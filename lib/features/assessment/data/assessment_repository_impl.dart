import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../../core/config/remote_config_repository.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/dao/assessment_dao.dart';
import '../../../core/db/dao/message_dao.dart';
import '../../../core/db/dao/session_dao.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/network/dto/judge_dto.dart';
import '../../../core/network/dto/turn_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/queue/outbox_repository.dart';
import '../../../core/time/trusted_time_source.dart';
import '../../chat/domain/ended_by.dart';
import '../../chat/domain/session.dart';
import '../../keys/domain/key_repository.dart';
import '../../keys/domain/learner_key.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../domain/assessment.dart';
import '../domain/assessment_repository.dart';
import '../domain/complexity.dart';

/// `/v1/judge`'s own wire cap on `conversation` — same 40-turn ceiling
/// `openapi.yaml`'s schema enforces on `/v1/chat`.
const int _maxJudgeMessages = 40;

class AssessmentRepositoryImpl implements AssessmentRepository {
  AssessmentRepositoryImpl({
    required RelayClient relayClient,
    required AssessmentDao assessmentDao,
    required SessionDao sessionDao,
    required MessageDao messageDao,
    required RemoteConfigRepository configRepository,
    required KeyRepository keyRepository,
    required InstallRepository installRepository,
    required TrustedTimeSource timeSource,
    required OutboxRepository outboxRepository,
  })  : _relayClient = relayClient,
        _assessmentDao = assessmentDao,
        _sessionDao = sessionDao,
        _messageDao = messageDao,
        _configRepository = configRepository,
        _keyRepository = keyRepository,
        _installRepository = installRepository,
        _timeSource = timeSource,
        _outboxRepository = outboxRepository;

  final RelayClient _relayClient;
  final AssessmentDao _assessmentDao;
  final SessionDao _sessionDao;
  final MessageDao _messageDao;
  final RemoteConfigRepository _configRepository;
  final KeyRepository _keyRepository;
  final InstallRepository _installRepository;
  final TrustedTimeSource _timeSource;
  final OutboxRepository _outboxRepository;

  @override
  Future<Result<Assessment>> request(Session session) async {
    JudgeRequestDto? request;
    try {
      final String installId = await _resolvedInstallId();
      final EndedBy endedBy = endedByFromSessionEnded(session.counters.sessionEnded);
      request = JudgeRequestDto(
        problemId: session.problem.id,
        conversation: await _buildConversation(session.id),
        endedBy: endedBy.wireName,
        // FR-033: required exactly when the session ended by a solution
        // request, and read off the session's own last-known turn index
        // — "what they had earned when they asked" — rather than a
        // second argument a caller could pass inconsistently.
        revealAtIndex: endedBy == EndedBy.solution ? session.counters.turnIndex : null,
      );
      final (String? userKey, String? providerId) = await _keyedHeaders(session);

      final AssessmentDto dto = session.path == SessionPath.trial
          ? await _relayClient.trialJudge(installId: installId, request: request)
          : await _relayClient.judge(
              installId: installId,
              request: request,
              userKey: userKey,
              providerId: providerId,
            );

      final Assessment assessment = _toDomain(session.id, dto, revealAtIndex: request.revealAtIndex);
      await _persist(assessment, rawJson: jsonEncode(dto.toJson()));
      return Ok(assessment);
    } on RelayException catch (e) {
      // `claimJudge()` claims before the provider call and releases the
      // claim again on any provider failure (`worker/src/lib/judge-core.ts`),
      // so a retry after THIS install's own failed attempt gets a genuine
      // second try, never `SESSION_ALREADY_JUDGED`. The only way that code
      // reaches here for real is a *successful* assessment this install
      // never received (e.g. the response was lost after the server
      // committed it) — recoverable only if a previous attempt already
      // wrote it locally (T105).
      if (e.error case SessionAlreadyJudged(ctx: JudgedContext.repeatJudge)) {
        final Assessment? cached = await forSession(session.id);
        if (cached != null) {
          return Ok(cached);
        }
      }
      // FR-042's queueing extends to the judge call: the request never
      // reached the relay at all, so it queues rather than surfacing as
      // something the learner must act on (T131/T142).
      if (e.error is TransportFailure && request != null) {
        await _outboxRepository.enqueue(
          sessionId: session.id,
          kind: OutboxKind.judge,
          payload: <String, Object?>{'request': request.toJson()},
          solutionRequestCountAtEnqueue: session.solutionRequestCount,
        );
      }
      return Err(e.error);
    } catch (_) {
      return const Err(RelayError.transport());
    }
  }

  @override
  Future<Assessment?> forSession(String sessionId) async {
    final AssessmentRow? row = await _assessmentDao.forSession(sessionId);
    if (row == null) {
      return null;
    }
    return _fromRow(row);
  }

  @override
  Future<void> recordDispute(String sessionId) async {
    final SessionRow? row = await _sessionDao.byId(sessionId);
    if (row == null) {
      return;
    }
    final DateTime now = (await _timeSource.now()).utc;
    await _sessionDao.updateSession(row.copyWith(disputed: true, disputedAt: Value(now)));
  }

  // --- internals ---------------------------------------------------

  Future<String> _resolvedInstallId() async {
    final Result<InstallIdentity> result = await _installRepository.ensureIdentity();
    return switch (result) {
      Ok<InstallIdentity>(:final value) => value.installId,
      Err<InstallIdentity>(:final error) => throw RelayException(error),
    };
  }

