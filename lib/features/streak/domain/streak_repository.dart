import 'streak.dart';

/// The streak feature's one repository (contracts/repositories.md). Pure
/// Dart — the presentation layer never reaches for `StreakDao` directly.
abstract interface class StreakRepository {
  /// Insert-only (FR-038) — crediting an already-credited day is a no-op,
  /// never an error and never a second row. [SessionRepository.endSession]
  /// is the one caller that matters (T121); this exists so a screen can
  /// read the result without touching Drift.
  Future<void> credit(String trustedDay);

  /// Walks back from today's trusted date. **There is no decrement
  /// anywhere in this call graph** — that absence is what makes FR-038
  /// structural.
  Future<Streak> current();

  /// The heatmap's only input.
  Future<Set<String>> completedDates();
}
