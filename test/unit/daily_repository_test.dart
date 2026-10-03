// T148 (US7): the repeat path end to end — the library exhausted, today a
// problem already attempted, `isRepeat` set on the selection (FR-035c) so
// it is recorded locally, while nothing about the selection itself marks
// the problem differently for a widget to find (FR-035b — no widget reads
// `Session.isRepeat`; grepped separately, not re-asserted here).
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/daily/domain/daily_repository.dart';
import 'package:dry_run/features/daily/domain/daily_selection.dart';
import 'package:dry_run/features/problem/data/problem_repository_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>['vp-0003'],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

RuntimeConfig _configWith(RotationConfig rotation) => RuntimeConfig(
      minSupportedVersion: _config.minSupportedVersion,
      killedProblemIds: _config.killedProblemIds,
      contentManifestUrl: _config.contentManifestUrl,
      chat: _config.chat,
      trial: _config.trial,
      keyedProviders: _config.keyedProviders,
      rotation: rotation,
    );

Future<void> _insertProblem(AppDatabase db, {required String id, String? date}) {
  return db.problemDao.upsertAll(<CachedProblemsCompanion>[
    CachedProblemsCompanion.insert(
      problemId: id,
      schemaVersion: 2,
      title: id,
      ramp: 'easy',
      tags: const <String>[],
      source: 'authored',
      statement: 'statement for $id',
      constraints: const <String>[],
      estSpeakSeconds: 60,
      collections: const <String>[],
      glossaryTerms: const <String>[],
      hintCount: 0,
      manifestDate: Value(date),
      fetchedAt: DateTime.utc(2026, 1, 1),
    ),
  ]);
}

