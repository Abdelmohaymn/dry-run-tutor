import 'package:equatable/equatable.dart';

/// Computed from `StreakDays`, never stored (data-model.md §9) —
/// `currentLength` is a walk-back from today's trusted date, not a
/// counter column anything could decrement.
class Streak extends Equatable {
  const Streak({required this.currentLength, required this.completedDates});

  final int currentLength;

  /// `YYYY-MM-DD` strings — the heatmap's only input (FR-039d: a date has
  /// no id to route with).
  final Set<String> completedDates;

  @override
  List<Object?> get props => <Object?>[currentLength, completedDates];
}
