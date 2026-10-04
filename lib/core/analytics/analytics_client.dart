import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener, AppLifecycleState, WidgetsBinding;
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../db/dao/event_dao.dart';
import '../network/dto/event_dto.dart';
import '../network/relay_client.dart';
import '../time/trusted_instant.dart';
import '../time/trusted_time_source.dart';
import 'event_name.dart';

/// `emit` returns `void` and cannot throw (FR-051) — a signature with no
/// failure channel is the cheapest guarantee that no call site ever tries
/// to handle one.
abstract interface class AnalyticsClient {
  void emit(EventName name, {Map<String, Object>? props});
}

/// Validates against `event.schema.json`'s own limits before ever
/// buffering to Drift, then batches fire-and-forget: `emit` writes to the
/// local buffer only, and [drain] is what turns that buffer into
/// `POST /v1/event` calls — triggered by connectivity returning and by
/// the app backgrounding (T151), never by `emit` itself, so a call to
/// [emit] never blocks the caller.
class AnalyticsClientImpl implements AnalyticsClient {
  AnalyticsClientImpl({
    required EventDao eventDao,
    required TrustedTimeSource timeSource,
    required RelayClient relayClient,
    required Future<String> Function() resolveInstallId,
    Uuid? uuid,
    Connectivity? connectivity,
  })  : _eventDao = eventDao,
        _timeSource = timeSource,
        _relayClient = relayClient,
        _resolveInstallId = resolveInstallId,
        _uuid = uuid ?? const Uuid() {
    // Both of these need a live Flutter binding (`ServicesBinding` for
    // the connectivity `EventChannel`, `WidgetsBinding` for the
    // lifecycle listener) — present for every real app run, since
    // `main()` calls `WidgetsFlutterBinding.ensureInitialized()` before
    // this is ever constructed, but absent in a plain `test()` (as
    // opposed to `testWidgets()`) that builds this class directly, e.g.
    // `test/security/no_key_leak_test.dart`. `emit()`/buffering must
    // keep working there regardless — only the drain triggers are
    // skipped, silently, matching FR-051's "an analytics failure changes
    // nothing" for this class generally. Checked **before** calling
    // `.listen()`, not around it — the `EventChannel`'s missing-binding
    // error surfaces asynchronously (inside the zone `.listen()`
    // registers), past the point a synchronous `try/catch` here would
    // still be on the stack.
    if (_hasFlutterBinding()) {
      _connectivitySub = (connectivity ?? Connectivity()).onConnectivityChanged.listen((
        List<ConnectivityResult> results,
      ) {
        if (results.any((ConnectivityResult r) => r != ConnectivityResult.none)) {
          unawaited(drain());
        }
      });
      _lifecycleListener = AppLifecycleListener(
        onStateChange: (AppLifecycleState state) {
          if (state == AppLifecycleState.paused) {
            unawaited(drain());
          }
        },
      );
    }
  }

  static bool _hasFlutterBinding() {
    try {
      WidgetsBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  final EventDao _eventDao;
  final TrustedTimeSource _timeSource;
  final RelayClient _relayClient;
  final Future<String> Function() _resolveInstallId;
  final Uuid _uuid;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  AppLifecycleListener? _lifecycleListener;
  bool _draining = false;

  /// `event.schema.json`'s ≤100-per-batch ceiling.
  static const int _batchLimit = 100;

  /// US8 scenario 3 / FR-051: a rejected batch is dropped after a bounded
  /// number of attempts, never surfaced. Not zero, so a single transient
  /// failure (one bad request in a batch, a mid-drain disconnect) doesn't
  /// throw away an event on the first retry.
  static const int _maxAttempts = 5;

  static final RegExp _keyPattern = RegExp(r'^[a-z][a-z0-9_]{0,31}$');

  /// Pure, so `test/unit/analytics_contract_test.dart` can assert the
  /// schema's limits — at most 12 keys, scalar values only, no nesting,
  /// 64 characters maximum, key names matching `^[a-z][a-z0-9_]{0,31}$`
  /// (research.md R-006) — without exercising Drift or the async path.
  static bool isValidProps(Map<String, Object>? props) {
    if (props == null) {
      return true;
    }
    if (props.length > 12) {
      return false;
    }
    for (final MapEntry<String, Object> entry in props.entries) {
      if (!_keyPattern.hasMatch(entry.key)) {
        return false;
      }
      final Object value = entry.value;
      if (value is! num && value is! String && value is! bool) {
        return false;
      }
      if (value is String && value.length > 64) {
        return false;
      }
    }
    return true;
  }

  @override
  void emit(EventName name, {Map<String, Object>? props}) {
    if (!isValidProps(props)) {
      // An event that would be rejected by the schema is a bug worth
      // failing loudly on in dev (research.md R-006) — asserts are
      // stripped in release, so this never reaches a learner.
      assert(false, 'invalid analytics props for ${name.wireName}: $props');
      return;
    }
    unawaited(_bufferEvent(name, props));
  }

  Future<void> _bufferEvent(EventName name, Map<String, Object>? props) async {
    try {
      final TrustedInstant instant = await _timeSource.now();
      await _eventDao.insertEvent(
        BufferedEventsCompanion.insert(
          id: _uuid.v4(),
          name: name.wireName,
          clientTs: instant.utc.toIso8601String(),
          props: Value(props == null ? null : jsonEncode(props)),
        ),
      );
    } catch (_) {
      // FR-051: an analytics failure changes nothing the learner sees.
    }
  }

  /// Drains the buffer in batches of up to 100, oldest first. A batch the
  /// relay accepts is removed outright; a batch it rejects has every
  /// row's `attempts` incremented, and only the rows that have now
  /// exhausted [_maxAttempts] are dropped — the rest stay queued for the
  /// next trigger. Reentrant-safe: a connectivity change and a background
  /// event arriving together drain once, not twice.
  Future<void> drain() async {
    if (_draining) {
      return;
    }
    _draining = true;
    try {
      while (true) {
        final List<BufferedEvent> events = await _eventDao.due(limit: _batchLimit);
        if (events.isEmpty) {
          return;
        }
        final EventBatchDto batch = EventBatchDto(
          events: events.map(_toDto).toList(growable: false),
        );
        try {
          final String installId = await _resolveInstallId();
          await _relayClient.sendEvents(installId: installId, batch: batch);
          await _eventDao.removeMany(events.map((BufferedEvent e) => e.id).toList(growable: false));
        } catch (e) {
          if (kDebugMode) {
            debugPrint('analytics drain failed, will retry: $e');
          }
          final List<String> exhausted = <String>[];
          for (final BufferedEvent event in events) {
            await _eventDao.incrementAttempts(event.id);
            if (event.attempts + 1 >= _maxAttempts) {
              exhausted.add(event.id);
            }
          }
          if (exhausted.isNotEmpty) {
            await _eventDao.removeMany(exhausted);
          }
          // Stop this pass on failure — the next connectivity or
          // background trigger tries again, rather than looping against
          // a relay that just rejected the same kind of request.
          return;
        }
      }
    } finally {
      _draining = false;
    }
  }

  EventDto _toDto(BufferedEvent row) => EventDto(
        name: row.name,
        clientTs: row.clientTs,
        props: row.props == null ? null : Map<String, Object>.from(jsonDecode(row.props!) as Map),
      );

  void dispose() {
    unawaited(_connectivitySub?.cancel());
    _lifecycleListener?.dispose();
  }
}
