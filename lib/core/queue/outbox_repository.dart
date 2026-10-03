import '../models/wire_enums.dart';
import 'outbox_item.dart';

/// The offline queue's one repository — `core/queue` is cross-feature
/// machinery, injected through this interface rather than reached for as
/// `OutboxDao` directly (contracts/repositories.md's architecture rule).
abstract interface class OutboxRepository {
  Future<void> enqueue({
    required String sessionId,
    required OutboxKind kind,
    required Map<String, Object?> payload,
    required int solutionRequestCountAtEnqueue,
  });

  /// Rows eligible to send right now, oldest first.
  Future<List<OutboxItem>> due(DateTime trustedNow);

  /// Every queued row for one session, oldest first — what the drain
  /// worker serialises against so a queued turn never races a queued
  /// judge for the same session.
  Future<List<OutboxItem>> forSession(String sessionId);

  Future<void> markAttempted({
    required String id,
    required DateTime nextEligibleAt,
    String? lastErrorCode,
  });

  Future<void> incrementAttempts(String id);

  Future<void> remove(String id);
}
