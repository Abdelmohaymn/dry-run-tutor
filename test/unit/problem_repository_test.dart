import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/network/dto/problem_dto.dart';
import 'package:dry_run/features/problem/data/problem_repository_impl.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_install_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

PublicHalfDto _dto(String id, {List<String>? collections}) => PublicHalfDto(
      schemaVersion: 2,
      id: id,
      title: 'Title $id',
      ramp: 'easy',
      tags: const <String>[],
      source: 'authored',
      statement: 'statement for $id',
      constraints: const <String>[],
      estSpeakSeconds: 60,
      collections: collections,
      glossaryTerms: const <String>[],
      hintCount: 2,
    );

void main() {
  late AppDatabase db;
  late MockRelayClient relay;
  late ProblemRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relay = MockRelayClient();
    repository = ProblemRepositoryImpl(
      relayClient: relay,
      problemDao: db.problemDao,
      timeSource: FakeTrustedTimeSource(),
      installRepository: FakeInstallRepository(),
    );
  });

  tearDown(() => db.close());

  test('fetchDaily stores manifestDate = date, returns the problem, and cachedForDate finds it', () async {
    when(() => relay.daily(installId: 'fake-install-id', date: '2026-01-10')).thenAnswer(
      (_) async => DailyResponseDto(date: '2026-01-10', problem: _dto('vp-0007')),
    );

    final Problem problem = await repository.fetchDaily('2026-01-10');

    expect(problem.id, 'vp-0007');
    expect((await db.problemDao.byId('vp-0007'))!.manifestDate, '2026-01-10');
    expect((await repository.cachedForDate('2026-01-10'))!.id, 'vp-0007');
    expect(await repository.cachedForDate('2026-01-11'), isNull);
  });

  test('fetchPractice stores the warm-up with no date and practiceProblem finds it', () async {
    when(() => relay.practice()).thenAnswer(
      (_) async => PracticeResponseDto(problem: _dto('vp-0000', collections: <String>['practice'])),
    );

    await repository.fetchPractice();

    expect((await db.problemDao.byId('vp-0000'))!.manifestDate, isNull);
    expect((await repository.practiceProblem())!.id, 'vp-0000');
    expect(await repository.hasAnyCached(), isTrue);
  });
}
