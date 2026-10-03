import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/db/dao/session_dao.dart';
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
    final List<Problem> available = await _problemRepository.available(config);

    // 1. A problem the manifest authored for exactly today (FR-035a).
    for (final Problem problem in available) {
      if (problem.date == today) {
        return DailySelection(problem: problem, isRepeat: false);
      }
    }

    final List<Problem> evergreen = available.where((Problem p) => p.date == null).toList()
      ..sort((Problem a, Problem b) => a.id.compareTo(b.id));
    final Set<String> completed = await _sessionDao.completedProblemIds();

    // 2. The operator's pointer (FR-035d). The whole point of this branch
    // is that it reads NOTHING about this install: same day, same pool,
    // same problem, whether the app was installed a year ago or an hour
    // ago. `isRepeat` is still answered from local history, because that
    // flag is a local analytics fact (FR-035c) and not part of what is
    // being chosen.
    final RotationConfig? rotation = config.rotation;
    if (rotation != null && evergreen.isNotEmpty) {
      final Problem picked = _pointerPick(rotation, evergreen, today);
      return DailySelection(problem: picked, isRepeat: completed.contains(picked.id));
    }

    // 3. No pointer: the evergreen pool, preferring one this install has
    // never attempted, so "the library is exhausted" means something real
    // rather than the very first repeat available.
    for (final Problem problem in evergreen) {
      if (!completed.contains(problem.id)) {
        return DailySelection(problem: problem, isRepeat: false);
      }
    }

    // 4. Exhausted (FR-035b/c): repeat one, deterministically, from
    // whichever pool has anything at all. No badge, no marker anywhere a
    // widget can read — only this locally-recorded flag.
    final List<Problem> candidates = evergreen.isNotEmpty ? evergreen : available;
    if (candidates.isEmpty) {
      throw const NoProblemAvailableException();
    }
    final List<Problem> sorted = List<Problem>.of(candidates)
      ..sort((Problem a, Problem b) => a.id.compareTo(b.id));
    return DailySelection(problem: sorted.first, isRepeat: true);
  }

  /// `start_problem_id` plus whole days elapsed since `anchor_date`,
  /// wrapped around [pool] (which arrives id-sorted).
  ///
  /// Three ways the operator's numbers can be wrong, none of which may
  /// cost a learner their day:
  ///  - `start_problem_id` withdrawn, misspelled, or not yet in the
  ///    manifest → start from the top of the pool rather than nothing.
  ///  - `anchor_date` unparseable → treat as no elapsed days, i.e. serve
  ///    the start problem.
  ///  - today earlier than the anchor (a device behind, or an anchor set
  ///    in the future) → clamp at zero rather than walking backwards into
  ///    a negative index.
  static Problem _pointerPick(RotationConfig rotation, List<Problem> pool, String today) {
    final int startIndex = pool.indexWhere((Problem p) => p.id == rotation.startProblemId);
    final DateTime? anchor = DateTime.tryParse('${rotation.anchorDate}T00:00:00Z');
    final DateTime? now = DateTime.tryParse('${today}T00:00:00Z');

    int elapsedDays = 0;
    if (anchor != null && now != null) {
      elapsedDays = now.difference(anchor).inDays;
      if (elapsedDays < 0) {
        elapsedDays = 0;
      }
    }

    final int index = ((startIndex < 0 ? 0 : startIndex) + elapsedDays) % pool.length;
    return pool[index];
  }
}