  /// Every `kind: turn` row for the session, capped at the wire's own
  /// 40-turn ceiling — unlike `/v1/chat`, `/v1/judge` has no `summary`
  /// field to fold older turns into, so this is the full conversation the
  /// judge grades, not the chat request builder's uncovered-only view.
  Future<List<TurnDto>> _buildConversation(String sessionId) async {
    final List<MessageRow> all = await _messageDao.forSession(sessionId);
    final List<MessageRow> turnsOnly =
        all.where((MessageRow m) => m.kind == MessageKind.turn).toList(growable: false);
    final List<MessageRow> capped = turnsOnly.length > _maxJudgeMessages
        ? turnsOnly.sublist(turnsOnly.length - _maxJudgeMessages)
        : turnsOnly;
    return capped.map((MessageRow m) => TurnDto(role: m.role.name, text: m.body)).toList();
  }

  Future<(String?, String?)> _keyedHeaders(Session session) async {
    if (session.path != SessionPath.keyed) {
      return (null, null);
    }
    final LearnerKey? key = await _keyRepository.read();
    final String? providerId = key?.providerId ?? session.providerId;
    final config = _configRepository.cached() ?? await _configRepository.load();
    if (providerId != null && !config.keyedProviders.contains(providerId)) {
      throw const RelayException(RelayError.invalidKey());
    }
    return (key?.value, providerId);
  }

  Future<void> _persist(Assessment assessment, {required String rawJson}) async {
    await _assessmentDao.upsert(
      AssessmentsCompanion.insert(
        sessionId: assessment.sessionId,
        matchedApproach: assessment.matchedApproach,
        matchedVerdict: assessment.matchedVerdict,
        insightsHit: assessment.insightsHit,
        insightsMissed: assessment.insightsMissed,
        wrongTurnsTaken: assessment.wrongTurnsTaken,
        complexityJson: jsonEncode(_complexityToJson(assessment.complexity)),
        verdict: assessment.verdict,
        confidence: assessment.confidence,
        feedback: assessment.feedback,
        editorial: assessment.editorial,
        revealAtIndex: Value(assessment.revealAtIndex),
        rawJson: rawJson,
        receivedAt: (await _timeSource.now()).utc,
      ),
    );
    final SessionRow? current = await _sessionDao.byId(assessment.sessionId);
    if (current != null) {
      await _sessionDao.updateSession(current.copyWith(status: SessionStatus.complete));
    }
  }

  Assessment _toDomain(String sessionId, AssessmentDto dto, {int? revealAtIndex}) => Assessment(
        sessionId: sessionId,
        matchedApproach: dto.matchedApproach,
        matchedVerdict: _matchedVerdictFromWire(dto.matchedVerdict),
        insightsHit: dto.insightsHit,
        insightsMissed: dto.insightsMissed,
        wrongTurnsTaken: dto.wrongTurnsTaken,
        complexity: Complexity(
          userClaimedTime: dto.complexity.userClaimedTime,
          userClaimedSpace: dto.complexity.userClaimedSpace,
          referenceTime: dto.complexity.referenceTime,
          referenceSpace: dto.complexity.referenceSpace,
          assessment: dto.complexity.assessment,
        ),
        verdict: _verdictFromWire(dto.verdict),
        confidence: dto.confidence,
        feedback: dto.feedback,
        editorial: dto.editorial,
        revealAtIndex: revealAtIndex,
      );

  Assessment _fromRow(AssessmentRow row) {
    final Map<String, dynamic> complexityJson = jsonDecode(row.complexityJson) as Map<String, dynamic>;
    return Assessment(
      sessionId: row.sessionId,
      matchedApproach: row.matchedApproach,
      matchedVerdict: row.matchedVerdict,
      insightsHit: row.insightsHit,
      insightsMissed: row.insightsMissed,
      wrongTurnsTaken: row.wrongTurnsTaken,
      complexity: Complexity(
        userClaimedTime: complexityJson['user_claimed_time'] as String?,
        userClaimedSpace: complexityJson['user_claimed_space'] as String?,
        referenceTime: complexityJson['reference_time'] as String,
        referenceSpace: complexityJson['reference_space'] as String,
        assessment: complexityJson['assessment'] as String,
      ),
      verdict: row.verdict,
      confidence: row.confidence,
      feedback: row.feedback,
      editorial: row.editorial,
      revealAtIndex: row.revealAtIndex,
    );
  }

  Map<String, Object?> _complexityToJson(Complexity c) => <String, Object?>{
        'user_claimed_time': c.userClaimedTime,
        'user_claimed_space': c.userClaimedSpace,
        'reference_time': c.referenceTime,
        'reference_space': c.referenceSpace,
        'assessment': c.assessment,
      };

  MatchedVerdict _matchedVerdictFromWire(String wire) =>
      MatchedVerdict.values.firstWhere((MatchedVerdict v) => v.name == wire);

  Verdict _verdictFromWire(String wire) => switch (wire) {
        'strong_pass' => Verdict.strongPass,
        'pass' => Verdict.pass,
        'borderline' => Verdict.borderline,
        'fail' => Verdict.fail,
        'unclear' => Verdict.unclear,
        _ => throw FormatException('Unknown verdict on the wire: $wire'),
      };
}
