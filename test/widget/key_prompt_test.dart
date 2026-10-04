// Asking for a provider key used to happen *to* the learner. TRIAL_CONSUMED
// and TRIAL_UNAVAILABLE routed straight to `/keys/entry` — a password field
// arriving mid-conversation with no explanation — and because the shell
// used `go`, that form had an empty stack under it, so system back closed
// the app outright (the same shape of bug as
// `assessment_back_navigation_test.dart`). QUOTA_EXHAUSTED said its piece
// in a footer under the composer, which is easy to miss entirely.
//
// All three now raise a dialog that explains itself first, and the form is
// *pushed* from it, so backing out returns to the conversation.
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/config/remote_config_repository.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/di/service_locator.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_screen.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/keys/domain/key_repository.dart';
import 'package:dry_run/features/keys/presentation/key_entry_screen.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_key_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Pair Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'You are given a list of integers and a target number.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 4, wrapUpAtTurn: 3, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

Session _session() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

DailySessionCubit _cubit() => DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
      analyticsClient: FakeAnalyticsClient(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );

/// Two locations, because the assertion is about which one the learner is
/// on and whether there is anything under it — not about what the key form
/// renders. The one test that needs the *real* form passes it in.
Future<GoRouter> _pump(WidgetTester tester, DailySessionCubit cubit, {Widget? keyEntry}) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.daily.path,
    routes: <RouteBase>[
      GoRoute(path: AppRoute.daily.path, builder: (_, _) => const DailyScreen()),
      GoRoute(
        path: AppRoute.keysEntry.path,
        builder: (_, _) => keyEntry ?? const Scaffold(body: Text('key form')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    BlocProvider<DailySessionCubit>.value(
      value: cubit,
      child: MaterialApp.router(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  // `pump`, not `pumpAndSettle`: the Cubit opens in `Opening`, which
  // renders a `CircularProgressIndicator` that never stops animating.
  await tester.pump();
  return router;
}

String _location(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

/// Resolved from `DailyScreen`, not from `MaterialApp`: `AppLocalizations`
/// lives *below* the app widget, so looking up from the app element finds
/// nothing.
AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(DailyScreen)))!;

void main() {
  testWidgets('a spent provider allowance explains itself in a dialog, and does not navigate on its own', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.quotaExhausted()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _l10n(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.keyPromptQuotaTitle), findsOneWidget);
    expect(
      find.text(l10n.keyPromptQuotaBody),
      findsOneWidget,
      reason: 'FR-008d: the learner is told it resets and that no charge occurred',
    );
    expect(
      _location(router),
      AppRoute.daily.path,
      reason: 'the dialog explains before anything moves — raising it must not navigate',
    );
  });

  testWidgets('the key form is pushed, so it has a conversation to go back to', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.quotaExhausted()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n(tester).keyPromptReplaceAction));
    await tester.pumpAndSettle();

    // Asserted on the widget, not on `_location`: an imperative `push`
    // leaves the delegate's configured URI at the route underneath, which
    // is precisely the stack this test is here to check exists.
    expect(find.text('key form'), findsOneWidget);
    expect(
      router.canPop(),
      isTrue,
      reason: 'this is the regression: `go` left an empty stack and system back closed the app',
    );
  });

  testWidgets('declining leaves the learner in the conversation, with the explanation still on screen', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.quotaExhausted()));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n(tester).keyPromptQuotaDismissAction));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(_location(router), AppRoute.daily.path);
    expect(
      find.text(_l10n(tester).errQuotaExhausted),
      findsOneWidget,
      reason: 'nothing is lost by declining — `_FailureNotice` still carries it',
    );
  });

  testWidgets('a spent taster asks before it puts a password field in front of anyone', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.trialConsumed()));
    await tester.pumpAndSettle();

    expect(find.text(_l10n(tester).keyPromptTrialTitle), findsOneWidget);
    expect(_location(router), AppRoute.daily.path);
  });

  testWidgets('the shared taster being full never borrows the spent-allowance copy', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.trialUnavailable()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _l10n(tester);
    expect(find.text(l10n.keyPromptTrialUnavailableTitle), findsOneWidget);
    expect(
      find.text(l10n.keyPromptQuotaTitle),
      findsNothing,
      reason: 'capacity is not an allowance this learner spent',
    );
  });

  testWidgets('the per-network daily cap offers key entry with its own copy', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.trialIpLimited()));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _l10n(tester);
    expect(find.text(l10n.keyPromptTrialIpLimitedTitle), findsOneWidget);
    expect(find.text(l10n.keyPromptAddAction), findsOneWidget);
    expect(find.text(l10n.keyPromptTrialUnavailableTitle), findsNothing);
    expect(_location(router), AppRoute.daily.path);
  });

  testWidgets('the dialog is raised once per reason — dismissing it keeps it dismissed', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.quotaExhausted()));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n(tester).keyPromptQuotaDismissAction));
    await tester.pumpAndSettle();

    // The same failure again — a re-emitted state must not re-raise it.
    cubit.emit(DailySessionState.failure(_session(), const RelayError.quotaExhausted()));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
  });

  group('backing out of the key form', () {
    setUp(() {
      sl.registerSingleton<KeyRepository>(FakeKeyRepository());
      sl.registerSingleton<AnalyticsClient>(FakeAnalyticsClient());
      sl.registerSingleton<RemoteConfigRepository>(
        FakeRemoteConfigRepository()..cachedValue = _config,
      );
    });
    tearDown(sl.reset);

    testWidgets('returns to the conversation rather than closing the app', (WidgetTester tester) async {
      final DailySessionCubit cubit = _cubit();
      addTearDown(cubit.close);

      final GoRouter router = await _pump(tester, cubit, keyEntry: const KeyEntryScreen());
      cubit.emit(DailySessionState.failure(_session(), const RelayError.trialConsumed()));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_l10n(tester).keyPromptAddAction));
      await tester.pumpAndSettle();
      expect(find.byType(KeyEntryScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.byType(KeyEntryScreen), findsNothing);
      expect(find.byType(DailyScreen), findsOneWidget);
      expect(_location(router), AppRoute.daily.path);
    });
  });
}
