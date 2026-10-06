import 'dart:async';

import 'package:flutter/services.dart';

import '../config/brand.dart';

/// The Dart side of `DeviceIdChannel.kt`.
///
/// The value is read once, sent to `POST /v1/install`, and dropped: it is
/// never written to Drift, SharedPreferences or a log (the relay keeps
/// only a keyed hash of it).
abstract interface class DeviceIdPlatform {
  /// Android's per-app `Settings.Secure.ANDROID_ID`, or null when the
  /// platform returns none, the channel is missing, or it times out.
  Future<String?> androidId();
}

/// A `MethodChannel` call completes only when the native side replies; a
/// reply that never arrives must not hang first launch.
const Duration _channelTimeout = Duration(seconds: 5);

class MethodChannelDeviceIdPlatform implements DeviceIdPlatform {
  MethodChannelDeviceIdPlatform({MethodChannel? channel, Duration? timeout})
      : _channel = channel ?? const MethodChannel('${AppBrand.channelPrefix}/device_id'),
        _timeout = timeout ?? _channelTimeout;

  final MethodChannel _channel;
  final Duration _timeout;

  @override
  Future<String?> androidId() async {
    try {
      final String? id = await _channel.invokeMethod<String>('androidId').timeout(_timeout);
      if (id == null || id.trim().isEmpty) {
        return null;
      }
      return id;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TimeoutException {
      return null;
    }
  }
}
