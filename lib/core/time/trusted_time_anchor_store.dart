import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'trusted_instant.dart';

/// The last successful reading from either tier one or tier two, kept so
/// tier three can derive "now" from it plus a monotonic delta even after
/// the app process restarts. `elapsedRealtimeAtCaptureMillis` is what
/// makes a reboot detectable: `SystemClock.elapsedRealtime()` resets to a
/// small value across a reboot, so a *smaller* later reading than this
/// one is the signal (research.md R-003).
class TrustedTimeAnchor {
  const TrustedTimeAnchor({
    required this.utc,
    required this.elapsedRealtimeAtCaptureMillis,
    required this.source,
  });

  final DateTime utc;
  final int elapsedRealtimeAtCaptureMillis;

  /// Always `trustedTime` or `serverDate` — an anchor is never written
  /// with source `monotonicAnchor`, because that tier never produces a
  /// fresh anchor of its own; it only extrapolates from one of the other
  /// two.
  final TrustedTimeSourceKind source;

  Map<String, Object?> toJson() => <String, Object?>{
        'utcMillis': utc.millisecondsSinceEpoch,
        'elapsedRealtimeAtCaptureMillis': elapsedRealtimeAtCaptureMillis,
        'source': source.name,
      };

  static TrustedTimeAnchor? tryParse(String raw) {
    try {
      final Map<String, Object?> json = jsonDecode(raw) as Map<String, Object?>;
      final Object? utcMillis = json['utcMillis'];
      final Object? elapsed = json['elapsedRealtimeAtCaptureMillis'];
      final Object? sourceName = json['source'];
      if (utcMillis is! int || elapsed is! int || sourceName is! String) {
        return null;
      }
      final TrustedTimeSourceKind? source = TrustedTimeSourceKind.values
          .where((TrustedTimeSourceKind s) => s.name == sourceName)
          .firstOrNull;
      if (source == null) {
        return null;
      }
      return TrustedTimeAnchor(
        utc: DateTime.fromMillisecondsSinceEpoch(utcMillis, isUtc: true),
        elapsedRealtimeAtCaptureMillis: elapsed,
        source: source,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Persists the one [TrustedTimeAnchor] the app keeps. A `shared_preferences`
/// flag, not a Drift row — this is bookkeeping for a clock, not retained
/// learner data.
abstract interface class TrustedTimeAnchorStore {
  Future<TrustedTimeAnchor?> read();
  Future<void> write(TrustedTimeAnchor anchor);
}

class SharedPreferencesTrustedTimeAnchorStore implements TrustedTimeAnchorStore {
  SharedPreferencesTrustedTimeAnchorStore(this._prefs);

  static const String _key = 'core.time.trusted_time_anchor';

  final SharedPreferences _prefs;

  @override
  Future<TrustedTimeAnchor?> read() async {
    final String? raw = _prefs.getString(_key);
    if (raw == null) {
      return null;
    }
    return TrustedTimeAnchor.tryParse(raw);
  }

  @override
  Future<void> write(TrustedTimeAnchor anchor) async {
    await _prefs.setString(_key, jsonEncode(anchor.toJson()));
  }
}
