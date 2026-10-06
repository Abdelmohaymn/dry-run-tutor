import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/problem/domain/problem_repository.dart';

class FakeProblemRepository implements ProblemRepository {
  bool hasAny = false;
  List<Problem> availableProblems = const <Problem>[];
  Problem? practice;

  /// What [fetchDaily] returns; ignored when [fetchDailyError] is set.
  Problem? fetchDailyResult;

  /// Thrown by [fetchDaily] when set (a `RelayError` wrapped in `RelayException`).
  RelayError? fetchDailyError;
  final List<String> fetchDailyCalls = <String>[];

  /// What [cachedForDate] answers, by date.
  final Map<String, Problem> cachedByDate = <String, Problem>{};
  int fetchPracticeCalls = 0;

  @override
  Future<Problem> fetchDaily(String date) async {
    fetchDailyCalls.add(date);
    final RelayError? error = fetchDailyError;
    if (error != null) {
      throw RelayException(error);
    }
    return fetchDailyResult!;
  }

  @override
  Future<Problem?> cachedForDate(String date) async => cachedByDate[date];

  @override
  Future<void> fetchPractice() async {
    fetchPracticeCalls++;
  }

  @override
  Future<Problem?> byId(String problemId) async {
    for (final Problem p in availableProblems) {
      if (p.id == problemId) {
        return p;
      }
    }
    return null;
  }

  @override
  Future<List<Problem>> available(RuntimeConfig config) async => availableProblems;

  @override
  Future<Problem?> practiceProblem() async => practice;

  @override
  Future<bool> hasAnyCached() async => hasAny;
}
