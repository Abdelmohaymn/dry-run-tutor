import 'daily_selection.dart';

/// The daily feature's one repository (contracts/repositories.md). Three
/// requirements collapse into this one method: FR-040 excludes withdrawn
/// problems, FR-035b returns a repeat with no marker of any kind, and
/// FR-035c records it anyway, locally, for later analysis only.
abstract interface class DailyRepository {
  /// Throws [NoProblemAvailableException] when every cached candidate is
  /// withdrawn (`killed_problem_ids`) — the one case this method cannot
  /// resolve on its own. `DailySessionCubit.open()` is the one caller,
  /// and routes it to `/withdrawn` rather than letting it surface as a
  /// bare failure (contracts/routes.md, FR-040).
  Future<DailySelection> forToday();
}

/// Thrown by [DailyRepository.forToday] when no non-withdrawn problem is
/// cached at all — not the ordinary "today's authored problem is missing"
/// case, which falls through to the evergreen pool invisibly.
class NoProblemAvailableException implements Exception {
  const NoProblemAvailableException();

  @override
  String toString() => 'NoProblemAvailableException: every cached problem is withdrawn';
}
