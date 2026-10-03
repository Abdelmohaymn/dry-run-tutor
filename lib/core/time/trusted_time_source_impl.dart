import 'trusted_instant.dart';
import 'trusted_time_anchor_store.dart';
import 'trusted_time_platform.dart';
import 'trusted_time_source.dart';

/// The three-tier chain, exactly as research.md R-003 specifies:
///
/// 1. **Play Services TrustedTime.** A fresh read every call. Success
///    both answers this call and refreshes the anchor for the other two
///    tiers.
/// 2. **The relay's `Date:` header.** Not pulled here — [onServerDate] is
///    called by `ServerDateInterceptor` on every successful response, so
///    ordinary app traffic keeps this tier's anchor fresh for free.
/// 3. **The last known anchor plus a monotonic delta**
///    (`SystemClock.elapsedRealtime()`, via [TrustedTimePlatform]). Used
///    whenever tier one fails at call time; the anchor may itself be
///    tier one's or tier two's. A detected reboot (the platform's
///    monotonic clock reads *behind* the anchor's captured value) or a
///    total absence of any anchor both report `isStale: true` — this
///    class never falls back to the device wall clock.
class TrustedTimeSourceImpl implements TrustedTimeSource {
  TrustedTimeSourceImpl({
    required TrustedTimePlatform platform,
    required TrustedTimeAnchorStore anchorStore,
  })  : _platform = platform,
        _anchorStore = anchorStore;

  final TrustedTimePlatform _platform;
  final TrustedTimeAnchorStore _anchorStore;

  @override
  Future<TrustedInstant> now() async {
    final TrustedTimeReading? fresh = await _platform.now();
    if (fresh != null) {
      await _anchorStore.write(
        TrustedTimeAnchor(
          utc: fresh.utc,
          elapsedRealtimeAtCaptureMillis: fresh.elapsedRealtimeAtCaptureMillis,
          source: TrustedTimeSourceKind.trustedTime,
        ),
      );
      return TrustedInstant(utc: fresh.utc, source: TrustedTimeSourceKind.trustedTime, isStale: false);
    }

    final TrustedTimeAnchor? anchor = await _anchorStore.read();
    if (anchor == null) {
      // No anchor has ever been established. FR-047c: never unlock a new
      // day on an unanchored clock. The instant returned is a marker,
      // not a value any caller should render or persist.
      return TrustedInstant(
        utc: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        source: TrustedTimeSourceKind.monotonicAnchor,
        isStale: true,
      );
    }

    final int? currentElapsed = await _platform.elapsedRealtimeMillis();
    if (currentElapsed == null || currentElapsed < anchor.elapsedRealtimeAtCaptureMillis) {
      // Either the platform channel itself is unavailable, or the
      // monotonic clock went backwards relative to the anchor — the one
      // reliable signature of a reboot since the anchor was captured.
      // The learner keeps what they have and today waits (FR-038).
      return TrustedInstant(utc: anchor.utc, source: TrustedTimeSourceKind.monotonicAnchor, isStale: true);
    }

    final Duration delta = Duration(
      milliseconds: currentElapsed - anchor.elapsedRealtimeAtCaptureMillis,
    );
    return TrustedInstant(
      utc: anchor.utc.add(delta),
      source: anchor.source,
      isStale: false,
    );
  }

  @override
  Future<String> today() async {
    final TrustedInstant instant = await now();
    final DateTime utc = instant.utc;
    final String year = utc.year.toString().padLeft(4, '0');
    final String month = utc.month.toString().padLeft(2, '0');
    final String day = utc.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Called by `ServerDateInterceptor` on every successful relay
  /// response — tier two staying fresh from ordinary traffic, with no
  /// call of its own.
  Future<void> onServerDate(DateTime serverDateUtc) async {
    final int? elapsed = await _platform.elapsedRealtimeMillis();
    if (elapsed == null) {
      // No monotonic reference available (e.g. running off-device in a
      // test harness without the channel). Nothing safe to anchor.
      return;
    }
    await _anchorStore.write(
      TrustedTimeAnchor(
        utc: serverDateUtc,
        elapsedRealtimeAtCaptureMillis: elapsed,
        source: TrustedTimeSourceKind.serverDate,
      ),
    );
  }
}
