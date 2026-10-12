// The notification popup after the first daily verdict: shown once per
// install, only while notifications are blocked, and its accept arms the
// default reminder, falls through to Android's settings when the
// permission was refused, and lands on the reminder screen.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/assessment/presentation/verdict_screen.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/settings/domain/reminder_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_settings_repository.dart';
import '../fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Two Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given an array of integers, return indices of the two numbers that add up to target.',
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
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

Assessment _assessment(String sessionId) => Assessment(
      sessionId: sessionId,
      matchedApproach: 'hash_map',
      matchedVerdict: MatchedVerdict.acceptable,
      insightsHit: const <String>['used a hashmap'],
      insightsAssisted: const <String>[],
      insightsMissed: const <String>['two-pointer alternative'],
      wrongTurnsTaken: const <String>[],
      complexity: const Complexity(
        referenceTime: 'O(n)',
        referenceSpace: 'O(n)',
        assessment: 'correct',
      ),
      verdict: Verdict.pass,
      confidence: 0.8,
      feedback: 'Solid reasoning throughout.',
      editorial: 'Use a hashmap.',
    );

/// A cubit driven to `Verdict` through a capped turn and a user end, the
/// same public path verdict_dispute_test.dart takes.
Future<DailySessionCubit> _cubitAtVerdict(FakeSettingsRepository settings) async {
  final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
  final DailySessionCubit cubit = DailySessionCubit(
    sessionRepository: sessionRepository,
    streakRepository: FakeStreakRepository(),
    assessmentRepository: FakeAssessmentRepository()
      ..requestHandler = (Session session) async => Ok(_assessment(session.id)),
    recognitionService: FakeRecognitionService(),
    configRepository: FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        chat: ChatConfig(turnCap: 1, wrapUpAtTurn: 1, minTurnChars: 5),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      ),
    micRationaleRepository: FakeMicRationaleRepository(),
    settingsRepository: settings,
  );
  await cubit.open();
  sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
    return Stream<TurnEvent>.fromIterable(const <TurnEvent>[
      TurnEvent.meta(
        ServerCounters(
          turnIndex: 1,
          turnsRemaining: 0,
          hintsRevealed: 0,
          hintsRemaining: 3,
          sessionEnded: 'cap',
          leakBlocked: false,
        ),
      ),
    ]);
  };
  await cubit.sendTyped('Here is my full approach and its complexity.');
  await cubit.endSessionUser();
  return cubit;
}

Future<void> _pumpVerdict(WidgetTester tester, DailySessionCubit cubit) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.sessionVerdict.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.sessionVerdict.path,
        builder: (_, _) => BlocProvider<DailySessionCubit>.value(value: cubit, child: const VerdictScreen()),
      ),
      GoRoute(
        path: AppRoute.settingsReminder.path,
        builder: (_, _) => const Scaffold(body: Text('reminder screen')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MaterialApp.router(
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) => AppLocalizations.of(tester.element(find.byType(Navigator).first))!;

void main() {
  testWidgets('blocked notifications raise the popup once, and Not now closes it', (WidgetTester tester) async {
    final FakeSettingsRepository settings = FakeSettingsRepository()..permissionGranted = false;
    final DailySessionCubit cubit = await _cubitAtVerdict(settings);
    addTearDown(cubit.close);

    await _pumpVerdict(tester, cubit);
    expect(find.text(_l10n(tester).notificationNudgeTitle), findsOneWidget);

    // Both buttons sit side by side, never stacked.
    final Offset dismiss = tester.getCenter(find.text(_l10n(tester).notificationNudgeDismiss));
    final Offset accept = tester.getCenter(find.text(_l10n(tester).notificationNudgeAction));
    expect(dismiss.dy, accept.dy);
    expect(dismiss.dx, lessThan(accept.dx));

    // Tapping outside does not close it; only a button does.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).notificationNudgeTitle), findsOneWidget);

    await tester.tap(find.text(_l10n(tester).notificationNudgeDismiss));
    await tester.pumpAndSettle();
    expect(find.text(_l10n(tester).notificationNudgeTitle), findsNothing);
    expect(settings.settingsOpened, 0);
    expect(settings.scheduled, isNull);

    // A second visit to a verdict does not ask again.
    await _pumpVerdict(tester, cubit);
    expect(find.text(_l10n(tester).notificationNudgeTitle), findsNothing);
  });

  testWidgets('allowed notifications raise no popup', (WidgetTester tester) async {
    final FakeSettingsRepository settings = FakeSettingsRepository();
    final DailySessionCubit cubit = await _cubitAtVerdict(settings);
    addTearDown(cubit.close);

    await _pumpVerdict(tester, cubit);
    expect(find.text(_l10n(tester).notificationNudgeTitle), findsNothing);
  });

  testWidgets('accepting arms the default reminder, opens settings when refused, then shows the reminder screen', (
    WidgetTester tester,
  ) async {
    final FakeSettingsRepository settings = FakeSettingsRepository()..permissionGranted = false;
    final DailySessionCubit cubit = await _cubitAtVerdict(settings);
    addTearDown(cubit.close);

    await _pumpVerdict(tester, cubit);
    await tester.tap(find.text(_l10n(tester).notificationNudgeAction));
    await tester.pumpAndSettle();

    expect(settings.scheduled, ReminderTime.defaultTime);
    expect(settings.settingsOpened, 1);
    expect(find.text('reminder screen'), findsOneWidget);
  });
}
