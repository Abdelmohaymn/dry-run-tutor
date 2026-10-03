import '../../../core/db/dao/streak_dao.dart';
import '../../../core/time/trusted_time_source.dart';
import '../domain/streak.dart';
import '../domain/streak_repository.dart';

class StreakRepositoryImpl implements StreakRepository {
  StreakRepositoryImpl({required StreakDao streakDao, required TrustedTimeSource timeSource})
      : _streakDao = streakDao,
        _timeSource = timeSource;

  final StreakDao _streakDao;
  final TrustedTimeSource _timeSource;

  @override
  Future<void> credit(String trustedDay) async {
    final DateTime creditedAt = (await _timeSource.now()).utc;
    await _streakDao.credit(trustedDay, creditedAt: creditedAt);
  }

  @override
  Future<Set<String>> completedDates() => _streakDao.completedDates();

  @override
  Future<Streak> current() async {
    final Set<String> dates = await _streakDao.completedDates();
    final String today = await _timeSource.today();

    // A walk backward from trusted "today" (data-model.md §7) — never
    // the device wall clock, and never a stored counter to decrement.
    // Today itself may not be credited yet (the session isn't done), so
    // the walk starts at yesterday in that case rather than reading a
    // zero streak the moment the clock rolls over.
    DateTime cursor = _parseYmd(today);
    if (!dates.contains(_formatYmd(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int length = 0;
    while (dates.contains(_formatYmd(cursor))) {
      length++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return Streak(currentLength: length, completedDates: dates);
  }

  DateTime _parseYmd(String ymd) {
    final List<String> parts = ymd.split('-');
    return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  String _formatYmd(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
