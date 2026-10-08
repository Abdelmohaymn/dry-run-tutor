import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
import 'package:dry_run/features/chat/domain/ended_by.dart';
import 'package:dry_run/features/chat/domain/hint_rung.dart';
import 'package:dry_run/features/chat/domain/message.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/session_repository.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';

/// A plain, scriptable fake — no Drift, no `dio`, no locator setup.
/// [sendTurnHandler] lets each test script exactly the `TurnEvent` stream
/// (or the error) a send should produce.
class FakeSessionRepository implements SessionRepository {
  late Session initialSession;
  Stream<TurnEvent> Function(Session session, String text, InputMode mode)? sendTurnHandler;
  Future<Result<HintRung>> Function(Session session)? pullHintHandler;
  Future<Session> Function(Session session, EndedBy reason)? endSessionHandler;
  final List<String> savedDraftTexts = <String>[];
  int deleteDraftCalls = 0;
  Result<void> resetForPracticeAgainResult = const Ok(null);
  int resetForPracticeAgainCalls = 0;

  /// The `solutionRequestCount` each `sendTurn` call was invoked with —
  /// `null` for an ordinary turn, so a solution-request test can assert
  /// the wire hint was actually sent (T110).
  final List<int?> sendTurnSolutionRequestCounts = <int?>[];
  final List<bool> sendTurnFinishOfferDismissed = <bool>[];

  /// The `retryMessageId` each `sendTurn` call carried — `null` for a
  /// first attempt, the existing row's id for a retry (FR-042).
  final List<String?> retriedMessageIds = <String?>[];

  @override
  Future<Session> openOrResumeToday({String? problemId}) async => initialSession;

  /// Defaults to null — the walkthrough is an offer, and every existing
  /// test was written against a repository that had none.
  Session? practiceSession;

  @override
  Future<Session?> openOrResumePractice() async => practiceSession;

  @override
  Stream<TurnEvent> sendTurn(
    Session session,
    String text,
    InputMode mode, {
    int? solutionRequestCount,
    String? retryMessageId,
    bool finishOfferDismissed = false,
  }) {
    retriedMessageIds.add(retryMessageId);
    sendTurnFinishOfferDismissed.add(finishOfferDismissed);
    sendTurnSolutionRequestCounts.add(solutionRequestCount);
    final Stream<TurnEvent> Function(Session, String, InputMode)? handler = sendTurnHandler;
    if (handler == null) {
      return const Stream<TurnEvent>.empty();
    }
    return handler(session, text, mode);
  }

  @override
  Future<Result<HintRung>> pullHint(Session session) async {
    final Future<Result<HintRung>> Function(Session)? handler = pullHintHandler;
    if (handler == null) {
      return const Err(RelayError.unclearRetry());
    }
    return handler(session);
  }

  /// Worked examples revealed through this fake, in order — an example
  /// reveal is a local insert, so a test asserts on the count rather than
  /// on a wire call that never happens.
  int examplesRevealed = 0;

  @override
  Future<int?> revealNextExample(Session session) async {
    if (examplesRevealed >= session.problem.examples.length) {
      return null;
    }
    examplesRevealed++;
    return examplesRevealed;
  }

  @override
  Future<void> saveDraft(Session session, Draft draft) async {
    savedDraftTexts.add(draft.text);
  }

  @override
  Future<Draft?> loadDraft(Session session) async => null;

  @override
  Future<void> deleteDraft(Session session) async {
    deleteDraftCalls++;
  }

  @override
  Future<Result<void>> resetForPracticeAgain(Session session) async {
    resetForPracticeAgainCalls++;
    return resetForPracticeAgainResult;
  }

  @override
  Future<Session> promoteToKeyed(Session session, String providerId) async =>
      session.copyWith(path: SessionPath.keyed, providerId: providerId);

  @override
  Future<Session> endSession(Session session, EndedBy reason) async {
    final Future<Session> Function(Session, EndedBy)? handler = endSessionHandler;
    if (handler == null) {
      return session.copyWith(status: SessionStatus.pendingJudge);
    }
    return handler(session, reason);
  }

  /// The session `DailySessionCubit.pullHint()` reads back after a
  /// successful pull, to pick up the fresh `ServerCounters` without this
  /// fake needing a real Drift row. Defaults to [initialSession] so a test
  /// that never sets it still gets a well-formed stream.
  Session? watchSession;

  @override
  Stream<Session> watch(String sessionId) => Stream<Session>.value(watchSession ?? initialSession);

  @override
  Stream<List<Message>> watchMessages(String sessionId) =>
      Stream<List<Message>>.value(messages);

  /// The rendered conversation a test wants `DailySessionCubit` to see.
  /// Empty by default; a retry test seeds it with the failed row so the
  /// Cubit can find the id it must reuse.
  List<Message> messages = <Message>[];
}
