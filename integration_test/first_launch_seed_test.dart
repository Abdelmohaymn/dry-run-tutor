// T143 (US7), FR-047a/b, SC-022: a brand-new install with no network
// reaches the designed `/seeding` waiting screen, retries by itself as
// connectivity changes, and enters the app the moment the seed lands —
// with no error dialog, no bare retry button, and no blank screen at any
// point.
//
// Same substitution as the other integration tests in this directory
// (offline_queue_test.dart, voice_interruption_test.dart): the relay round
// trip and the platform connectivity plugin are scripted, since the claim
// under test is `SeedingScreen`'s own retry-and-enter behaviour, not the
// network path or the OS connectivity API themselves.
import 'dart:async';

import 'package:dry_run/core/config/remote_config_repository.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/onboarding/domain/install_repository.dart';
import 'package:dry_run/features/onboarding/presentation/seeding_screen.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/problem/domain/problem_repository.dart';
import 'package:dry_run/features/problem/domain/problem_summary.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

import '../test/fakes/fake_install_repository.dart';

class _MockConnectivity extends Mock implements Connectivity {}

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

/// Fails `load()` until [available] is flipped, mirroring `seedGuard`'s
/// "no cache and no network" first-launch case.
class _ScriptedConfigRepository implements RemoteConfigRepository {
  bool available = false;
  RuntimeConfig? _cached;

  @override
  RuntimeConfig? cached() => _cached;

  /// No persisted row in this scenario — a genuine first launch hydrates
  /// to nothing, which is what sends the app to `/seeding`.
  @override
  Future<RuntimeConfig?> hydrateFromCache() async => _cached;

  @override
  Future<RuntimeConfig> load() async {
    if (!available) {
      throw StateError('offline');
    }
    _cached = _config;
    return _cached!;
  }

  @override
  Stream<RuntimeConfig> watch() => const Stream<RuntimeConfig>.empty();
}

class _ScriptedProblemRepository implements ProblemRepository {
  bool prefetchSucceeds = false;

  @override
  Future<void> fetchPractice() async {
    if (!prefetchSucceeds) {
      throw StateError('offline');
    }
  }

  @override
  Future<Problem> fetchDaily(String date, {String? problemId}) async => throw StateError('offline');

  @override
  Future<List<ProblemSummary>> fetchProblems() async => const <ProblemSummary>[];

  @override
  Future<Problem?> cachedForDate(String date) async => null;

  @override
  Future<Problem?> byId(String problemId) async => null;

  @override
  Future<List<Problem>> available(RuntimeConfig config) async => const <Problem>[];

  @override
  Future<Problem?> practiceProblem() async => null;

  @override
  Future<bool> hasAnyCached() async => prefetchSucceeds;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpSeeding(
    WidgetTester tester, {
    required InstallRepository installRepository,
    required _ScriptedConfigRepository configRepository,
    required _ScriptedProblemRepository problemRepository,
    required Connectivity connectivity,
  }) async {
    final GoRouter router = GoRouter(
      initialLocation: AppRoute.seeding.path,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoute.seeding.path,
          builder: (_, _) => SeedingScreen(
            installRepository: installRepository,
            configRepository: configRepository,
            problemRepository: problemRepository,
            connectivity: connectivity,
          ),
        ),
        GoRoute(path: AppRoute.daily.path, builder: (_, _) => const Text('HOME')),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        // `SeedingScreen` — like every screen in this app — reads
        // `context.appTypography`, which resolves a `ThemeData` extension.
        // Without the real theme the screen throws on its first build, so
        // this is load-bearing, not cosmetic.
        theme: appTheme,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          ...AppLocalizations.localizationsDelegates,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }

  testWidgets('offline at launch: shows the designed waiting screen, no dialog, no bare retry button', (
    WidgetTester tester,
  ) async {
    final _MockConnectivity connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());

    await pumpSeeding(
      tester,
      installRepository: FakeInstallRepository(),
      configRepository: _ScriptedConfigRepository(),
      problemRepository: _ScriptedProblemRepository(),
      connectivity: connectivity,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Setting up'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(SimpleDialog), findsNothing);
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    // Never a blank screen: the explanatory copy is always present, not
    // just the spinner.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('retries by itself as connectivity changes, and enters the app the moment the seed lands', (
    WidgetTester tester,
  ) async {
    final StreamController<List<ConnectivityResult>> connectivityChanges =
        StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(connectivityChanges.close);
    final _MockConnectivity connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => connectivityChanges.stream);

    final _ScriptedConfigRepository configRepository = _ScriptedConfigRepository();
    final _ScriptedProblemRepository problemRepository = _ScriptedProblemRepository();

    await pumpSeeding(
      tester,
      installRepository: FakeInstallRepository(),
      configRepository: configRepository,
      problemRepository: problemRepository,
      connectivity: connectivity,
    );
    await tester.pump();
    await tester.pump();

    // Still offline: stuck on the waiting screen, not the app.
    expect(find.text('Setting up'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    // Connectivity returns — the seed can now land.
    configRepository.available = true;
    problemRepository.prefetchSucceeds = true;
    connectivityChanges.add(<ConnectivityResult>[ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('HOME'), findsOneWidget);
  });
}
