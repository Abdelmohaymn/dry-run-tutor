// Retention that is invisible (FR-039c/e, data-model.md §13): a completed
// session, its messages, its assessment, and its streak day must survive
// every schema version pair intact. Destroying retained history quietly in
// a migration is exactly how an "indefinite" promise breaks.
//
// The schema is at version 6. v2 adds the nullable
// `CachedProblems.examplesJson`; v3 adds `Sessions.isPractice`, defaulted
// false; v4 adds the nullable `Drafts.repaired` (feature 004). Those three
// are additive and touch nothing retained. v5 is the first that deletes:
// it dedupes `install_identity` and `cached_config`, which appended a row
// per write until their ids were pinned. v6 (feature 006) clears
// `install_identity` (identity is now a hash of the Android ID) and drops
// the analytics `buffered_events` table. Extend rather than rewrite when a
// v7 lands — bump `AppDatabase.schemaVersion`, add the migration step, and
// add a case to the migration test below.
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/db/converters.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migration_test — a completed session survives intact', () {
    test('every retained table round-trips through the current schema', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      await _expectSessionIntact(db);
    });

    test('schemaVersion is 6 — the floor this test suite assumes', () {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      expect(db.schemaVersion, 6);
    });

    test('the v1 -> v2 migration adds examplesJson and keeps the row', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      // The upgrade path itself, run against a database that already holds
      // a completed session: `addColumn` must not rewrite or drop it.
      await db.customStatement('ALTER TABLE cached_problems DROP COLUMN examples_json');
      await db.migration.onUpgrade(Migrator(db), 1, 2);

      await _expectSessionIntact(db);
      final CachedProblem problem = await db.select(db.cachedProblems).getSingle();
      expect(problem.examplesJson, isNull);
      expect(problem.title, 'Two Sum');
    });

    test('the v2 -> v3 migration adds isPractice and keeps the row', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      await db.customStatement('ALTER TABLE sessions DROP COLUMN is_practice');
      await db.migration.onUpgrade(Migrator(db), 2, 3);

      await _expectSessionIntact(db);
      final SessionRow session = await db.select(db.sessions).getSingle();
      // The default is what makes this migration safe: every session
      // retained before the walkthrough became a real conversation still
      // reads as one of the days, which is what it was.
      expect(session.isPractice, isFalse);
    });

    test('the v3 -> v4 migration adds repaired and keeps the row', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      await db.customStatement('ALTER TABLE drafts DROP COLUMN repaired');
      await db.migration.onUpgrade(Migrator(db), 3, 4);

      await _expectSessionIntact(db);
    });

    test('the v4 -> v5 migration leaves one install identity and one config', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      // Exactly what reached the device: every write appended, because
      // `id` is a rowid alias and the insert left it out.
      await db.customStatement(
        "INSERT INTO install_identity (id, install_uuid, install_id, minted_at) "
        "VALUES (1, 'uuid-a', 'id-a', 1000), (2, 'uuid-a', 'id-a', 1000)",
      );
      await db.customStatement(
        "INSERT INTO cached_config (id, json, etag, fetched_at) "
        "VALUES (1, '{\"v\":1}', NULL, 1000), (2, '{\"v\":2}', NULL, 2000)",
      );

      await db.migration.onUpgrade(Migrator(db), 4, 5);

      final InstallIdentityRow identity = await db.select(db.installIdentity).getSingle();
      expect(identity.id, 1);
      // The oldest survives: that is the identity the relay minted first,
      // and the taster it carries.
      expect(identity.installId, 'id-a');

      final CachedConfigData config = await db.select(db.cachedConfig).getSingle();
      expect(config.id, 1);
      // The newest survives: the point of this row is the last config
      // the relay served.
      expect(config.json, '{"v":2}');

      await _expectSessionIntact(db);
    });

    test('v5 is a no-op on a database that never duplicated', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await db.customStatement(
        "INSERT INTO install_identity (id, install_uuid, install_id, minted_at) "
        "VALUES (1, 'uuid-a', 'id-a', 1000)",
      );
      await db.migration.onUpgrade(Migrator(db), 4, 5);

      final InstallIdentityRow identity = await db.select(db.installIdentity).getSingle();
      expect(identity.installId, 'id-a');
      // An empty cached_config must survive the delete untouched rather
      // than tripping over its own subquery.
      expect(await db.select(db.cachedConfig).get(), isEmpty);
    });

    test('the v5 -> v6 migration clears the old install identity, drops buffered_events, and keeps the session', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      await db.customStatement(
        "INSERT INTO install_identity (id, install_uuid, install_id, minted_at) "
        "VALUES (1, 'uuid-a', 'id-a', 1000)",
      );
      // The analytics buffer a v5 device still carries; the v6 schema no
      // longer declares it, so it is created by hand here.
      await db.customStatement(
        'CREATE TABLE buffered_events (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, '
        'client_ts TEXT NOT NULL, props TEXT, attempts INTEGER NOT NULL DEFAULT 0)',
      );
      await db.customStatement(
        "INSERT INTO buffered_events (id, name, client_ts) VALUES ('e1', 'app_open', '2026-01-01T00:00:00Z')",
      );

      await db.migration.onUpgrade(Migrator(db), 5, 6);

      expect(await db.select(db.installIdentity).get(), isEmpty);
      final List<QueryRow> leftover = await db
          .customSelect("SELECT name FROM sqlite_master WHERE name = 'buffered_events'")
          .get();
      expect(leftover, isEmpty);
      await _expectSessionIntact(db);
    });

    test('a v1 database upgraded straight to v6 keeps its session', () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      await _seedCompletedSession(db);
      await db.customStatement('ALTER TABLE cached_problems DROP COLUMN examples_json');
      await db.customStatement('ALTER TABLE sessions DROP COLUMN is_practice');
      await db.customStatement('ALTER TABLE drafts DROP COLUMN repaired');
      await db.migration.onUpgrade(Migrator(db), 1, 6);

      await _expectSessionIntact(db);
      final SessionRow session = await db.select(db.sessions).getSingle();
      expect(session.isPractice, isFalse);
    });
  });
}

