import 'dart:async';

import 'package:dry_run/core/config/remote_config_repository.dart';
import 'package:dry_run/core/config/runtime_config.dart';

/// A plain fake — no mocktail, no Drift, no network — for tests that only
/// need to control what `cached()` returns. Constructible with no locator
/// setup, exactly as `contracts/repositories.md` requires of every
/// repository interface.
class FakeRemoteConfigRepository implements RemoteConfigRepository {
  RuntimeConfig? cachedValue;

  @override
  RuntimeConfig? cached() => cachedValue;

  @override
  Future<RuntimeConfig?> hydrateFromCache() async => cachedValue;

  @override
  Future<RuntimeConfig> load() async {
    if (cachedValue == null) {
      throw StateError('FakeRemoteConfigRepository: no cache and no network scripted');
    }
    return cachedValue!;
  }

  @override
  Stream<RuntimeConfig> watch() => const Stream<RuntimeConfig>.empty();
}
