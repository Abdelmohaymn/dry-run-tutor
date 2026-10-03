// The dev app must never report into prod's events table, but the prod app
// always reports and the dev app reports to the dev relay.
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/config/flavor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldSendAnalytics', () {
    const cases = <(bool, Flavor, bool)>[
      (true, Flavor.prod, false),
      (true, Flavor.dev, true),
      (false, Flavor.prod, true),
      (false, Flavor.dev, true),
    ];
    for (final (isDevApp, backend, expected) in cases) {
      test('isDevApp=$isDevApp backend=${backend.name} -> $expected', () {
        expect(shouldSendAnalytics(isDevApp: isDevApp, backend: backend), expected);
      });
    }
  });

  test('NoopAnalyticsClient.emit completes without throwing', () {
    expect(() => const NoopAnalyticsClient().emit(EventName.values.first), returnsNormally);
  });
}
