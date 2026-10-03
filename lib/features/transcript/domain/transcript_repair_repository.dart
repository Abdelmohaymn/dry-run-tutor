import '../../chat/domain/session.dart';

/// `POST /v1/repair` on the learner's own key. FR-006 is implemented here:
/// [repair] returns `null` on every failure — a rejected key, a rate limit,
/// a malformed upstream body, an offline device, a trial-path session — and
/// **never throws**, so nothing above this layer has to remember to fail
/// open (plan.md §The hold window).
abstract interface class TranscriptRepairRepository {
  /// Returns the corrected transcript, or `null` when repair did not run,
  /// did not change anything, or failed in any way.
  Future<String?> repair({required Session session, required String transcript});
}
