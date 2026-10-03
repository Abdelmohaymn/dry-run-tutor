import 'package:dry_run/features/streak/domain/streak.dart';
import 'package:dry_run/features/streak/domain/streak_repository.dart';

class FakeStreakRepository implements StreakRepository {
  final Set<String> credited = <String>{};

  /// Overrides the length `current()` reports, independent of [credited]
  /// — most tests only care that crediting happened and what length the
  /// Cubit then emits as `streak_advanced`, not a real walk-back.
  int currentLengthOverride = 1;

  @override
  Future<void> credit(String trustedDay) async {
    credited.add(trustedDay);
  }

  @override
  Future<Set<String>> completedDates() async => credited;

  @override
  Future<Streak> current() async => Streak(currentLength: currentLengthOverride, completedDates: credited);
}