Future<void> _seedCompletedSession(AppDatabase db) async {
  await db.into(db.cachedProblems).insert(
        CachedProblemsCompanion.insert(
          problemId: 'vp-0001',
          schemaVersion: 2,
          title: 'Two Sum',
          ramp: 'easy',
          tags: const <String>['arrays'],
          source: 'authored',
          statement: 'Given an array...',
          constraints: const <String>['1 <= n <= 1e5'],
          estSpeakSeconds: 60,
          collections: const <String>['warmup'],
          glossaryTerms: const <String>['hashmap'],
          hintCount: 3,
          fetchedAt: DateTime.utc(2026, 1, 1),
        ),
      );

  await db.into(db.sessions).insert(
        SessionsCompanion.insert(
          id: 'session-1',
          problemId: 'vp-0001',
          day: '2026-01-01',
          path: SessionPath.keyed,
          status: SessionStatus.complete,
          startedAt: DateTime.utc(2026, 1, 1, 9),
          completedAt: Value(DateTime.utc(2026, 1, 1, 9, 20)),
          turnIndex: const Value(4),
          turnsRemaining: const Value(6),
          hintsRevealed: const Value(1),
          hintsRemaining: const Value(2),
          sessionEnded: const Value('user'),
        ),
      );

  await db.into(db.messages).insert(
        MessagesCompanion.insert(
          id: 'message-1',
          sessionId: 'session-1',
          seq: 0,
          role: TurnRole.user,
          body: 'I would use a hashmap to track seen values.',
          kind: MessageKind.turn,
          delivery: Delivery.sent,
          createdAt: DateTime.utc(2026, 1, 1, 9, 1),
        ),
      );

  await db.into(db.assessments).insert(
        AssessmentsCompanion.insert(
          sessionId: 'session-1',
          matchedApproach: 'hashmap',
          matchedVerdict: MatchedVerdict.optimal,
          insightsHit: const <String>['recognised O(n)'],
          insightsMissed: const <String>[],
          wrongTurnsTaken: const <String>[],
          complexityJson: '{"referenceTime":"O(n)","referenceSpace":"O(n)"}',
          verdict: Verdict.strongPass,
          confidence: 0.9,
          feedback: 'Solid approach, clearly explained.',
          editorial: '# Two Sum\n\nThe canonical approach is a hashmap...',
          rawJson: '{"matched_approach":"hashmap"}',
          receivedAt: DateTime.utc(2026, 1, 1, 9, 21),
        ),
      );

  await db.into(db.streakDays).insert(
        StreakDaysCompanion.insert(
          day: '2026-01-01',
          creditedAt: DateTime.utc(2026, 1, 1, 9, 20),
        ),
      );
}

Future<void> _expectSessionIntact(AppDatabase db) async {
  final SessionRow? session =
      await (db.select(db.sessions)..where((t) => t.id.equals('session-1')))
          .getSingleOrNull();
  expect(session, isNotNull);
  expect(session!.status, SessionStatus.complete);
  expect(session.turnIndex, 4);
  expect(session.turnsRemaining, 6);

  final List<MessageRow> messages = await (db.select(db.messages)
        ..where((t) => t.sessionId.equals('session-1')))
      .get();
  expect(messages, hasLength(1));
  expect(messages.single.body, 'I would use a hashmap to track seen values.');

  final AssessmentRow? assessment = await (db.select(db.assessments)
        ..where((t) => t.sessionId.equals('session-1')))
      .getSingleOrNull();
  expect(assessment, isNotNull);
  expect(assessment!.editorial, contains('canonical approach'));
  expect(assessment.rawJson, '{"matched_approach":"hashmap"}');

  final Set<String> completedDates = (await db.select(db.streakDays).get())
      .map((StreakDay r) => r.day)
      .toSet();
  expect(completedDates, contains('2026-01-01'));
}
