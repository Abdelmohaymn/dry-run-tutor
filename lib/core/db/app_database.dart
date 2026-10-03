import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'converters.dart';
import 'dao/assessment_dao.dart';
import 'dao/config_dao.dart';
import 'dao/event_dao.dart';
import 'dao/install_dao.dart';
import 'dao/message_dao.dart';
import 'dao/outbox_dao.dart';
import 'dao/problem_dao.dart';
import 'dao/session_dao.dart';
import 'dao/streak_dao.dart';
import 'tables.dart';
import '../config/brand.dart';

part 'app_database.g.dart';

/// The one Drift database. Everything retained indefinitely lives here:
/// sessions, messages, drafts, assessments, the outbox, the streak, the
/// config cache, and the analytics buffer.
///
/// Schema version 1 at launch (data-model.md §13). Migrations must be
/// additive where possible and must never destroy a table holding a
/// completed session — `test/db/migration_test.dart` asserts a seeded
/// completed session survives every version pair intact.
@DriftDatabase(
  tables: [
    InstallIdentity,
    CachedProblems,
    Sessions,
    Messages,
    Drafts,
    Assessments,
    Outbox,
    StreakDays,
    CachedConfig,
    BufferedEvents,
  ],
  daos: [
    InstallDao,
    SessionDao,
    MessageDao,
    ProblemDao,
    StreakDao,
    OutboxDao,
    EventDao,
    ConfigDao,
    AssessmentDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Opens an in-memory database, for tests and for the migration harness.
  AppDatabase.forTesting(super.executor);

  /// v2 adds `CachedProblems.examplesJson` — additive, nullable, and on
  /// the problem *cache*, which is refetched from the manifest anyway.
  ///
  /// v3 adds `Sessions.isPractice`, defaulted false, so every session
  /// retained before the onboarding walkthrough became a real conversation
  /// keeps reading as exactly what it was: one of the days.
  ///
  /// v4 adds `Drafts.repaired`, nullable with no backfill — `null` decodes
  /// to "repair never ran", which is true for every draft written before
  /// feature 004 (data-model.md §4).
  ///
  /// Nothing retained (a completed session, its messages, its assessment,
  /// its streak day) is touched by either; `test/db/migration_test.dart`
  /// asserts exactly that.
  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        // Each step is bounded at both ends. In production `to` is always
        // `schemaVersion`, so the upper guard changes nothing there — it
        // is what lets `test/db/migration_test.dart` exercise one version
        // pair at a time on a database that already has the later columns.
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2 && to >= 2) {
            await m.addColumn(cachedProblems, cachedProblems.examplesJson);
          }
          if (from < 3 && to >= 3) {
            await m.addColumn(sessions, sessions.isPractice);
          }
          if (from < 4 && to >= 4) {
            await m.addColumn(drafts, drafts.repaired);
          }
          // Heals the duplicate rows that reached devices before
          // `InstallDao`/`ConfigDao` pinned their id. Both tables key on a
          // rowid alias, so every write that omitted the id appended
          // instead of replacing; two rows made `getSingleOrNull()` throw
          // on every read, and that read sits under every relay call the
          // app makes.
          //
          // Install identity keeps the OLDEST row — that is the identity
          // the relay minted first, and the taster it carries. The cached
          // config keeps the NEWEST, because the point of that row is to
          // be the last config served.
          if (from < 5 && to >= 5) {
            await m.database.customStatement(
              'DELETE FROM install_identity WHERE id <> (SELECT MIN(id) FROM install_identity)',
            );
            await m.database.customStatement('UPDATE install_identity SET id = 1');
            await m.database.customStatement(
              'DELETE FROM cached_config WHERE id <> '
              '(SELECT id FROM cached_config ORDER BY fetched_at DESC, id DESC LIMIT 1)',
            );
            await m.database.customStatement('UPDATE cached_config SET id = 1');
          }
        },
      );

  /// FR-039f's wipe, minus `InstallIdentity`: preserving that row is what
  /// keeps a wipe from also resetting install identity and, with it,
  /// restoring the taster (`SettingsRepositoryImpl.wipeAllData`). Every
  /// other retained table — including `StreakDays`, so the wipe's
  /// warning that "the streak ends" is literally true — is cleared.
  Future<void> wipeAllExceptInstallIdentity() {
    return transaction(() async {
      await delete(cachedProblems).go();
      await delete(sessions).go();
      await delete(messages).go();
      await delete(drafts).go();
      await delete(assessments).go();
      await delete(outbox).go();
      await delete(streakDays).go();
      await delete(cachedConfig).go();
      await delete(bufferedEvents).go();
    });
  }
}

QueryExecutor _openConnection() {
  return driftDatabase(name: AppBrand.databaseName);
}
