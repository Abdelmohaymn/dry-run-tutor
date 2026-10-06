// RATE_LIMITED on the learner's own key used to replace the conversation
// with a full "catching up" screen that never said the limit was the
// key's. It is now a popup over the conversation that names the limit,
// and closes by itself when the Cubit resends the turn.
import 'package:dry_run/core/config/runtime_config.dart';
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
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
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
  testWidgets('a rate limit shows a popup over the conversation, which closes itself when the turn resends', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    final GoRouter router = await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.rateLimited(retryAfter: Duration(seconds: 20))));
    await tester.pumpAndSettle();

    final AppLocalizations l10n = _l10n(tester);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text(l10n.rateLimitTitle), findsOneWidget);
    expect(find.text(l10n.rateLimitBody(20)), findsOneWidget);
    expect(_location(router), AppRoute.daily.path, reason: 'the conversation stays underneath');

    cubit.emit(DailySessionState.sending(_session(), 'my turn'));
    // `pump`s, not `pumpAndSettle`: `Sending` animates its typing dots
    // forever. The state reaches the popup's listener a frame late, so
    // the exit transition needs a second timed frame to finish.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AlertDialog), findsNothing, reason: 'the resend closes the popup');
    expect(find.byType(DailyScreen), findsOneWidget, reason: 'closing it must not pop the conversation too');
  });

  testWidgets('OK closes the popup and leaves the conversation', (WidgetTester tester) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);

    await _pump(tester, cubit);
    cubit.emit(DailySessionState.failure(_session(), const RelayError.rateLimited(retryAfter: Duration(seconds: 1))));
    await tester.pumpAndSettle();

    await tester.tap(find.text(_l10n(tester).rateLimitOkAction));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(DailyScreen), findsOneWidget);
  });
}
