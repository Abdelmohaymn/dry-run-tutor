import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/assessment_repository.dart';
import 'package:dry_run/features/chat/domain/session.dart';

/// A plain, scriptable fake — no Drift, no `dio`. [requestHandler] lets
/// each test script exactly the `Result<Assessment>` a judge request
/// should produce, including a call counter so a retry test can assert
/// the second attempt actually ran.
class FakeAssessmentRepository implements AssessmentRepository {
  Future<Result<Assessment>> Function(Session session)? requestHandler;
  int requestCalls = 0;
  final Map<String, Assessment> _bySession = <String, Assessment>{};

  @override
  Future<Result<Assessment>> request(Session session) async {
    requestCalls++;
    final Future<Result<Assessment>> Function(Session)? handler = requestHandler;
    if (handler == null) {
      return const Err(RelayError.unclearRetry());
    }
    final Result<Assessment> result = await handler(session);
    if (result case Ok<Assessment>(:final value)) {
      _bySession[session.id] = value;
    }
    return result;
  }

  /// Seeds an assessment as though a previous run had already stored it —
  /// what resuming a finished session finds.
  void seed(Assessment assessment) => _bySession[assessment.sessionId] = assessment;

  @override
  Future<Assessment?> forSession(String sessionId) async => _bySession[sessionId];

  int disputeCalls = 0;

  /// Which sessions were disputed, not just how many times — the flag is
  /// per session, and a test asserting the screen wrote it needs to know
  /// which one.
  final List<String> disputedSessionIds = <String>[];

  @override
  Future<void> recordDispute(String sessionId) async {
    disputeCalls++;
    disputedSessionIds.add(sessionId);
  }
}
