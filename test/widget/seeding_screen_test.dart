// The first-launch waiting screen's one promise (FR-047a/b) is that it
// keeps trying and leaves on its own. These tests are about the ways that
// promise can quietly stop being true: a bootstrap call that never
// returns, and a screen that has already decided it is attempting.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dry_run/core/config/remote_config_repository.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/features/onboarding/presentation/seeding_screen.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_problem_repository.dart';

/// A config repository whose `load()` never completes — the shape of a
/// platform channel with no reply or a database that will not open, which
/// no `dio` timeout underneath can bound.
class _HangingConfigRepository extends FakeRemoteConfigRepository {
  int loadCalls = 0;

  @override
  Future<RuntimeConfig> load() {
    loadCalls++;
    return Completer<RuntimeConfig>().future;
  }
}

Widget _harness({
  required RemoteConfigRepository configRepository,
  required FakeProblemRepository problemRepository,
}) {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.seeding.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.seeding.path,
        builder: (_, _) => SeedingScreen(
          installRepository: FakeInstallRepository(),
          configRepository: configRepository,
          problemRepository: problemRepository,
          connectivity: _SilentConnectivity(),
        ),
      ),
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

/// Connectivity that never emits, so these tests exercise the screen's own
/// retry rather than a stream event standing in for it.
class _SilentConnectivity implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream<List<ConnectivityResult>>.empty();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      const <ConnectivityResult>[ConnectivityResult.none];
}

void main() {
  testWidgets('a bootstrap call that never returns does not end the retries', (
    WidgetTester tester,
  ) async {
    final _HangingConfigRepository config = _HangingConfigRepository();
    await tester.pumpWidget(
      _harness(configRepository: config, problemRepository: FakeProblemRepository()),
    );
    await tester.pump();
    expect(config.loadCalls, 1);

    // Past the attempt timeout: the latch has to have been released by
    // something other than the hung call completing, because it never
    // will.
    await tester.pump(const Duration(seconds: 45));
    await tester.pump();
    expect(config.loadCalls, greaterThan(1), reason: 'the screen stopped trying after one hang');

    expect(find.byType(SeedingScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a later attempt that lands a cached problem leaves for today', (
    WidgetTester tester,
  ) async {
    final _HangingConfigRepository config = _HangingConfigRepository();
    final FakeProblemRepository problems = FakeProblemRepository();
    await tester.pumpWidget(_harness(configRepository: config, problemRepository: problems));
    await tester.pump();
    expect(find.byType(SeedingScreen), findsOneWidget);

    // What a retry is for: the condition that kept the screen up is gone
    // by the time the next tick reads it.
    problems.hasAny = true;
    await tester.pump(const Duration(seconds: 45));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('daily'), findsOneWidget);
  });
}
