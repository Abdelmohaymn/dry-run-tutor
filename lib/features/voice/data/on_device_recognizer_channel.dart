import 'package:flutter/services.dart';
import '../../../core/config/brand.dart';

/// Wraps the `OnDeviceRecognizerCheck` platform channel (research.md
/// R-002, T065) — `SpeechRecognizer.isOnDeviceRecognitionAvailable`, a
/// distinction `speech_to_text`'s own `initialize()` does not expose.
class OnDeviceRecognizerChannel {
  const OnDeviceRecognizerChannel();

  static const MethodChannel _channel = MethodChannel('${AppBrand.channelPrefix}/on_device_recognizer');

  /// `(recognitionAvailable, onDeviceAvailable)`. Both `false` on any
  /// platform without this channel wired (a test harness, or a platform
  /// other than Android) — `RecognitionServiceImpl` treats that as "ask
  /// `speech_to_text` directly" rather than as a hard `unsupported`.
  Future<(bool, bool)> check() async {
    try {
      final Map<Object?, Object?>? result =
          await _channel.invokeMapMethod<Object?, Object?>(_methodCheck);
      final bool recognitionAvailable = result?['recognitionAvailable'] as bool? ?? false;
      final bool onDeviceAvailable = result?['onDeviceAvailable'] as bool? ?? false;
      return (recognitionAvailable, onDeviceAvailable);
    } on PlatformException {
      return (false, false);
    } on MissingPluginException {
      return (false, false);
    }
  }

  /// The languages this device is configured for, then every locale the
  /// platform knows — FR-011b's picker list. Both are needed because
  /// `speech_to_text`'s `locales()` under-reports: it omits Arabic on a
  /// device where `ar-EG` recognises Arabic perfectly.
  Future<List<(String, String)>> deviceLocales() => _locales(_methodDeviceLocales);

  Future<List<(String, String)>> allLocales() => _locales(_methodAllLocales);

  Future<List<(String, String)>> _locales(String method) async {
    try {
      final List<Object?>? raw = await _channel.invokeListMethod<Object?>(method);
      if (raw == null) {
        return const <(String, String)>[];
      }
      final List<(String, String)> out = <(String, String)>[];
      for (final Object? entry in raw) {
        if (entry is! Map<Object?, Object?>) {
          continue;
        }
        final String? localeId = entry['localeId'] as String?;
        final String? name = entry['name'] as String?;
        if (localeId != null && localeId.isNotEmpty && name != null && name.isNotEmpty) {
          out.add((localeId, name));
        }
      }
      return out;
    } on PlatformException {
      return const <(String, String)>[];
    } on MissingPluginException {
      return const <(String, String)>[];
    }
  }

  static const String _methodCheck = 'isOnDeviceRecognitionAvailable';
  static const String _methodDeviceLocales = 'deviceLocales';
  static const String _methodAllLocales = 'allLocales';
}
