// T040: PracticeScreen gains an onLeave callback so the web demo (feature
// 007) can replace go_router's exit with its own — this screen has no
// router at all when compiled for the demo. Null in the app keeps the
// existing go_router exit.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/onboarding/presentation/practice_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../fakes/fake_install_repository.dart';
import '../../fakes/fake_mic_rationale_repository.dart';
import '../../fakes/fake_recognition_service.dart';
import '../../fakes/fake_session_repository.dart';

Widget _practiceScreen({VoidCallback? onLeave, bool typedOnly = false}) => PracticeScreen(
      recognitionService: FakeRecognitionService(),
      micRationaleRepository: FakeMicRationaleRepository(),
      installRepository: FakeInstallRepository(),
      sessionRepository: FakeSessionRepository(),
      onLeave: onLeave,
      typedOnly: typedOnly,
    );

Widget _wrapNoRouter(Widget child) => MaterialApp(
      home: child,
      theme: appTheme,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        ...AppLocalizations.localizationsDelegates,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );

Widget _wrapWithRouter(Widget child) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.welcomePractice.path,
    routes: <RouteBase>[
      GoRoute(path: AppRoute.welcomePractice.path, builder: (_, _) => child),
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
  testWidgets('with onLeave set and no router, Skip calls onLeave once and throws nothing', (
    WidgetTester tester,
  ) async {
    int called = 0;
    await tester.pumpWidget(_wrapNoRouter(_practiceScreen(onLeave: () => called++)));
    await tester.pump();

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(PracticeScreen)))!;
    await tester.tap(find.text(l10n.practiceSkipAction));
    await tester.pumpAndSettle();

    expect(called, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with onLeave null, Skip navigates through go_router as before', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapWithRouter(_practiceScreen()));
    await tester.pump();

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(PracticeScreen)))!;
    await tester.tap(find.text(l10n.practiceSkipAction));
    await tester.pumpAndSettle();

    expect(find.text('daily'), findsOneWidget);
  });

  testWidgets('typedOnly hides the mic and its hint', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapNoRouter(_practiceScreen(onLeave: () {}, typedOnly: true)));
    await tester.pump();

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(PracticeScreen)))!;
    expect(find.byIcon(Icons.mic), findsNothing);
    expect(find.text(l10n.practiceMicHint), findsNothing);
  });

  testWidgets('without typedOnly the mic shows', (WidgetTester tester) async {
    await tester.pumpWidget(_wrapNoRouter(_practiceScreen(onLeave: () {})));
    await tester.pump();

    expect(find.byIcon(Icons.mic), findsOneWidget);
  });
}
