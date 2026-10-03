import 'dart:async';

import 'package:flutter/services.dart';
import '../config/brand.dart';

/// A single tier-one reading off Play Services TrustedTime, paired with
/// the monotonic clock reading taken in the same native call — the pair
/// tier three needs to compute a later delta.
class TrustedTimeReading {
  const TrustedTimeReading({required this.utc, required this.elapsedRealtimeAtCaptureMillis});

  final DateTime utc;
  final int elapsedRealtimeAtCaptureMillis;
}

/// The Dart side of `TrustedTimeChannel.kt`. Isolated behind an interface
/// so `test/unit/trusted_time_test.dart` can drive all three tiers with a
/// fake rather than a physical device (research.md R-003 — a fake here is
/// how the clock-tamper cases run without a device farm; only the
/// physical-device claim itself needs a real device, per the phase-11
/// verification task).
abstract interface class TrustedTimePlatform {
  /// A fresh tier-one reading, or `null` if TrustedTime has never synced
  /// (typically: no network since install) or the channel is unavailable
  /// on this platform.
  Future<TrustedTimeReading?> now();

  /// `SystemClock.elapsedRealtime()` right now — monotonic since boot,
  /// unaffected by wall-clock edits. Used to compute tier three's delta
  /// independent of ever reaching tier one.
  Future<int?> elapsedRealtimeMillis();
}

/// How long either channel call may take before it is treated as tier
/// one being unavailable.
///
/// A `MethodChannel` invocation completes when — and only when — the
/// native side calls `result`. `TrustedTimeChannel.kt` calls it from a
/// `Task` listener, and a `Task` that never settles (a Play Services
/// build without the time module, an in-progress GMS module install) is
/// a reply that never arrives. Without this bound that hangs the whole
/// trusted-time chain, and with it every caller that awaits a timestamp
/// — which on a first launch is the config write standing between the
/// seeding screen and the app. Tier one has a designed unavailable path;
/// a call that never returns is not it.
const Duration _channelTimeout = Duration(seconds: 5);

/// The real implementation, over `TrustedTimeChannel.kt`.
class MethodChannelTrustedTimePlatform implements TrustedTimePlatform {
  MethodChannelTrustedTimePlatform({MethodChannel? channel, Duration? timeout})
      : _channel = channel ?? const MethodChannel('${AppBrand.channelPrefix}/trusted_time'),
        _timeout = timeout ?? _channelTimeout;

  final MethodChannel _channel;
  final Duration _timeout;

  @override
  Future<TrustedTimeReading?> now() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMapMethod<Object?, Object?>('now').timeout(_timeout);
      if (result == null) {
        return null;
      }
      final Object? epochMillis = result['epochMillis'];
      final Object? elapsedRealtimeMillis = result['elapsedRealtimeMillis'];
      final bool isTrusted = result['isTrusted'] == true;
      if (!isTrusted || epochMillis is! int || elapsedRealtimeMillis is! int) {
        return null;
      }
      return TrustedTimeReading(
        utc: DateTime.fromMillisecondsSinceEpoch(epochMillis, isUtc: true),
        elapsedRealtimeAtCaptureMillis: elapsedRealtimeMillis,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }

  @override
  Future<int?> elapsedRealtimeMillis() async {
    try {
      final Object? result =
          await _channel.invokeMethod<Object?>('elapsedRealtimeMillis').timeout(_timeout);
      return result is int ? result : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}
