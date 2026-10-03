import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'streak_dao.g.dart';

/// Data access for `StreakDays` — a set of dates, not a counter. **There is
/// no decrement method here**, which is how FR-038 ("never revoke a
/// credited streak") becomes structurally true rather than a rule someone
/// has to remember.
@DriftAccessor(tables: [StreakDays])
class StreakDao extends DatabaseAccessor<AppDatabase> with _$StreakDaoMixin {
  StreakDao(super.db);

  /// Insert-only. Crediting an already-credited day is a no-op, not an
  /// error — a double-credit attempt must never throw and must never
  /// duplicate a row. `creditedAt` is supplied by the caller from
  /// `TrustedTimeSource`; this DAO never reads the wall clock itself
  /// (Principle IX, `no_wall_clock`).
  Future<void> credit(String day, {required DateTime creditedAt}) {
    return into(streakDays).insertOnConflictUpdate(
      StreakDaysCompanion.insert(day: day, creditedAt: creditedAt),
    );
  }

  /// The heatmap's **only** input. Returns dates, never sessions — a
  /// heatmap square built from this has no id to route with (FR-039d).
  Future<Set<String>> completedDates() async {
    final List<StreakDay> rows = await select(streakDays).get();
    return rows.map((StreakDay r) => r.day).toSet();
  }

  Future<bool> isCredited(String day) async {
    final StreakDay? row =
        await (select(streakDays)..where((t) => t.day.equals(day))).getSingleOrNull();
    return row != null;
  }
}
