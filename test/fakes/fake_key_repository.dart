import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/features/keys/domain/key_repository.dart';
import 'package:dry_run/features/keys/domain/learner_key.dart';

class FakeKeyRepository implements KeyRepository {
  LearnerKey? storedKey;

  /// When set, `saveAndValidate` returns this instead of succeeding —
  /// lets a test script a probe rejection without a real relay client.
  Result<void>? scriptedResult;

  @override
  Future<LearnerKey?> read() async => storedKey;

  @override
  Future<Result<void>> saveAndValidate(LearnerKey key) async {
    final Result<void> result = scriptedResult ?? const Ok(null);
    if (result is Ok<void>) {
      storedKey = key;
    }
    return result;
  }

  @override
  Future<void> delete() async {
    storedKey = null;
  }

  @override
  List<String> offeredProviders(RuntimeConfig config) => config.keyedProviders;
}
