import '../../../core/errors/result.dart';
import '../../chat/domain/session.dart';
import 'assessment.dart';

/// The assessment feature's one repository (contracts/repositories.md).
/// Pure Dart — no `dio`, no Drift, no DTO — so `DailySessionCubit` stays
/// constructible in `bloc_test` with a plain fake.
abstract interface class AssessmentRepository {
  /// Requests the one assessment [session] ever gets. Everything `/v1/judge`
  /// needs — the conversation, `ended_by`, and (when the session ended by a
  /// solution request) `reveal_at_index` — is read off [session] itself, so
  /// this never queues a second judge call with a different story than the
  /// one the session already tells (FR-034).
  Future<Result<Assessment>> request(Session session);

  Future<Assessment?> forSession(String sessionId);

  /// Local only (FR-031a) — sets `disputed`/`disputedAt`, emits the event,
  /// uploads nothing, and shows no consent prompt, because FR-031b forbids
  /// asking for consent the app will not act on.
  Future<void> recordDispute(String sessionId);
}
