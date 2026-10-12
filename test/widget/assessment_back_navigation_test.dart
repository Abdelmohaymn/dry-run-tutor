// The assessment screens are reached with `go`, not `push` — the session
// is over, so there is deliberately no stack under them. That left system
// back with nothing to pop, and on a physical device it closed the app
// outright from both the verdict and the editorial.
//
// Back now has somewhere to go on each: the verdict returns to the
// conversation (which offers a way straight back), and the editorial
// returns to the verdict it was opened from — by moving the *state*, since
// `DailySessionShell` is what owns navigation for this flow.
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/assessment/presentation/reveal_screen.dart';
import 'package:dry_run/features/assessment/presentation/verdict_screen.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
// Aliased: `Verdict` is both a wire enum and a Cubit state, and this file
// needs to name each of them.
import 'package:dry_run/features/chat/presentation/daily_session_state.dart' as chat;
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

Session _session() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.complete,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

Assessment _assessment() => Assessment(
      sessionId: 'session-1',
      matchedApproach: 'hash_map',
      matchedVerdict: MatchedVerdict.acceptable,
      insightsHit: const <String>['used a hashmap'],
      insightsAssisted: const <String>[],
      insightsMissed: const <String>[],
      wrongTurnsTaken: const <String>[],
      complexity: const Complexity(
        referenceTime: 'O(n)',
        referenceSpace: 'O(n)',
        assessment: 'correct',
      ),
      verdict: Verdict.pass,
      confidence: 0.8,
      feedback: '**Solid** reasoning throughout.',
      editorial: '**The move:** turn a search into a lookup.',
    );

DailySessionCubit _cubit() => DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );

/// A router carrying only the three locations this flow moves between, so
/// the assertion is about where back lands and nothing else.
Future<GoRouter> _pumpAt(WidgetTester tester, DailySessionCubit cubit, String initial) async {
  final GoRouter router = GoRouter(
    initialLocation: initial,
    routes: <RouteBase>[
      GoRoute(path: AppRoute.daily.path, builder: (_, _) => const Scaffold(body: SizedBox.shrink())),
      GoRoute(path: AppRoute.sessionVerdict.path, builder: (_, _) => const VerdictScreen()),
      GoRoute(path: AppRoute.sessionReveal.path, builder: (_, _) => const RevealScreen()),
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
  await tester.pump();
  return router;
}

String _location(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();

void main() {
  testWidgets('back from the verdict returns to the conversation, not out of the app', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.verdict(_session(), _assessment()));

    final GoRouter router = await _pumpAt(tester, cubit, AppRoute.sessionVerdict.path);
    expect(find.byType(VerdictScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoute.daily.path);
  });

  testWidgets('back from the editorial returns to the verdict it was opened from', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.revealed(_session(), _assessment()));

    final GoRouter router = await _pumpAt(tester, cubit, AppRoute.sessionReveal.path);
    expect(find.byType(RevealScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(_location(router), AppRoute.sessionVerdict.path);
    expect(
      cubit.state,
      isA<chat.Verdict>(),
      reason: 'the state moves back too — the shell routes off state, so the two must agree',
    );
  });

  testWidgets('the judge’s markdown renders as formatting, not as asterisks', (
    WidgetTester tester,
  ) async {
    final DailySessionCubit cubit = _cubit();
    addTearDown(cubit.close);
    cubit.emit(chat.DailySessionState.revealed(_session(), _assessment()));

    await _pumpAt(tester, cubit, AppRoute.sessionReveal.path);

    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('The move:'), findsOneWidget);
  });
}
