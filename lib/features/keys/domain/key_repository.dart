import '../../../core/config/runtime_config.dart';
import '../../../core/errors/result.dart';
import 'learner_key.dart';

/// The learner's provider key, held in Android Keystore and nowhere else
/// (contracts/repositories.md, FR-003).
abstract interface class KeyRepository {
  Future<LearnerKey?> read();

  /// Persists [key]. FR-005b's "probe before persisting" (a cheap call
  /// that fails fast on a bad key, so a rejected key is never stored) is
  /// wired into this call by `features/keys/presentation` in Phase 4 — see
  /// tasks.md T092. This interface's contract is only that a failure here
  /// must leave [read] unchanged from before the call.
  Future<Result<void>> saveAndValidate(LearnerKey key);

  Future<void> delete();

  /// == `config.keyedProviders`, in the order key entry should offer them.
  List<String> offeredProviders(RuntimeConfig config);
}
