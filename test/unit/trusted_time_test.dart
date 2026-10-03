// research.md R-003: the three-tier chain, driven with fakes so the
// clock-tamper and reboot cases run without a device farm. FR-047c and
// FR-038 both branch on `TrustedInstant.isStale` — this is what proves
// the branch actually fires.
import 'package:dry_run/core/time/trusted_instant.dart';
import 'package:dry_run/core/time/trusted_time_anchor_store.dart';
import 'package:dry_run/core/time/trusted_time_platform.dart';
import 'package:dry_run/core/time/trusted_time_source_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePlatform implements TrustedTimePlatform {
  TrustedTimeReading? nowReading;
  int? elapsedRealtime;

  @override
  Future<TrustedTimeReading?> now() async => nowReading;

  @override
  Future<int?> elapsedRealtimeMillis() async => elapsedRealtime;
}

class _FakeAnchorStore implements TrustedTimeAnchorStore {
  TrustedTimeAnchor? stored;

  @override
  Future<TrustedTimeAnchor?> read() async => stored;

  @override
  Future<void> write(TrustedTimeAnchor anchor) async => stored = anchor;
}

void main() {
  late _FakePlatform platform;
  late _FakeAnchorStore anchorStore;
  late TrustedTimeSourceImpl source;

  setUp(() {
    platform = _FakePlatform();
    anchorStore = _FakeAnchorStore();
    source = TrustedTimeSourceImpl(platform: platform, anchorStore: anchorStore);
  });

  group('tier one — Play Services TrustedTime', () {
    test('a fresh trusted reading is used directly and not stale', () async {
      final DateTime expected = DateTime.utc(2026, 3, 1, 12);
      platform.nowReading =
          TrustedTimeReading(utc: expected, elapsedRealtimeAtCaptureMillis: 1000);

      final TrustedInstant instant = await source.now();

      expect(instant.utc, expected);
      expect(instant.source, TrustedTimeSourceKind.trustedTime);
      expect(instant.isStale, isFalse);
    });

    test('a fresh reading refreshes the anchor for later tier-three use', () async {
      platform.nowReading = TrustedTimeReading(
        utc: DateTime.utc(2026, 3, 1, 12),
        elapsedRealtimeAtCaptureMillis: 5000,
      );
      await source.now();

      expect(anchorStore.stored, isNotNull);
      expect(anchorStore.stored!.source, TrustedTimeSourceKind.trustedTime);
    });
  });

  group('tier two — the relay Date: header', () {
    test('onServerDate anchors the clock even with tier one unavailable', () async {
      platform.nowReading = null;
      platform.elapsedRealtime = 10000;

      await source.onServerDate(DateTime.utc(2026, 3, 2, 9));

      platform.elapsedRealtime = 10000; // no time has passed since the anchor
      final TrustedInstant instant = await source.now();

      expect(instant.utc, DateTime.utc(2026, 3, 2, 9));
      expect(instant.source, TrustedTimeSourceKind.serverDate);
      expect(instant.isStale, isFalse);
    });

    test('a server-date anchor advances by the monotonic delta since capture', () async {
      platform.nowReading = null;
      platform.elapsedRealtime = 10000;
      await source.onServerDate(DateTime.utc(2026, 3, 2, 9));

      platform.elapsedRealtime = 10000 + 90000; // 90s later
      final TrustedInstant instant = await source.now();

      expect(instant.utc, DateTime.utc(2026, 3, 2, 9).add(const Duration(seconds: 90)));
      expect(instant.source, TrustedTimeSourceKind.serverDate);
      expect(instant.isStale, isFalse);
    });
  });

  group('tier three — last anchor plus monotonic delta, and its failure modes', () {
    test('no anchor at all is reported as stale, never as a wall-clock guess', () async {
      platform.nowReading = null;
      platform.elapsedRealtime = 12345;

      final TrustedInstant instant = await source.now();

      expect(instant.isStale, isTrue);
      expect(instant.source, TrustedTimeSourceKind.monotonicAnchor);
    });

    test('a reboot (elapsedRealtime goes backwards) is detected and flagged stale', () async {
      platform.nowReading =
          TrustedTimeReading(utc: DateTime.utc(2026, 3, 1), elapsedRealtimeAtCaptureMillis: 50000);
      await source.now(); // establishes the anchor at elapsed=50000

      // Simulate a reboot: TrustedTime is unavailable again (no sync yet
      // since reboot) and elapsedRealtime restarted near zero.
      platform.nowReading = null;
      platform.elapsedRealtime = 200;

      final TrustedInstant instant = await source.now();

      expect(instant.isStale, isTrue);
      expect(instant.source, TrustedTimeSourceKind.monotonicAnchor);
      // The learner keeps what they had — the stale instant is still the
      // last known anchor's value, never advanced backwards.
      expect(instant.utc, DateTime.utc(2026, 3, 1));
    });

    test('device clock manipulation cannot move trusted time', () async {
      // Even though nothing in this fake reads System.currentTimeMillis,
      // this test documents the contract: TrustedInstant is derived only
      // from platform readings and the monotonic delta, never from
      // DateTime.now(). A tampered device clock has no code path in.
      platform.nowReading =
          TrustedTimeReading(utc: DateTime.utc(2026, 1, 1), elapsedRealtimeAtCaptureMillis: 0);
      await source.now();

      platform.nowReading = null;
      platform.elapsedRealtime = 1000; // 1s later, monotonically

      final TrustedInstant instant = await source.now();
      expect(instant.utc, DateTime.utc(2026, 1, 1).add(const Duration(seconds: 1)));
    });
  });

  group('today()', () {
    test('formats the trusted instant as YYYY-MM-DD', () async {
      platform.nowReading = TrustedTimeReading(
        utc: DateTime.utc(2026, 3, 5, 23, 59),
        elapsedRealtimeAtCaptureMillis: 0,
      );
      expect(await source.today(), '2026-03-05');
    });
  });
}
