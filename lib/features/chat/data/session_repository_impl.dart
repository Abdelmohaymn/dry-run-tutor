import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/dao/message_dao.dart';
import '../../../core/db/dao/session_dao.dart';
import '../../../core/db/dao/assessment_dao.dart';
import '../../../core/db/dao/outbox_dao.dart';
import '../../../core/db/dao/streak_dao.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/text/example_body.dart';
import '../../../core/network/dto/chat_dto.dart';
import '../../../core/network/dto/turn_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/network/sse_parser.dart';
import '../../../core/queue/outbox_repository.dart';
import '../../../core/time/trusted_time_source.dart';
import '../../daily/domain/daily_repository.dart';
import '../../daily/domain/daily_selection.dart';
import '../../keys/domain/key_repository.dart';
import '../../keys/domain/learner_key.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../../problem/domain/problem.dart';
import '../../problem/domain/problem_repository.dart';
import '../domain/draft.dart';
import '../domain/ended_by.dart';
import '../domain/hint_rung.dart';
import '../domain/message.dart';
import '../domain/server_counters.dart';
import '../domain/session.dart';
import '../domain/session_repository.dart';
import '../domain/turn_event.dart';
import 'turn_event_mapper.dart';

/// A replayed request never carries more than this many turns (FR-020) —
/// a defensive cap alongside `coveredBySummary`'s own bookkeeping, not a
/// substitute for it.
const int _maxReplayedMessages = 40;

class SessionRepositoryImpl implements SessionRepository {
  SessionRepositoryImpl({
    required RelayClient relayClient,
    required SessionDao sessionDao,
    AssessmentDao? assessmentDao,
    OutboxDao? outboxDao,
    required MessageDao messageDao,
    required StreakDao streakDao,
    required ProblemRepository problemRepository,
    required DailyRepository dailyRepository,
    required RemoteConfigRepository configRepository,
    required KeyRepository keyRepository,
    required InstallRepository installRepository,
    required TrustedTimeSource timeSource,
    required OutboxRepository outboxRepository,
    Uuid? uuid,
  })  : _relayClient = relayClient,
        _sessionDao = sessionDao,
        _assessmentDao = assessmentDao,
        _outboxDao = outboxDao,
        _messageDao = messageDao,
        _streakDao = streakDao,
        _problemRepository = problemRepository,
        _dailyRepository = dailyRepository,
        _configRepository = configRepository,
        _keyRepository = keyRepository,
        _installRepository = installRepository,
        _timeSource = timeSource,
        _outboxRepository = outboxRepository,
        _uuid = uuid ?? const Uuid();

  final RelayClient _relayClient;
  final SessionDao _sessionDao;
  final AssessmentDao? _assessmentDao;
  final OutboxDao? _outboxDao;
  final MessageDao _messageDao;
  final StreakDao _streakDao;
  final ProblemRepository _problemRepository;
  final DailyRepository _dailyRepository;
  final RemoteConfigRepository _configRepository;
  final OutboxRepository _outboxRepository;
  final KeyRepository _keyRepository;
  final InstallRepository _installRepository;
  final TrustedTimeSource _timeSource;
  final Uuid _uuid;

