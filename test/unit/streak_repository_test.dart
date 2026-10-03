// T119 (US5): insert-only behaviour, the walk-back computation, and — the
// property FR-038 rests on — that no code path here can decrement.
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/features/streak/data/streak_repository_impl.dart';
import 'package:dry_run/features/streak/domain/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_trusted_time_source.dart';

void main() {
  late AppDatabase db;
  late FakeTrustedTimeSource timeSource;
  late StreakRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    timeSource = FakeTrustedTimeSource()..utc = DateTime.utc(2026, 1, 10);
    repository = StreakRepositoryImpl(streakDao: db.streakDao, timeSource: timeSource);
  });

  tearDown(() => db.close());

  test('crediting the same day twice is a no-op, not a duplicate or an error', () async {
    await repository.credit('2026-01-10');
    await repository.credit('2026-01-10');
    final Set<String> dates = await repository.completedDates();
    expect(dates, <String>{'2026-01-10'});
  });

  test('current() walks back consecutive credited days from today', () async {
    for (final String day in <String>['2026-01-07', '2026-01-08', '2026-01-09', '2026-01-10']) {
      await repository.credit(day);
    }
    final Streak streak = await repository.current();
    expect(streak.currentLength, 4);
  });

  test('a gap stops the walk-back — the streak length reflects only the consecutive run', () async {
    await repository.credit('2026-01-05');
    await repository.credit('2026-01-09');
    await repository.credit('2026-01-10');
    final Streak streak = await repository.current();
    expect(streak.currentLength, 2);
  });

  test("today not yet credited doesn't zero an existing streak — it walks back from yesterday", () async {
    await repository.credit('2026-01-08');
    await repository.credit('2026-01-09');
    // 2026-01-10 (today) is deliberately not credited yet.
    final Streak streak = await repository.current();
    expect(streak.currentLength, 2);
  });

  test('no day credited at all is a streak of zero, not an error', () async {
    final Streak streak = await repository.current();
    expect(streak.currentLength, 0);
  });
}
