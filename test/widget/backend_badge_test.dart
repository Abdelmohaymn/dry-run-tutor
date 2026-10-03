// The backend badge renders the relay's name, or nothing in the shipped
// build. Every case passes `androidFlavor` explicitly so the result does not
// depend on the flavor `flutter test` happens to run under.
import 'package:dry_run/core/config/flavor.dart';
import 'package:dry_run/features/settings/presentation/backend_badge.dart';
import 'package:flutter_test/flutter_test.dart';

import '../golden/golden_harness.dart';

void main() {
  testWidgets('dev app on the prod relay says PROD API', (WidgetTester tester) async {
    await tester.pumpWidget(
      goldenHarness(
        const BackendBadge(androidFlavor: 'dev', backend: Flavor.prod),
      ),
    );

    expect(find.text('PROD API'), findsOneWidget);
    expect(find.text('DEV API'), findsNothing);
  });

  testWidgets('dev app on the dev relay says DEV API', (WidgetTester tester) async {
    await tester.pumpWidget(
      goldenHarness(
        const BackendBadge(androidFlavor: 'dev', backend: Flavor.dev),
      ),
    );

    expect(find.text('DEV API'), findsOneWidget);
    expect(find.text('PROD API'), findsNothing);
  });

  testWidgets('prod app on the prod relay shows no badge', (WidgetTester tester) async {
    await tester.pumpWidget(
      goldenHarness(
        const BackendBadge(androidFlavor: 'prod', backend: Flavor.prod),
      ),
    );

    expect(find.text('DEV API'), findsNothing);
    expect(find.text('PROD API'), findsNothing);
  });
}