  @override
  Future<Session> openOrResumeToday({String? problemId}) async {
    final String day = await _timeSource.today();
    final SessionRow? existing = await _sessionDao.todaysSession(day, problemId: problemId);
    if (existing != null) {
      final Problem problem = (await _problemRepository.byId(existing.problemId))!;
      return _toDomainSession(existing, problem);
    }

    final Problem problem;
    final bool isRepeat;
    if (problemId == null) {
      final DailySelection selection = await _dailyRepository.forToday();
      problem = selection.problem;
      isRepeat = selection.isRepeat;
    } else {
      problem = await _problemRepository.fetchDaily(day, problemId: problemId);
      isRepeat = (await _sessionDao.completedProblemIds()).contains(problem.id);
    }
    final LearnerKey? key = await _keyRepository.read();
    final SessionPath path = key == null ? SessionPath.trial : SessionPath.keyed;
    final DateTime startedAt = (await _timeSource.now()).utc;
    final String id = _uuid.v4();

    await _sessionDao.insertSession(
      SessionsCompanion.insert(
        id: id,
        problemId: problem.id,
        day: day,
        path: path,
        status: SessionStatus.chatting,
        providerId: Value(key?.providerId),
        isRepeat: Value(isRepeat),
        startedAt: startedAt,
      ),
    );

    return Session(
      id: id,
      problem: problem,
      day: day,
      path: path,
      status: SessionStatus.chatting,
      providerId: key?.providerId,
      counters: ServerCounters.initial,
      isRepeat: isRepeat,
      disputed: false,
      solutionRequestCount: 0,
    );
  }

  @override
  Future<Session?> openOrResumePractice() async {
    final String day = await _timeSource.today();
    final SessionRow? existing = await _sessionDao.practiceSession(day);
    if (existing != null) {
      final Problem? cached = await _problemRepository.byId(existing.problemId);
      if (cached != null) {
        return _toDomainSession(existing, cached);
      }
    }

    final Problem? problem = await _problemRepository.practiceProblem();
    if (problem == null) {
      // A manifest with no warm-up in it — an older relay. The walkthrough
      // is an offer, so its absence is a fallback, not an error.
      return null;
    }

    final LearnerKey? key = await _keyRepository.read();
    final SessionPath path = key == null ? SessionPath.trial : SessionPath.keyed;
    final DateTime startedAt = (await _timeSource.now()).utc;
    final String id = _uuid.v4();

    await _sessionDao.insertSession(
      SessionsCompanion.insert(
        id: id,
        problemId: problem.id,
        day: day,
        path: path,
        status: SessionStatus.chatting,
        providerId: Value(key?.providerId),
        isPractice: const Value(true),
        startedAt: startedAt,
      ),
    );

    return Session(
      id: id,
      problem: problem,
      day: day,
      path: path,
      status: SessionStatus.chatting,
      providerId: key?.providerId,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );
  }