void main() {
  late AppDatabase db;
  late FakeTrustedTimeSource timeSource;
  late FakeRemoteConfigRepository configRepository;
  late DailyRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    timeSource = FakeTrustedTimeSource()..utc = DateTime.utc(2026, 1, 10);
    configRepository = FakeRemoteConfigRepository()..cachedValue = _config;
    repository = DailyRepositoryImpl(
      problemRepository: ProblemRepositoryImpl(
        relayClient: MockRelayClient(),
        problemDao: db.problemDao,
        timeSource: timeSource,
        configRepository: configRepository,
      ),
      sessionDao: db.sessionDao,
      configRepository: configRepository,
      timeSource: timeSource,
    );
  });

  tearDown(() => db.close());

  test("today's authored problem is picked first when it exists and is not withdrawn", () async {
    await _insertProblem(db, id: 'vp-0001', date: '2026-01-10');
    await _insertProblem(db, id: 'vp-0002');

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0001');
    expect(selection.isRepeat, isFalse);
  });

  test('withdrawn problems are excluded even when authored for exactly today (FR-040)', () async {
    await _insertProblem(db, id: 'vp-0003', date: '2026-01-10'); // killed in _config
    await _insertProblem(db, id: 'vp-0004');

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0004');
  });

  test('an untouched evergreen problem is preferred over a repeat', () async {
    await _insertProblem(db, id: 'vp-0010');
    await _insertProblem(db, id: 'vp-0011');
    await db.sessionDao.insertSession(
      SessionsCompanion.insert(
        id: 's1',
        problemId: 'vp-0010',
        day: '2026-01-09',
        path: SessionPath.trial,
        status: SessionStatus.complete,
        startedAt: DateTime.utc(2026, 1, 9),
      ),
    );

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0011');
    expect(selection.isRepeat, isFalse);
  });

  test(
    'library exhausted: returns to an already-attempted problem, deterministically, flagged isRepeat (FR-035b/c)',
    () async {
      await _insertProblem(db, id: 'vp-0020');
      await _insertProblem(db, id: 'vp-0021');
      for (final String id in <String>['vp-0020', 'vp-0021']) {
        await db.sessionDao.insertSession(
          SessionsCompanion.insert(
            id: 'done-$id',
            problemId: id,
            day: '2026-01-0${id == 'vp-0020' ? 8 : 9}',
            path: SessionPath.trial,
            status: SessionStatus.complete,
            startedAt: DateTime.utc(2026, 1, 9),
          ),
        );
      }

      final DailySelection selection = await repository.forToday();

      expect(selection.isRepeat, isTrue);
      // Deterministic (lowest id) rather than arbitrary, so two installs
      // hitting exhaustion on the same day land on the same problem.
      expect(selection.problem.id, 'vp-0020');
    },
  );

  test('no cached problem at all throws NoProblemAvailableException, not a bare crash', () async {
    expect(() => repository.forToday(), throwsA(isA<NoProblemAvailableException>()));
  });

  group('the operator pointer (FR-035d)', () {
    Future<void> seedPool() async {
      // Inserted out of order on purpose: the pointer indexes the
      // id-sorted pool, never SQLite's row order.
      for (final String id in <String>['vp-0002', 'vp-0000', 'vp-0001']) {
        await _insertProblem(db, id: id);
      }
    }

    void usePointer({String start = 'vp-0000', String anchor = '2026-01-10'}) {
      configRepository.cachedValue = _configWith(
        RotationConfig(startProblemId: start, anchorDate: anchor),
      );
    }

    test('on the anchor day everyone gets the start problem', () async {
      await seedPool();
      usePointer();

      expect((await repository.forToday()).problem.id, 'vp-0000');
    });

    test('advances one problem per elapsed day with no write of any kind', () async {
      await seedPool();
      usePointer();

      timeSource.utc = DateTime.utc(2026, 1, 12);

      expect((await repository.forToday()).problem.id, 'vp-0002');
    });

    test('wraps around the end of the pool', () async {
      await seedPool();
      usePointer();

      timeSource.utc = DateTime.utc(2026, 1, 13); // 3 days on, pool of 3

      expect((await repository.forToday()).problem.id, 'vp-0000');
    });

    test('a fresh install and a long-standing one land on the same problem', () async {
      await seedPool();
      usePointer();
      timeSource.utc = DateTime.utc(2026, 1, 11);

      // A history that WOULD have pushed the per-install fallback past
      // vp-0001 entirely.
      for (final String id in <String>['vp-0000', 'vp-0001']) {
        await db.sessionDao.insertSession(
          SessionsCompanion.insert(
            id: 'done-$id',
            problemId: id,
            day: '2026-01-09',
            path: SessionPath.trial,
            status: SessionStatus.complete,
            startedAt: DateTime.utc(2026, 1, 9),
          ),
        );
      }

      final DailySelection selection = await repository.forToday();

      expect(selection.problem.id, 'vp-0001');
      // Same problem for everyone, but this install has seen it before —
      // recorded locally (FR-035c), invisible on screen (FR-035b).
      expect(selection.isRepeat, isTrue);
    });

    test('moving the pointer back restarts every install at the first problem', () async {
      await seedPool();
      timeSource.utc = DateTime.utc(2026, 1, 20);
      usePointer(); // ten days in

      expect((await repository.forToday()).problem.id, 'vp-0001');

      // The one operator write: start back at the first id, anchor today.
      usePointer(start: 'vp-0000', anchor: '2026-01-20');

      expect((await repository.forToday()).problem.id, 'vp-0000');
    });

    test('a withdrawn start_problem_id degrades to the top of the pool, not to nothing', () async {
      await seedPool();
      usePointer(start: 'vp-0003'); // killed in _config, so not in the pool

      expect((await repository.forToday()).problem.id, 'vp-0000');
    });

    test('a device behind the anchor clamps to the start rather than indexing backwards', () async {
      await seedPool();
      usePointer(anchor: '2026-02-01'); // anchor in the future

      expect((await repository.forToday()).problem.id, 'vp-0000');
    });

    test('a problem authored for exactly today still outranks the pointer', () async {
      await seedPool();
      await _insertProblem(db, id: 'vp-0009', date: '2026-01-10');
      usePointer();

      expect((await repository.forToday()).problem.id, 'vp-0009');
    });

    test('no pointer leaves the per-install walk untouched', () async {
      await seedPool();
      await db.sessionDao.insertSession(
        SessionsCompanion.insert(
          id: 'done',
          problemId: 'vp-0000',
          day: '2026-01-09',
          path: SessionPath.trial,
          status: SessionStatus.complete,
          startedAt: DateTime.utc(2026, 1, 9),
        ),
      );

      expect((await repository.forToday()).problem.id, 'vp-0001');
    });
  });
}
