import '../../../core/config/runtime_config.dart';
import 'problem.dart';
import 'problem_summary.dart';

/// The `collections` entry that marks the onboarding warm-up. It is a
/// real manifest problem — the relay resolves it like any other, so a
/// live practice turn has a statement and a private half to work from —
/// but it is never one of the days, and this string is the one place
/// that distinction is written down.
const String practiceCollection = 'practice';

abstract interface class ProblemRepository {
  /// `GET /v1/daily` for [date]; caches the problem with `manifestDate = date`.
  /// Throws `RelayException` on any relay failure.
  Future<Problem> fetchDaily(String date, {String? problemId});

  /// The problem cached for [date] by an earlier [fetchDaily], or null.
  Future<Problem?> cachedForDate(String date);

  /// `GET /v1/practice`; caches the warm-up (`manifestDate = null`).
  /// Throws `RelayException` on failure.
  Future<void> fetchPractice();

  Future<Problem?> byId(String problemId);

  Future<List<ProblemSummary>> fetchProblems();

  /// Cached, not in [RuntimeConfig.killedProblemIds], not the warm-up
  /// ([practiceCollection]). Now used only by the key-check probe fallback.
  Future<List<Problem>> available(RuntimeConfig config);

  /// The onboarding warm-up, or null when none is cached.
  Future<Problem?> practiceProblem();

  /// Whether anything at all is cached — what `seedGuard` checks alongside
  /// `RemoteConfigRepository.cached()` to decide whether a later offline
  /// launch can go straight to today's problem (FR-047, routes.md).
  Future<bool> hasAnyCached();
}