  @override
  Stream<TurnEvent> sendTurn(
    Session session,
    String text,
    InputMode mode, {
    int? solutionRequestCount,
    String? retryMessageId,
    bool finishOfferDismissed = false,
  }) async* {
    final String installId = await _resolvedInstallId();
    final String userMessageId = retryMessageId ?? _uuid.v4();

    if (retryMessageId == null) {
      final int userSeq = await _messageDao.nextSeq(session.id);
      final DateTime now = (await _timeSource.now()).utc;
      await _messageDao.insertMessage(
        MessagesCompanion.insert(
          id: userMessageId,
          sessionId: session.id,
          seq: userSeq,
          role: TurnRole.user,
          body: text,
          kind: MessageKind.turn,
          delivery: Delivery.sending,
          inputMode: Value(mode),
          createdAt: now,
        ),
      );
    } else {
      // The words are already in the conversation, in the place the
      // learner said them. A retry moves that row's delivery state; it
      // never appends a second copy underneath the first.
      await _messageDao.markDelivery(retryMessageId, Delivery.sending);
    }

    final StringBuffer tutorText = StringBuffer();
    ChatRequestDto? request;
    try {
      final List<String> replayedIds;
      (request, replayedIds) = await _buildChatRequest(
        session,
        solutionRequestCount: solutionRequestCount,
        finishOfferDismissed: finishOfferDismissed,
      );
      final (String? userKey, String? providerId) = await _keyedHeaders(session);

      final Stream<SseFrame> frames = session.path == SessionPath.trial
          ? _relayClient.trialChat(installId: installId, request: request)
          : _relayClient.chat(
              installId: installId,
              request: request,
              userKey: userKey,
              providerId: providerId,
            );

      // The frame-to-event mapping is shared with the web demo
      // (turn_event_mapper.dart); `summary` rides the same meta frame but
      // is not part of the event, so it is captured here on the way past.
      final List<MetaFrameDto> metas = <MetaFrameDto>[];
      final Stream<SseFrame> tapped = frames.map((SseFrame frame) {
        if (frame is MetaFrame) {
          metas.add(MetaFrameDto.fromJson(frame.rawJson));
        }
        return frame;
      });
      await for (final TurnEvent event in turnEventsFromFrames(tapped)) {
        switch (event) {
          case TurnEventToken(:final text):
            tutorText.write(text);
            yield event;
          case TurnEventMeta(:final counters):
            final MetaFrameDto dto = metas.last;
            await _messageDao.markDelivery(userMessageId, Delivery.sent);
            await _persistTurnReply(
              session: session,
              tutorText: tutorText.toString(),
              counters: counters,
              replayedIds: replayedIds,
              newSummary: dto.summary,
              summaryCovers: dto.summaryCovers,
              solutionRequestCount: solutionRequestCount,
            );
            yield event;
        }
      }
    } catch (e) {
      await _messageDao.markDelivery(userMessageId, Delivery.failedRetryable);
      // FR-042: a transport failure — the request never reached the relay
      // at all — is what queues here. A relay-catalogue error (a real
      // response, just not a success) is surfaced to the learner instead
      // (`Failure`'s own copy); it is never queued, because retrying it
      // blindly would fail identically.
      if (e is RelayException && e.error is TransportFailure && request != null) {
        await _outboxRepository.enqueue(
          sessionId: session.id,
          kind: OutboxKind.chatTurn,
          payload: <String, Object?>{'user_message_id': userMessageId, 'request': request.toJson()},
          solutionRequestCountAtEnqueue: session.solutionRequestCount,
        );
      }
      rethrow;
    }
  }

  @override
  Future<Result<HintRung>> pullHint(Session session) async {
    try {
      final String installId = await _resolvedInstallId();
      // The conversation so far, not `const []`: the wire schema requires
      // `messages` to carry the turns a reply would be grounded in, and
      // sending an empty array made every hint pull a 400 the learner read
      // as "something failed on our side" (found on device). The hint
      // branch reaches no provider and spends no turn either way (FR-027)
      // — this is the request *shape* the relay validates, not extra
      // context the ladder consumes.
      final (ChatRequestDto request, _) = await _buildChatRequest(session, hintRequested: true);
      final (String? userKey, String? providerId) = await _keyedHeaders(session);

      final Stream<SseFrame> frames = session.path == SessionPath.trial
          ? _relayClient.trialChat(installId: installId, request: request)
          : _relayClient.chat(
              installId: installId,
              request: request,
              userKey: userKey,
              providerId: providerId,
            );

      String? hintText;
      ServerCounters? counters;
      await for (final SseFrame frame in frames) {
        switch (frame) {
          case TokenFrame(:final text):
            hintText = text;
          case MetaFrame(:final rawJson):
            counters = _countersFromDto(MetaFrameDto.fromJson(rawJson));
          case DoneFrame():
          case ErrorFrame():
            break;
        }
      }
      if (hintText == null || counters == null) {
        return const Err(RelayError.unclearRetry());
      }

      // The server flattens the authored ladder and returns its own fixed
      // closing line once `hints_revealed` runs past the ladder's length
      // (worker/src/lib/hint-ladder.ts's `LADDER_EXHAUSTED`) — indistinguishable
      // from a real rung by `hints_remaining` alone, since that is already
      // zero on the *last* real rung too. Comparing the 1-based index this
      // pull just produced against the problem's own authored count is
      // what tells the two apart without guessing at the session's prior
      // state (T083's placeholder-zero lesson, applied here).
      final bool exhausted = counters.hintsRevealed > session.problem.hintCount;

      final int seq = await _messageDao.nextSeq(session.id);
      final DateTime now = (await _timeSource.now()).utc;
      await _messageDao.insertMessage(
        MessagesCompanion.insert(
          id: _uuid.v4(),
          sessionId: session.id,
          seq: seq,
          role: TurnRole.tutor,
          body: hintText,
          kind: exhausted ? MessageKind.ladderExhausted : MessageKind.hintRung,
          delivery: Delivery.sent,
          createdAt: now,
        ),
      );
      await _applyCounters(session.id, counters, newSummary: null);

      return Ok(HintRung(index: counters.hintsRevealed, text: hintText, exhausted: exhausted));
    } on MissingMetaFailure {
      return const Err(RelayError.unclearRetry());
    } on RelayException catch (e) {
      return Err(e.error);
    } catch (_) {
      return const Err(RelayError.transport());
    }
  }

