import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'config_dao.g.dart';

/// See `install_dao.dart` — `id` is a rowid alias, so an insert that omits
/// it appends rather than upserts. This table felt it hardest: every
/// successful `/v1/config` fetch wrote a row, so the second launch of a
/// fresh install was enough to break [read] permanently.
const int _singleRow = 1;

/// Data access for the single cached `/v1/config` row. Stored verbatim so
/// a key the app does not yet read is never silently dropped
/// (`RemoteConfigRepository`, FR-046's fail-open).
@DriftAccessor(tables: [CachedConfig])
class ConfigDao extends DatabaseAccessor<AppDatabase> with _$ConfigDaoMixin {
  ConfigDao(super.db);

  /// The freshest row, not `getSingleOrNull()` — see `InstallDao.read()`
  /// for why this must not throw on finding two. Newest wins here, unlike
  /// install identity: the point of this row is to be the last config the
  /// relay served.
  Future<CachedConfigData?> read() async {
    final List<CachedConfigData> rows = await (select(cachedConfig)
          ..orderBy(<OrderingTerm Function($CachedConfigTable)>[
            ($CachedConfigTable t) => OrderingTerm.desc(t.fetchedAt),
            ($CachedConfigTable t) => OrderingTerm.desc(t.id),
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> write(CachedConfigCompanion entry) {
    return into(cachedConfig)
        .insertOnConflictUpdate(entry.copyWith(id: const Value<int>(_singleRow)));
  }
}
