import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../db/app_database.dart';
import '../db/dao/assessment_dao.dart';
import '../db/dao/message_dao.dart';
import '../db/dao/session_dao.dart';
import '../errors/relay_error.dart';
import '../models/wire_enums.dart';
import '../network/dto/chat_dto.dart';
import '../network/dto/judge_dto.dart';
import '../network/relay_client.dart';
import '../network/sse_parser.dart';
import '../notifications/notification_service.dart';
import '../time/trusted_time_source.dart';
import 'outbox_drain_state.dart';
import 'outbox_item.dart';
import 'outbox_repository.dart';

sealed class OutboxDrainEvent {
  const OutboxDrainEvent();
}

/// Fired by `connectivity_plus` and by any successful foreground request
/// (research.md R-010) — the two moments a queued row is worth trying
/// again.
class DrainRequested extends OutboxDrainEvent {
  const DrainRequested();
}

/// The **one** event-driven `Bloc` in the app (T134). Drains strictly in
/// `createdAt` order — one row at a time, in a single sequential loop, so
/// a queued turn and a queued judge for the same session are never sent
/// concurrently (the serialisation data-model.md §6 requires is a
/// property of this loop, not a lock).
class OutboxDrainBloc extends Bloc<OutboxDrainEvent, OutboxDrainState> {
  OutboxDrainBloc({
    required OutboxRepository outboxRepository,
    required RelayClient relayClient,
    required MessageDao messageDao,
    required SessionDao sessionDao,
    required AssessmentDao assessmentDao,
    required TrustedTimeSource timeSource,
    required Future<String> Function() resolveInstallId,
    required Future<(String?, String?)> Function(SessionRow session) resolveKeyedHeaders,
    NotificationService? notificationService,
    Connectivity? connectivity,
  })  : _outboxRepository = outboxRepository,
        _relayClient = relayClient,
        _messageDao = messageDao,
        _sessionDao = sessionDao,
        _assessmentDao = assessmentDao,
        _timeSource = timeSource,
        _resolveInstallId = resolveInstallId,
        _resolveKeyedHeaders = resolveKeyedHeaders,
        _notificationService = notificationService,
        super(const OutboxIdle()) {
    on<DrainRequested>(_onDrainRequested, transformer: (events, mapper) => events.asyncExpand(mapper));
    _connectivitySub = (connectivity ?? Connectivity()).onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((ConnectivityResult r) => r != ConnectivityResult.none)) {
        add(const DrainRequested());
      }
    });
  }

  final OutboxRepository _outboxRepository;
  final RelayClient _relayClient;
  final MessageDao _messageDao;
  final SessionDao _sessionDao;
  final AssessmentDao _assessmentDao;
  final TrustedTimeSource _timeSource;
  final Future<String> Function() _resolveInstallId;
  final Future<(String?, String?)> Function(SessionRow session) _resolveKeyedHeaders;
  final NotificationService? _notificationService;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// Called on any successful foreground request — the second of the two
  /// triggers research.md R-010 names.
  void notifyForegroundSuccess() => add(const DrainRequested());

  Future<void> _onDrainRequested(DrainRequested event, Emitter<OutboxDrainState> emit) async {
    final DateTime now = (await _timeSource.now()).utc;
    final List<OutboxItem> due = await _outboxRepository.due(now);
    if (due.isEmpty) {
      emit(const OutboxIdle());
      return;
    }

    int drained = 0;
    final Set<OutboxKind> drainedKinds = <OutboxKind>{};
    for (final OutboxItem item in due) {
      emit(OutboxDraining(due.length - drained));
      final bool sent = await _drainOne(item, now);
      if (sent) {
        drained++;
        drainedKinds.add(item.kind);
      }
    }
    if (drainedKinds.contains(OutboxKind.judge)) {
      // FR-048c: the app may not be foregrounded to show the verdict
      // directly — a local notification is the only way the learner
      // finds out their assessment caught up.
      await _notificationService?.notifyAssessmentReady();
    }
    emit(const OutboxIdle());
  }

  /// Returns `true` if [item] was actually sent and removed.
  Future<bool> _drainOne(OutboxItem item, DateTime now) async {
    final SessionRow? session = await _sessionDao.byId(item.sessionId);
    if (session == null) {
      // The session row is gone (shouldn't happen — sessions are never
      // deleted — but a queued row with nothing to attach a reply to is
      // not sendable either way).
      await _outboxRepository.remove(item.id);
      return false;
    }

    try {
      switch (item.kind) {
        case OutboxKind.chatTurn:
          await _drainChatTurn(item, session);
        case OutboxKind.judge:
          await _drainJudge(item, session);
      }
      await _outboxRepository.remove(item.id);
      return true;
    } on RelayException catch (e) {
      await _applyRetryPolicy(item, e.error, now);
    } on MissingMetaFailure {
      await _applyRetryPolicy(item, const RelayError.unclearRetry(), now);
    } catch (_) {
      // Still offline, or some other transport hiccup — leave the row
      // exactly as it is; the next `DrainRequested` tries again.
    }
    return false;
  }

  Future<void> _drainChatTurn(OutboxItem item, SessionRow session) async {
    final Map<String, Object?> requestJson = item.payload['request'] as Map<String, Object?>;
    ChatRequestDto request = ChatRequestDto.fromJson(requestJson);

    // Principle III / data-model.md §6: a replayed row can never carry a
    // higher solution count than the row it replaces. If some other
    // accepted turn already advanced `Sessions.solutionRequestCount`
    // beyond what this row was built against, this row's own ask is
    // stale — clamp it down rather than let a blind resend push the
    // count past what it was ever entitled to.
    if (request.solutionRequestCount != null &&
        item.solutionRequestCountAtEnqueue < session.solutionRequestCount) {
      request = ChatRequestDto(
        problemId: request.problemId,
        messages: request.messages,
        summary: request.summary,
        earlierLearnerTurns: request.earlierLearnerTurns,
        hintRequested: request.hintRequested,
        solutionRequestCount: session.solutionRequestCount,
      );
    }

    final String installId = await _resolveInstallId();
    final (String? userKey, String? providerId) = await _resolveKeyedHeaders(session);
    final String userMessageId = item.payload['user_message_id'] as String;

    final Stream<SseFrame> frames = session.path == SessionPath.trial
        ? _relayClient.trialChat(installId: installId, request: request)
        : _relayClient.chat(installId: installId, request: request, userKey: userKey, providerId: providerId);

    MetaFrameDto? meta;
    await for (final SseFrame frame in frames) {
      if (frame is MetaFrame) {
        meta = MetaFrameDto.fromJson(frame.rawJson);
      }
    }
    if (meta == null) {
      throw const MissingMetaFailure();
    }

    await _messageDao.markDelivery(userMessageId, Delivery.sent);
    final SessionRow? current = await _sessionDao.byId(session.id);
    if (current != null) {
      await _sessionDao.updateSession(
        current.copyWith(
          turnIndex: meta.turnIndex,
          turnsRemaining: Value(meta.turnsRemaining),
          hintsRevealed: meta.hintsRevealed,
          hintsRemaining: Value(meta.hintsRemaining),
          sessionEnded: Value(meta.sessionEnded),
          solutionRequestCount: request.solutionRequestCount ?? current.solutionRequestCount,
        ),
      );
    }
  }

  Future<void> _drainJudge(OutboxItem item, SessionRow session) async {
    final Map<String, Object?> requestJson = item.payload['request'] as Map<String, Object?>;
    final JudgeRequestDto request = JudgeRequestDto.fromJson(requestJson);
    final String installId = await _resolveInstallId();
    final (String? userKey, String? providerId) = await _resolveKeyedHeaders(session);

    final AssessmentDto dto = session.path == SessionPath.trial
        ? await _relayClient.trialJudge(installId: installId, request: request)
        : await _relayClient.judge(installId: installId, request: request, userKey: userKey, providerId: providerId);

    final DateTime receivedAt = (await _timeSource.now()).utc;
    await _assessmentDao.upsert(
      AssessmentsCompanion.insert(
        sessionId: session.id,
        matchedApproach: dto.matchedApproach,
        matchedVerdict: MatchedVerdict.values.firstWhere((MatchedVerdict v) => v.name == dto.matchedVerdict),
        insightsHit: dto.insightsHit,
        insightsMissed: dto.insightsMissed,
        wrongTurnsTaken: dto.wrongTurnsTaken,
        complexityJson: _complexityJson(dto),
        verdict: _verdictFromWire(dto.verdict),
        confidence: dto.confidence,
        feedback: dto.feedback,
        editorial: dto.editorial,
        revealAtIndex: Value(request.revealAtIndex),
        rawJson: '{}',
        receivedAt: receivedAt,
      ),
    );
    await _sessionDao.updateSession(session.copyWith(status: SessionStatus.complete));
  }

  String _complexityJson(AssessmentDto dto) => '{'
      '"user_claimed_time":${_jsonString(dto.complexity.userClaimedTime)},'
      '"user_claimed_space":${_jsonString(dto.complexity.userClaimedSpace)},'
      '"reference_time":${_jsonString(dto.complexity.referenceTime)},'
      '"reference_space":${_jsonString(dto.complexity.referenceSpace)},'
      '"assessment":${_jsonString(dto.complexity.assessment)}'
      '}';

  String _jsonString(String? value) => value == null ? 'null' : '"${value.replaceAll('"', r'\"')}"';

  Verdict _verdictFromWire(String wire) => switch (wire) {
        'strong_pass' => Verdict.strongPass,
        'pass' => Verdict.pass,
        'borderline' => Verdict.borderline,
        'fail' => Verdict.fail,
        'unclear' => Verdict.unclear,
        _ => Verdict.unclear,
      };

  Future<void> _applyRetryPolicy(OutboxItem item, RelayError error, DateTime now) async {
    switch (error) {
      case RateLimited(:final retryAfter):
        // Waits, and does not count an attempt (T136, research.md R-010).
        await _outboxRepository.markAttempted(
          id: item.id,
          nextEligibleAt: now.add(retryAfter),
          lastErrorCode: 'RATE_LIMITED',
        );
      case UnclearRetry():
        await _outboxRepository.incrementAttempts(item.id);
        if (item.attempts < 1) {
          // Retries once, immediately.
          await _outboxRepository.markAttempted(id: item.id, nextEligibleAt: now, lastErrorCode: 'UNCLEAR_RETRY');
        } else {
          // Leaves the session pending: stop retrying automatically
          // without discarding the row, so a learner acting on the
          // relay-catalogue message this failure surfaces is not also
          // told their turn was silently dropped.
          await _outboxRepository.markAttempted(
            id: item.id,
            nextEligibleAt: now.add(const Duration(days: 365)),
            lastErrorCode: 'UNCLEAR_RETRY',
          );
        }
      case SessionAlreadyJudged(ctx: JudgedContext.repeatJudge):
        // The relay judged this session but the verdict never reached this
        // install. The outbox cannot recover that (it needs a reset and a
        // re-judge); the session stays pendingJudge, and its "Review the
        // assessment" button runs that recovery. Parking the row for a year
        // only left a dead entry behind.
        await _outboxRepository.remove(item.id);
      case TransportFailure():
        // Never reached the relay at all — leave the row exactly as
        // it is; the next connectivity change tries again.
        break;
      default:
        // Every other catalogue code is `retryable: false` (research.md
        // R-010): stop the row and let its own copy — already rendered
        // as `Delivery.failedRetryable` on the message — say why.
        await _outboxRepository.markAttempted(
          id: item.id,
          nextEligibleAt: now.add(const Duration(days: 365)),
          lastErrorCode: error.runtimeType.toString(),
        );
    }
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }
}
