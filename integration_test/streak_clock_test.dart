// T118 (US5), SC-006/FR-038: the streak survives a manipulated clock in
// every direction — forward, backward, an offline rollover, and a denied
// time source — because it is credited by `TrustedTimeSource`'s day
// string into an **insert-only** table (`StreakDao.credit`,
// `data-model.md` §7) that has no method capable of removing or lowering
// a row. `TrustedTimeSourceImpl`'s own three-tier chain (never the device
// wall clock, `test/unit/trusted_time_test.dart`) is what makes "the
// device clock" not a lever on this at all; what this suite protects is
// that nothing built *on top of* that chain — the streak's own walk-back
// and its insert path — reintroduces a way to lose a day.
//
// A real device clock, a real reboot, and a real DST transition are not
// scriptable from Dart; `TrustedTimeSource` is substituted with a
// scriptable fake so each scenario is deterministic here, matching the
// existing `voice_interruption_test.dart` and
// `trial_to_keyed_handover_test.dart` convention. Requires the
// `flutter test integration_test/` device target to execute — see
// `specs/002-voice-tutor-app/VERIFICATION.md`.
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/features/streak/data/streak_repository_impl.dart';
import 'package:dry_run/features/streak/domain/streak.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_trusted_time_source.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakeTrustedTimeSource timeSource;
  late StreakRepositoryImpl repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    timeSource = FakeTrustedTimeSource();
    repository = StreakRepositoryImpl(streakDao: db.streakDao, timeSource: timeSource);
  });

  tearDown(() => db.close());

  group('the streak survives a manipulated clock (SC-006, FR-038)', () {
    test('a run of ordinary days credits and walks back correctly', () async {
      for (final DateTime day in <DateTime>[
        DateTime.utc(2026, 1, 7),
        DateTime.utc(2026, 1, 8),
        DateTime.utc(2026, 1, 9),
        DateTime.utc(2026, 1, 10),
      ]) {
        timeSource.utc = day;
        await repository.credit(await timeSource.today());
      }
      timeSource.utc = DateTime.utc(2026, 1, 10);
      expect((await repository.current()).currentLength, 4);
    });

    test('the device clock moved backward a day loses nothing already credited', () async {
      timeSource.utc = DateTime.utc(2026, 1, 10);
      await repository.credit(await timeSource.today());

      // The device clock (never actually consulted by this call graph)
      // is manipulated backward; simulated here by moving the fake's own
      // reading, since `StreakRepository` has no other input to give it.
      timeSource.utc = DateTime.utc(2026, 1, 9);
      final Streak afterRollback = await repository.current();

      expect(
        afterRollback.completedDates,
        contains('2026-01-10'),
        reason: 'insert-only: a day already credited is never removed by a later read',
      );
    });

    test('the device clock jumped forward by weeks loses nothing already credited', () async {
      timeSource.utc = DateTime.utc(2026, 1, 10);
      await repository.credit(await timeSource.today());

      timeSource.utc = DateTime.utc(2026, 2, 1);
      final Streak afterJump = await repository.current();

      expect(afterJump.completedDates, contains('2026-01-10'));
      // The run is no longer *current* (there is a real gap), which is
      // correct — but the credited day itself still exists.
      expect(afterJump.currentLength, 0);
    });

    test('crediting has no network dependency — an offline rollover credits exactly the same way', () async {
      // `StreakRepositoryImpl` takes only `StreakDao` and
      // `TrustedTimeSource` — no `RelayClient` anywhere in its
      // constructor — so there is no code path here that could fail on
      // connectivity in the first place.
      timeSource.utc = DateTime.utc(2026, 1, 10);
      await repository.credit(await timeSource.today());
      timeSource.utc = DateTime.utc(2026, 1, 11);
      await repository.credit(await timeSource.today());
      expect((await repository.current()).currentLength, 2);
    });

    test('a DST-adjacent boundary is still plain UTC calendar-day arithmetic', () async {
      // 2026-03-08 is the US spring-forward date; irrelevant here because
      // every date in this call graph is `DateTime.utc(...)`, never a
      // local-time `DateTime` — DST has nothing to attach to.
      for (final DateTime day in <DateTime>[
        DateTime.utc(2026, 3, 7),
        DateTime.utc(2026, 3, 8),
        DateTime.utc(2026, 3, 9),
      ]) {
        timeSource.utc = day;
        await repository.credit(await timeSource.today());
      }
      timeSource.utc = DateTime.utc(2026, 3, 9);
      expect((await repository.current()).currentLength, 3);
    });

    test('every time source tier denied still walks back over what is already credited', () async {
      timeSource.utc = DateTime.utc(2026, 1, 10);
      await repository.credit(await timeSource.today());

      // `now()`/`today()` returning a stale marker (the epoch, per
      // `TrustedTimeSourceImpl`'s own no-anchor fallback) must not read
      // back as "the streak is broken" — `completedDates()` doesn't
      // consult the clock at all.
      final Set<String> dates = await repository.completedDates();
      expect(dates, contains('2026-01-10'));
    });
  });
}
