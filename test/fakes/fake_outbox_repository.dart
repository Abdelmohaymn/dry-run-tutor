import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/queue/outbox_item.dart';
import 'package:dry_run/core/queue/outbox_repository.dart';

/// A plain, in-memory fake — records every enqueue call so a test can
/// assert a transport failure actually queued (or didn't).
class FakeOutboxRepository implements OutboxRepository {
  final List<OutboxItem> enqueued = <OutboxItem>[];
  int _nextId = 0;

  @override
  Future<void> enqueue({
    required String sessionId,
    required OutboxKind kind,
    required Map<String, Object?> payload,
    required int solutionRequestCountAtEnqueue,
  }) async {
    enqueued.add(
      OutboxItem(
        id: 'outbox-${_nextId++}',
        sessionId: sessionId,
        kind: kind,
        payload: payload,
        solutionRequestCountAtEnqueue: solutionRequestCountAtEnqueue,
        attempts: 0,
        nextEligibleAt: DateTime.utc(2026, 1, 1),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  @override
  Future<List<OutboxItem>> due(DateTime trustedNow) async =>
      enqueued.where((OutboxItem i) => !i.nextEligibleAt.isAfter(trustedNow)).toList();

  @override
  Future<List<OutboxItem>> forSession(String sessionId) async =>
      enqueued.where((OutboxItem i) => i.sessionId == sessionId).toList();

  @override
  Future<void> markAttempted({required String id, required DateTime nextEligibleAt, String? lastErrorCode}) async {
    final int index = enqueued.indexWhere((OutboxItem i) => i.id == id);
    if (index == -1) {
      return;
    }
    final OutboxItem current = enqueued[index];
    enqueued[index] = OutboxItem(
      id: current.id,
      sessionId: current.sessionId,
      kind: current.kind,
      payload: current.payload,
      solutionRequestCountAtEnqueue: current.solutionRequestCountAtEnqueue,
      attempts: current.attempts,
      nextEligibleAt: nextEligibleAt,
      lastErrorCode: lastErrorCode,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> incrementAttempts(String id) async {
    final int index = enqueued.indexWhere((OutboxItem i) => i.id == id);
    if (index == -1) {
      return;
    }
    final OutboxItem current = enqueued[index];
    enqueued[index] = OutboxItem(
      id: current.id,
      sessionId: current.sessionId,
      kind: current.kind,
      payload: current.payload,
      solutionRequestCountAtEnqueue: current.solutionRequestCountAtEnqueue,
      attempts: current.attempts + 1,
      nextEligibleAt: current.nextEligibleAt,
      lastErrorCode: current.lastErrorCode,
      createdAt: current.createdAt,
    );
  }

  @override
  Future<void> remove(String id) async {
    enqueued.removeWhere((OutboxItem i) => i.id == id);
  }
}
