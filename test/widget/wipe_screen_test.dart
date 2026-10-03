// FR-039f's delete is irreversible and restores neither the taster nor
// install identity, so the tap that starts it must not be the tap that
// finishes it. These tests are about that gap: what a mis-tap costs.
import 'package:dry_run/core/di/service_locator.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/settings/domain/settings_repository.dart';
import 'package:dry_run/features/settings/presentation/wipe_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_settings_repository.dart';

Widget _harness() {
  final GoRouter router = GoRouter(
    initialLocation: '/settings/wipe',
    routes: <RouteBase>[
      GoRoute(path: '/settings/wipe', builder: (_, _) => const WipeScreen()),
      GoRoute(path: AppRoute.daily.path, builder: (_, _) => const Text('daily')),
    ],
  );
  return MaterialApp.router(
    routerConfig: router,
    theme: appTheme,
    localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
      ...AppLocalizations.localizationsDelegates,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
  );
}

void main() {
  late FakeSettingsRepository settings;

  setUp(() {
    settings = FakeSettingsRepository();
    sl.registerSingleton<SettingsRepository>(settings);
  });
  tearDown(sl.reset);

  testWidgets('the destructive button asks before it deletes anything', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    expect(settings.wipes, 0, reason: 'the first tap deleted data on its own');
  });

  testWidgets('cancelling leaves every conversation where it was', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsNothing);
    expect(settings.wipes, 0);
    expect(find.byType(WipeScreen), findsOneWidget, reason: 'cancelling should not navigate away');
  });

  testWidgets('confirming wipes once and returns to today', (WidgetTester tester) async {
    await tester.pumpWidget(_harness());
    await tester.tap(find.text('Delete everything'));
    await tester.pumpAndSettle();

    // The dialog's own confirm, not the screen button behind it — both
    // carry the same label, and only the topmost one is the decision.
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Delete everything')));
    await tester.pumpAndSettle();

    expect(settings.wipes, 1);
    expect(find.text('daily'), findsOneWidget);
  });
}