  @override
  Future<int?> revealNextExample(Session session) async {
    final List<ProblemExample> examples = session.problem.examples;
    final List<MessageRow> rows = await _messageDao.forSession(session.id);
    final int alreadyShown =
        rows.where((MessageRow r) => r.kind == MessageKind.example).length;
    if (alreadyShown >= examples.length) {
      return null;
    }
    final ProblemExample example = examples[alreadyShown];
    final int seq = await _messageDao.nextSeq(session.id);
    final DateTime now = (await _timeSource.now()).utc;
    await _messageDao.insertMessage(
      MessagesCompanion.insert(
        id: _uuid.v4(),
        sessionId: session.id,
        seq: seq,
        role: TurnRole.tutor,
        body: renderExampleBody(example.input, example.output, example.explanation),
        kind: MessageKind.example,
        delivery: Delivery.sent,
        createdAt: now,
      ),
    );
    return alreadyShown + 1;
  }

  @override
  Future<void> saveDraft(Session session, Draft draft) async {
    final DateTime now = (await _timeSource.now()).utc;
    await _sessionDao.upsertDraft(
      DraftsCompanion.insert(
        sessionId: session.id,
        body: draft.text,
        recognised: Value(draft.recognised),
        repaired: Value(draft.repaired),
        inputMode: draft.inputMode,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<Draft?> loadDraft(Session session) async {
    final DraftRow? row = await _sessionDao.draftFor(session.id);
    if (row == null) {
      return null;
    }
    return Draft(
      text: row.body,
      recognised: row.recognised,
      repaired: row.repaired,
      inputMode: row.inputMode,
    );
  }

  @override
  Future<void> deleteDraft(Session session) => _sessionDao.deleteDraft(session.id);

  @override
  Future<Result<void>> resetForPracticeAgain(Session session) async {
    try {
      if (_assessmentDao == null || _outboxDao == null) {
        return const Err(RelayError.transport());
      }
      final String installId = await _resolvedInstallId();
      await _relayClient.resetSession(installId: installId, problemId: session.problem.id);
      await _sessionDao.transaction(() async {
        await _assessmentDao.deleteForSession(session.id);
        await _outboxDao.deleteForSession(session.id);
        await _sessionDao.deleteDraft(session.id);
        await _messageDao.deleteForSession(session.id);
        await _sessionDao.deleteSession(session.id);
      });
      return const Ok(null);
    } on RelayException catch (e) {
      return Err(e.error);
    } catch (_) {
      return const Err(RelayError.transport());
    }
  }

  @override
  Future<Session> promoteToKeyed(Session session, String providerId) async {
    final SessionRow current = (await _sessionDao.byId(session.id))!;
    await _sessionDao.updateSession(
      current.copyWith(path: SessionPath.keyed, providerId: Value(providerId)),
    );
    return session.copyWith(path: SessionPath.keyed, providerId: providerId);
  }

  @override
  Future<Session> endSession(Session session, EndedBy reason) async {
    final DateTime completedAt = (await _timeSource.now()).utc;
    await _sessionDao.transaction(() async {
      final SessionRow current = (await _sessionDao.byId(session.id))!;
      await _sessionDao.updateSession(
        current.copyWith(
          status: SessionStatus.pendingJudge,
          completedAt: Value(completedAt),
          sessionEnded: Value(reason.wireName),
        ),
      );
      // FR-036, Principle IV: credited here, in the same transaction,
      // before any judge request exists — no verdict and no network
      // state can reach back and undo it.
      await _streakDao.credit(session.day, creditedAt: completedAt);
    });
    return session.copyWith(
      status: SessionStatus.pendingJudge,
      counters: ServerCounters(
        turnIndex: session.counters.turnIndex,
        turnsRemaining: session.counters.turnsRemaining,
        hintsRevealed: session.counters.hintsRevealed,
        hintsRemaining: session.counters.hintsRemaining,
        sessionEnded: reason.wireName,
        leakBlocked: session.counters.leakBlocked,
      ),
    );
  }

  @override
  Stream<Session> watch(String sessionId) async* {
    await for (final SessionRow? row in _sessionDao.watchById(sessionId)) {
      if (row == null) {
        continue;
      }
      final Problem problem = (await _problemRepository.byId(row.problemId))!;
      yield _toDomainSession(row, problem);
    }
  }

  @override
  Stream<List<Message>> watchMessages(String sessionId) {
    return _messageDao.watchForSession(sessionId).map(
          (List<MessageRow> rows) => rows.map(_toDomainMessage).toList(growable: false),
        );
  }

  // --- internals ---------------------------------------------------

  Future<String> _resolvedInstallId() async {
    final Result<InstallIdentity> result = await _installRepository.ensureIdentity();
    return switch (result) {
      Ok<InstallIdentity>(:final value) => value.installId,
      Err<InstallIdentity>(:final error) => throw RelayException(error),
    };
  }


  /// The request, and the ids of the rows it replays, in the same order as
  /// its `messages` — `summary_covers` counts from the front of that list.
  Future<(ChatRequestDto, List<String>)> _buildChatRequest(
    Session session, {
    int? solutionRequestCount,
    bool? hintRequested,
    bool finishOfferDismissed = false,
  }) async {
    final List<MessageRow> uncovered = await _messageDao.uncoveredForSession(session.id);
    final List<MessageRow> capped = uncovered.length > _maxReplayedMessages
        ? uncovered.sublist(uncovered.length - _maxReplayedMessages)
        : uncovered;
    // From the row, not `session`: the Cubit's copy only ever takes new
    // counters, so its `summary` stayed null after the relay sent one and
    // the summary was never replayed (found on device 2026-09-25).
    final SessionRow? row = await _sessionDao.byId(session.id);
    final List<String> earlier = await _messageDao.coveredLearnerTurns(session.id);
    final ChatRequestDto request = ChatRequestDto(
      problemId: session.problem.id,
      messages: capped.map((MessageRow m) => TurnDto(role: m.role.name, text: m.body)).toList(),
      summary: row?.summary ?? session.summary,
      earlierLearnerTurns: earlier.isEmpty
          ? null
          : earlier.sublist(earlier.length > _maxReplayedMessages ? earlier.length - _maxReplayedMessages : 0),
      hintRequested: hintRequested,
      solutionRequestCount: solutionRequestCount,
      finishOfferDismissed: finishOfferDismissed ? true : null,
    );
    return (request, capped.map((MessageRow m) => m.id).toList());
  }

  Future<(String?, String?)> _keyedHeaders(Session session) async {
    if (session.path != SessionPath.keyed) {
      return (null, null);
    }
    final LearnerKey? key = await _keyRepository.read();
    final String? providerId = key?.providerId ?? session.providerId;

    // A provider offered when the key was saved can drop out of
    // `keyed_providers` later (the relay's own choice, research.md
    // R-005) — sending it anyway is `BAD_REQUEST` on the wire. Caught
    // here, before the request, and turned into the same re-entry
    // prompt `InvalidKey` already drives, rather than a doomed request
    // that reads as the app being broken (contracts/relay-client.md,
    // T093).
    final RuntimeConfig config = _configRepository.cached() ?? await _configRepository.load();
    if (providerId != null && !config.keyedProviders.contains(providerId)) {
      throw const RelayException(RelayError.invalidKey());
    }

    return (key?.value, providerId);
  }

  ServerCounters _countersFromDto(MetaFrameDto dto) => countersFromMetaDto(dto);

  /// Inserts the tutor's reply and applies the turn's counters, folding
  /// any newly-covered messages into a fresh `summary` (FR-020).
  Future<void> _persistTurnReply({
    required Session session,
    required String tutorText,
    required ServerCounters counters,
    required List<String> replayedIds,
    String? newSummary,
    int? summaryCovers,
    int? solutionRequestCount,
  }) async {
    final DateTime now = (await _timeSource.now()).utc;
    final int tutorSeq = await _messageDao.nextSeq(session.id);
    await _messageDao.insertMessage(
      MessagesCompanion.insert(
        id: _uuid.v4(),
        sessionId: session.id,
        seq: tutorSeq,
        role: TurnRole.tutor,
        body: tutorText.isEmpty ? ' ' : tutorText,
        kind: counters.leakBlocked ? MessageKind.fallbackRedirect : MessageKind.turn,
        delivery: Delivery.sent,
        createdAt: now,
      ),
    );
    await _applyCounters(
      session.id,
      counters,
      newSummary: newSummary,
      solutionRequestCount: solutionRequestCount,
    );
    // Only the rows the relay says it folded in. With no count (a relay
    // older than `summary_covers`) nothing is marked: the next summary may
    // repeat some of this one, which beats losing the recent turns.
    if (newSummary != null && summaryCovers != null) {
      await _messageDao.markCoveredBySummary(replayedIds.take(summaryCovers).toList());
    }
  }

  Future<void> _applyCounters(
    String sessionId,
    ServerCounters counters, {
    String? newSummary,
    int? solutionRequestCount,
  }) async {
    final SessionRow current = (await _sessionDao.byId(sessionId))!;
    await _sessionDao.updateSession(
      current.copyWith(
        turnIndex: counters.turnIndex,
        turnsRemaining: Value(counters.turnsRemaining),
        hintsRevealed: counters.hintsRevealed,
        hintsRemaining: Value(counters.hintsRemaining),
        sessionEnded: Value(counters.sessionEnded),
        summary: newSummary == null ? const Value.absent() : Value(newSummary),
        // Accepted by the relay, so the count this turn asked for is now
        // the row's own truth (Principle III) — the server never echoes
        // it back, this is the one write. `SessionRow.copyWith` (the data
        // class, not the companion) takes a plain nullable `int` here —
        // `null` means "leave unchanged", not "clear it" — so this is
        // passed straight through rather than `Value`-wrapped.
        solutionRequestCount: solutionRequestCount,
      ),
    );
  }

  Message _toDomainMessage(MessageRow row) => Message(
        id: row.id,
        seq: row.seq,
        role: row.role,
        text: row.body,
        kind: row.kind,
        delivery: row.delivery,
        recognisedDraft: row.recognisedDraft,
        inputMode: row.inputMode,
      );

  Session _toDomainSession(SessionRow row, Problem problem) => Session(
        id: row.id,
        problem: problem,
        day: row.day,
        path: row.path,
        status: row.status,
        providerId: row.providerId,
        counters: ServerCounters(
          turnIndex: row.turnIndex,
          turnsRemaining: row.turnsRemaining ?? 0,
          hintsRevealed: row.hintsRevealed,
          hintsRemaining: row.hintsRemaining ?? 0,
          sessionEnded: row.sessionEnded,
          leakBlocked: false,
        ),
        summary: row.summary,
        isRepeat: row.isRepeat,
        disputed: row.disputed,
        solutionRequestCount: row.solutionRequestCount,
      );
}
