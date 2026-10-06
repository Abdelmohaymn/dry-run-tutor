import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../db/dao/config_dao.dart';
import '../db/app_database.dart' show CachedConfigCompanion, CachedConfigData;
import '../network/dto/config_dto.dart';
import '../network/relay_client.dart';
import '../time/trusted_time_source.dart';
import 'runtime_config.dart';

/// `GET /v1/config`, with FR-046's fail-open. `load()` **never throws and
/// never returns null when a cache exists** — that guarantee is a property
/// of this signature, not a `try` block each call site has to remember.
/// The one case it cannot paper over is a first launch with no cached row
/// and no network at all; that is `seedGuard`'s blocking case (FR-047a),
/// and `load()` rethrows there so the seeding screen can offer retry.
abstract interface class RemoteConfigRepository {
  Future<RuntimeConfig> load();

  /// Populates [cached] from the Drift row alone — **no network, no
  /// timeout, no failure mode**. `main()` awaits this rather than
  /// `load()` so the first frame is never behind a socket: a returning
  /// learner's guards see their real config immediately, and the network
  /// refresh happens after `runApp`. Returns null when no row exists,
  /// which is exactly `seedGuard`'s first-launch case.
  Future<RuntimeConfig?> hydrateFromCache();

  /// Synchronous, for launch-path decisions that cannot await — e.g. a
  /// router guard deciding whether a cache already exists.
  RuntimeConfig? cached();

  Stream<RuntimeConfig> watch();
}

class RemoteConfigRepositoryImpl implements RemoteConfigRepository {
  RemoteConfigRepositoryImpl({
    required RelayClient relayClient,
    required ConfigDao configDao,
    required TrustedTimeSource timeSource,
  })  : _relayClient = relayClient,
        _configDao = configDao,
        _timeSource = timeSource;

  final RelayClient _relayClient;
  final ConfigDao _configDao;
  final TrustedTimeSource _timeSource;

  final StreamController<RuntimeConfig> _controller = StreamController<RuntimeConfig>.broadcast();

  RuntimeConfig? _cached;

  @override
  RuntimeConfig? cached() => _cached;

  @override
  Stream<RuntimeConfig> watch() => _controller.stream;

  @override
  Future<RuntimeConfig?> hydrateFromCache() async {
    if (_cached != null) {
      return _cached;
    }
    try {
      final CachedConfigData? row = await _configDao.read();
      if (row == null) {
        return null;
      }
      final ConfigDto dto = ConfigDto.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
      final RuntimeConfig config = RuntimeConfig.fromDto(dto);
      _cached = config;
      return config;
    } catch (_) {
      // A corrupt or unreadable row must not stop the app from starting;
      // it degrades to the first-launch path, which is a designed screen.
      return null;
    }
  }

  @override
  Future<RuntimeConfig> load() async {
    try {
      final ConfigResponse response = await _relayClient.config();
      final RuntimeConfig config = RuntimeConfig.fromDto(response.parsed);
      // Published before the row is persisted, deliberately. A fetch that
      // arrived and parsed is a config the app has; letting the *write*
      // decide that would put the launch path behind a Drift call and a
      // timestamp, and on a first launch there is no cached row for the
      // `catch` below to fall back to — so a slow or failing write would
      // strand `/seeding` on a config that had already been fetched
      // successfully. Caching it costs the next launch a re-fetch; not
      // caching it costs this launch the app.
      _cached = config;
      _controller.add(config);
      try {
        await _configDao.write(
          CachedConfigCompanion.insert(
            json: response.rawJson,
            etag: Value(response.etag),
            fetchedAt: (await _timeSource.now()).utc,
          ),
        );
      } catch (_) {
        // Its own `catch`, so a failed persist stays a failed persist:
        // the outer one below means "the fetch did not produce a config"
        // and answers from cache, which is the wrong answer to give
        // about a config already returned above.
      }
      return config;
    } catch (_) {
      // Any failure — unreachable, timeout, non-200, unparseable — falls
      // back to cache (FR-046). Only a first launch with no cached row at
      // all cannot honour this, and that is the sole case allowed to
      // rethrow: `seedGuard` is what turns it into the designed waiting
      // screen rather than an uncaught error reaching a widget.
      final CachedConfigData? row = await _configDao.read();
      if (row == null) {
        rethrow;
      }
      final ConfigDto dto = ConfigDto.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
      final RuntimeConfig config = RuntimeConfig.fromDto(dto);
      _cached = config;
      return config;
    }
  }
}
