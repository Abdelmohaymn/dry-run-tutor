import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'problem_dao.g.dart';

/// Data access for the public-half problem cache. `ProblemRepository`
/// layers the manifest fetch, the two-week prefetch window (FR-035a), and
/// the `killed_problem_ids` exclusion (FR-040) on top of this.
@DriftAccessor(tables: [CachedProblems])
class ProblemDao extends DatabaseAccessor<AppDatabase> with _$ProblemDaoMixin {
  ProblemDao(super.db);

  Future<CachedProblem?> byId(String problemId) {
    return (select(cachedProblems)..where((t) => t.problemId.equals(problemId)))
        .getSingleOrNull();
  }

  /// Id-ordered, not insertion-ordered: every "which problem is today"
  /// decision downstream is an index into this list, and SQLite's natural
  /// row order is not a promise.
  Future<List<CachedProblem>> all() =>
      (select(cachedProblems)..orderBy([(t) => OrderingTerm.asc(t.problemId)])).get();

  Future<void> upsertAll(List<CachedProblemsCompanion> entries) {
    return batch((b) => b.insertAllOnConflictUpdate(cachedProblems, entries));
  }

  Future<void> deleteById(String problemId) {
    return (delete(cachedProblems)..where((t) => t.problemId.equals(problemId))).go();
  }
}
