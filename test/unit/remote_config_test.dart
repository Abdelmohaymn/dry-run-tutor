// FR-046's fail-open: any failure of /v1/config falls back to the cached
// row, and only a first launch with no cached row at all is allowed to
// fail to produce a config (FR-047a's blocking case, which `seedGuard`
// turns into the designed waiting screen). This test drives
// RemoteConfigRepositoryImpl against a real RelayClient/Dio with a
// scripted transport, exactly as host_allowlist_test.dart does, so the
// fallback is proven at the same seam that will fail in production rather
// than against a hand-rolled fake repository.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dry_run/core/config/remote_config_repository.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/core/time/trusted_instant.dart';
import 'package:dry_run/core/time/trusted_time_source.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const String _validConfigJson = '''
{
  "min_supported_version": "1.0.0",
  "killed_problem_ids": [],
  "chat": {"turn_cap": 12, "wrap_up_at_turn": 9, "min_turn_chars": 8},
  "trial": {"turn_cap": 4},
  "keyed_providers": ["groq", "gemini"]
}
''';

/// The same payload with a store listing for the update wall.
const String _configWithUpdateUrlJson = '''
{
  "min_supported_version": "1.0.0",
  "killed_problem_ids": [],
  "chat": {"turn_cap": 12, "wrap_up_at_turn": 9, "min_turn_chars": 8},
  "trial": {"turn_cap": 4},
  "keyed_providers": ["groq", "gemini"],
  "update_url": "https://dry-run.en.uptodown.com/android"
}
''';

/// The same payload with the server-voice levers (spec 008).
const String _configWithVoiceJson = '''
{
  "min_supported_version": "1.0.0",
  "killed_problem_ids": [],
  "chat": {"turn_cap": 12, "wrap_up_at_turn": 9, "min_turn_chars": 8},
  "trial": {"turn_cap": 4},
  "keyed_providers": ["groq", "gemini"],
  "voice": {"enabled": true, "seconds_per_device": 300, "max_clip_seconds": 120}
}
''';

class _FixedTimeSource implements TrustedTimeSource {
  @override
  Future<TrustedInstant> now() async => TrustedInstant(
        utc: DateTime.utc(2026, 3, 1),
        source: TrustedTimeSourceKind.trustedTime,
        isStale: false,
      );

  @override
  Future<String> today() async => '2026-03-01';
}

/// An adapter whose response for each call is decided by a callback, so a
/// single test can script "succeed once, then fail" without a second Dio
/// instance.
class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._behaviour);

  final ResponseBody Function() _behaviour;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _behaviour();
  }
}

RelayClient _relayClientReturning(ResponseBody Function() behaviour) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://relay.test'));
  dio.httpClientAdapter = _ScriptedAdapter(behaviour);
  return RelayClient(dio);
}

ResponseBody _okBody(String json) => ResponseBody.fromString(
      json,
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('a successful load caches the config verbatim and returns it parsed', () async {
    final RemoteConfigRepositoryImpl repo = RemoteConfigRepositoryImpl(
      relayClient: _relayClientReturning(() => _okBody(_validConfigJson)),
      configDao: db.configDao,
      timeSource: _FixedTimeSource(),
    );

    final RuntimeConfig config = await repo.load();

    expect(config.minSupportedVersion, '1.0.0');
    expect(config.keyedProviders, <String>['groq', 'gemini']);
    expect(repo.cached(), config);

    final CachedConfigData? row = await db.configDao.read();
    expect(row, isNotNull);
    expect(jsonDecode(row!.json)['min_supported_version'], '1.0.0');
  });

  test('update_url round-trips, and its absence is null', () async {
    RemoteConfigRepositoryImpl repoFor(String json) => RemoteConfigRepositoryImpl(
          relayClient: _relayClientReturning(() => _okBody(json)),
          configDao: db.configDao,
          timeSource: _FixedTimeSource(),
        );

    expect((await repoFor(_validConfigJson).load()).updateUrl, isNull);
    expect(
      (await repoFor(_configWithUpdateUrlJson).load()).updateUrl,
      'https://dry-run.en.uptodown.com/android',
    );
  });

  test('a voice block parses into VoiceConfig, and its absence is null', () async {
    RemoteConfigRepositoryImpl repoFor(String json) => RemoteConfigRepositoryImpl(
          relayClient: _relayClientReturning(() => _okBody(json)),
          configDao: db.configDao,
          timeSource: _FixedTimeSource(),
        );

    expect((await repoFor(_validConfigJson).load()).voice, isNull);
    expect(
      (await repoFor(_configWithVoiceJson).load()).voice,
      const VoiceConfig(enabled: true, secondsPerDevice: 300, maxClipSeconds: 120),
    );
  });

  group('every failure mode falls back to an existing cache', () {
    Future<RuntimeConfig> seedThenFail(ResponseBody Function() failing) async {
      final RelayClient okOnce = _relayClientReturning(() => _okBody(_validConfigJson));
      final RemoteConfigRepositoryImpl seeding = RemoteConfigRepositoryImpl(
        relayClient: okOnce,
        configDao: db.configDao,
        timeSource: _FixedTimeSource(),
      );
      await seeding.load();

      final RemoteConfigRepositoryImpl repo = RemoteConfigRepositoryImpl(
        relayClient: _relayClientReturning(failing),
        configDao: db.configDao,
        timeSource: _FixedTimeSource(),
      );
      return repo.load();
    }

    test('unreachable (connection error)', () async {
      final RuntimeConfig config = await seedThenFail(() {
        throw const SocketExceptionStub();
      });
      expect(config.minSupportedVersion, '1.0.0');
    });

    test('timeout', () async {
      final RuntimeConfig config = await seedThenFail(() {
        throw DioException(
          requestOptions: RequestOptions(path: '/v1/config'),
          type: DioExceptionType.connectionTimeout,
        );
      });
      expect(config.minSupportedVersion, '1.0.0');
    });

    test('non-200', () async {
      final RuntimeConfig config = await seedThenFail(
        () => ResponseBody.fromString('{"error":"nope"}', 500),
      );
      expect(config.minSupportedVersion, '1.0.0');
    });

    test('unparseable body', () async {
      final RuntimeConfig config = await seedThenFail(
        () => _okBody('not json at all {{{'),
      );
      expect(config.minSupportedVersion, '1.0.0');
    });
  });

  test('no cache and no network is the one blocking case — load() rethrows', () async {
    final RemoteConfigRepositoryImpl repo = RemoteConfigRepositoryImpl(
      relayClient: _relayClientReturning(() {
        throw const SocketExceptionStub();
      }),
      configDao: db.configDao,
      timeSource: _FixedTimeSource(),
    );

    await expectLater(repo.load(), throwsA(anything));
    expect(repo.cached(), isNull);
  });
}

/// A minimal connection-error stand-in so this test does not need to reach
/// for `dart:io`'s `SocketException` (banned import-boundary territory
/// elsewhere in this codebase; kept out of habit here too).
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();

  @override
  String toString() => 'SocketExceptionStub: connection refused';
}
