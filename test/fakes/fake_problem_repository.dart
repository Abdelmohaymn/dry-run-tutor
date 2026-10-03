import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/problem/domain/problem_repository.dart';

class FakeProblemRepository implements ProblemRepository {
  bool hasAny = false;
  List<Problem> availableProblems = const <Problem>[];
  Problem? practice;

  @override
  Future<void> prefetchManifest() async {}

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
