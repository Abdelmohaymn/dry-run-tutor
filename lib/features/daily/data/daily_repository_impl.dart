import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/db/dao/session_dao.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_time_source.dart';
import '../../problem/domain/problem.dart';
import '../../problem/domain/problem_repository.dart';
import '../domain/daily_repository.dart';
import '../domain/daily_selection.dart';

class DailyRepositoryImpl implements DailyRepository {
  DailyRepositoryImpl({
    required ProblemRepository problemRepository,
    required SessionDao sessionDao,
    required RemoteConfigRepository configRepository,
    required TrustedTimeSource timeSource,
  })  : _problemRepository = problemRepository,
        _sessionDao = sessionDao,
        _configRepository = configRepository,
        _timeSource = timeSource;

  final ProblemRepository _problemRepository;
  final SessionDao _sessionDao;
  final RemoteConfigRepository _configRepository;
  final TrustedTimeSource _timeSource;

  @override
  Future<DailySelection> forToday() async {
    final RuntimeConfig config = _configRepository.cached() ?? await _configRepository.load();
    final String today = await _timeSource.today();
    final Set<String> completed = await _sessionDao.completedProblemIds();

    // Same-day offline (FR-020): the problem the relay served for today is
    // read from the cache, unless it has been withdrawn since.
    final Problem? cached = await _problemRepository.cachedForDate(today);
    if (cached != null && !config.killedProblemIds.contains(cached.id)) {
      return DailySelection(problem: cached, isRepeat: completed.contains(cached.id));
    }

    // The relay picks the day's problem (and records that this device was
    // active). `isRepeat` is still a local fact, answered from local history.
    try {
      final Problem problem = await _problemRepository.fetchDaily(today);
      return DailySelection(problem: problem, isRepeat: completed.contains(problem.id));
    } on RelayException {
      // PROBLEM_KILLED (everything withdrawn) and offline-with-nothing-cached
      // both land on the existing "no problem" state (FR-020).
      throw const NoProblemAvailableException();
    }
  }
}
