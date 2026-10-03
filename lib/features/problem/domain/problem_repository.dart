import '../../../core/config/runtime_config.dart';
import 'problem.dart';

/// The `collections` entry that marks the onboarding warm-up. It is a
/// real manifest problem — the relay resolves it like any other, so a
/// live practice turn has a statement and a private half to work from —
/// but it is never one of the days, and this string is the one place
/// that distinction is written down.
const String practiceCollection = 'practice';

abstract interface class ProblemRepository {
  /// Fetches the manifest and caches everything within the two-week
  /// window, excluding `killed_problem_ids` (FR-035a, FR-040).
  Future<void> prefetchManifest();

  Future<Problem?> byId(String problemId);

  /// Excludes [RuntimeConfig.killedProblemIds] and the warm-up
  /// ([practiceCollection]) — what `DailyRepository` rotates through.
  Future<List<Problem>> available(RuntimeConfig config);

  /// The onboarding warm-up, or null when the manifest carries none.
  Future<Problem?> practiceProblem();

  /// Whether anything at all is cached — what `seedGuard` checks alongside
  /// `RemoteConfigRepository.cached()` to decide whether a later offline
  /// launch can go straight to today's problem (FR-047, routes.md).
  Future<bool> hasAnyCached();
}
