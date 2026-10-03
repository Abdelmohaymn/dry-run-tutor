import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'install_dao.g.dart';

/// The one row this table is allowed to hold.
///
/// `id` is declared `INTEGER ... PRIMARY KEY`, which SQLite treats as an
/// alias for the rowid — and a rowid ignores the column's DEFAULT. An
/// insert that leaves `id` out is therefore handed `max(rowid) + 1`, so
/// `insertOnConflictUpdate` has nothing to conflict with and appends a
/// second row instead of replacing the first. Pinning the value here is
/// what makes the upsert an upsert.
const int _singleRow = 1;

/// Data access for the single install-identity row (data-model.md §1).
/// `InstallRepository.ensureIdentity()` is the only writer, and it never
/// re-mints on failure — an app that did would farm tasters (FR-001).
@DriftAccessor(tables: [InstallIdentity])
class InstallDao extends DatabaseAccessor<AppDatabase> with _$InstallDaoMixin {
  InstallDao(super.db);

  /// The oldest row, not `getSingleOrNull()`.
  ///
  /// A device that duplicated this row before [write] pinned the id would
  /// otherwise throw `StateError: Too many elements` here on every read,
  /// for good — and this read sits under `ensureIdentity()`, which sits
  /// under every relay call the app makes. Migration 5 dedupes, but a
  /// read that cannot survive finding two rows is one bad write away from
  /// bricking the app again. Oldest wins because that is the identity the
  /// relay minted first, and with it the taster it carries.
  Future<InstallIdentityRow?> read() async {
    final List<InstallIdentityRow> rows = await (select(installIdentity)
          ..orderBy(<OrderingTerm Function($InstallIdentityTable)>[
            ($InstallIdentityTable t) => OrderingTerm.asc(t.id),
          ])
          ..limit(1))
        .get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> write(InstallIdentityCompanion entry) {
    return into(installIdentity)
        .insertOnConflictUpdate(entry.copyWith(id: const Value<int>(_singleRow)));
  }
}
