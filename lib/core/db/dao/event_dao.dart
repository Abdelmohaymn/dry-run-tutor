import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'event_dao.g.dart';

/// Data access for the analytics buffer. `AnalyticsClient` validates a
/// prop map against the schema's limits *before* it ever reaches this DAO
/// (FR-050/FR-051) — this layer only stores and drains what has already
/// been accepted.
@DriftAccessor(tables: [BufferedEvents])
class EventDao extends DatabaseAccessor<AppDatabase> with _$EventDaoMixin {
  EventDao(super.db);

  Future<void> insertEvent(BufferedEventsCompanion entry) {
    return into(bufferedEvents).insert(entry);
  }

  /// Up to [limit] events, oldest first — the schema's ≤100-per-batch
  /// ceiling.
  Future<List<BufferedEvent>> due({int limit = 100}) {
    return (select(bufferedEvents)
          ..orderBy([(t) => OrderingTerm.asc(t.clientTs)])
          ..limit(limit))
        .get();
  }

  Future<void> incrementAttempts(String id) async {
    await customUpdate(
      'UPDATE buffered_events SET attempts = attempts + 1 WHERE id = ?1',
      variables: [Variable<String>(id)],
      updates: {bufferedEvents},
    );
  }

  /// Drops a batch that the relay accepted, or one that has exhausted its
  /// bounded retry attempts (FR-051 — a rejected batch changes nothing
  /// visible; it is dropped, not surfaced).
  Future<void> removeMany(List<String> ids) {
    return (delete(bufferedEvents)..where((t) => t.id.isIn(ids))).go();
  }
}
