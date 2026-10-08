import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'outbox_dao.g.dart';

/// Data access for the offline queue. `OutboxDrainBloc` (the one
/// event-driven `Bloc` in the app, research.md R-010) drains strictly in
/// `createdAt` order, serialised per `sessionId`.
@DriftAccessor(tables: [Outbox])
class OutboxDao extends DatabaseAccessor<AppDatabase> with _$OutboxDaoMixin {
  OutboxDao(super.db);

  Future<void> enqueue(OutboxCompanion item) {
    return into(outbox).insert(item);
  }

  Future<void> deleteForSession(String sessionId) {
    return (delete(outbox)..where((t) => t.sessionId.equals(sessionId))).go();
  }

  /// Rows eligible to send right now, oldest first.
  Future<List<OutboxData>> due(DateTime trustedNow) {
    return (select(outbox)
          ..where((t) => t.nextEligibleAt.isSmallerOrEqualValue(trustedNow))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// Every queued row for one session, oldest first — what the drain
  /// worker serialises against so a queued turn never races a queued
  /// judge for the same session.
  Future<List<OutboxData>> forSession(String sessionId) {
    return (select(outbox)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  Future<void> markAttempted({
    required String id,
    required DateTime nextEligibleAt,
    String? lastErrorCode,
  }) {
    return (update(outbox)..where((t) => t.id.equals(id))).write(
      OutboxCompanion(
        attempts: const Value.absent(),
        nextEligibleAt: Value(nextEligibleAt),
        lastErrorCode: Value(lastErrorCode),
      ),
    );
  }

  /// Increments the attempt counter separately from [markAttempted]'s
  /// timestamp/error write, since drift's `write()` cannot express
  /// `attempts = attempts + 1` alongside other column writes in one call.
  Future<void> incrementAttempts(String id) async {
    await customUpdate(
      'UPDATE outbox SET attempts = attempts + 1 WHERE id = ?1',
      variables: [Variable<String>(id)],
      updates: {outbox},
    );
  }

  Future<void> remove(String id) {
    return (delete(outbox)..where((t) => t.id.equals(id))).go();
  }
}
