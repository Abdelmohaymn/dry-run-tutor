// The daily problem is picked by the relay (`GET /v1/daily`); the app only
// caches what it was served and answers `isRepeat` from local history
// (FR-035c). The pick itself — dated problem, pointer, day-number
// fallback — is covered on the Worker by `daily-pick.test.ts`.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/daily/domain/daily_repository.dart';
import 'package:dry_run/features/daily/domain/daily_selection.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_problem_repository.dart';
import '../fakes/fake_trusted_time_source.dart';

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>['vp-0003'],
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

Problem _problem(String id) => Problem(
      schemaVersion: 2,
      id: id,
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
    );

void main() {
  late AppDatabase db;
  late FakeTrustedTimeSource timeSource;
  late FakeRemoteConfigRepository configRepository;
  late FakeProblemRepository problemRepository;
  late DailyRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    timeSource = FakeTrustedTimeSource()..utc = DateTime.utc(2026, 1, 10);
    configRepository = FakeRemoteConfigRepository()..cachedValue = _config;
    problemRepository = FakeProblemRepository();
    repository = DailyRepositoryImpl(
      problemRepository: problemRepository,
      sessionDao: db.sessionDao,
      configRepository: configRepository,
      timeSource: timeSource,
    );
  });

  tearDown(() => db.close());

  test('cached for today and not withdrawn: served from the cache, no fetch', () async {
    problemRepository.cachedByDate['2026-01-10'] = _problem('vp-0001');

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0001');
    expect(selection.isRepeat, isFalse);
    expect(problemRepository.fetchDailyCalls, isEmpty);
  });

  test('cached for today but withdrawn since: refetched from the relay (FR-040)', () async {
    problemRepository.cachedByDate['2026-01-10'] = _problem('vp-0003'); // killed in _config
    problemRepository.fetchDailyResult = _problem('vp-0004');

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0004');
    expect(problemRepository.fetchDailyCalls, <String>['2026-01-10']);
  });

  test("nothing cached: fetches today's problem from the relay", () async {
    problemRepository.fetchDailyResult = _problem('vp-0002');

    final DailySelection selection = await repository.forToday();

    expect(selection.problem.id, 'vp-0002');
    expect(problemRepository.fetchDailyCalls, <String>['2026-01-10']);
  });

  test('isRepeat is a local fact: true when this install already completed the problem (FR-035c)', () async {
    problemRepository.fetchDailyResult = _problem('vp-0010');
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

    expect(selection.problem.id, 'vp-0010');
    expect(selection.isRepeat, isTrue);
  });

  test('relay says every problem is withdrawn: NoProblemAvailableException', () async {
    problemRepository.fetchDailyError = const RelayError.problemKilled(problemId: '');

    expect(() => repository.forToday(), throwsA(isA<NoProblemAvailableException>()));
  });

  test('offline with nothing cached: NoProblemAvailableException, not a bare crash', () async {
    problemRepository.fetchDailyError = const RelayError.transport();

    expect(() => repository.forToday(), throwsA(isA<NoProblemAvailableException>()));
  });
}
