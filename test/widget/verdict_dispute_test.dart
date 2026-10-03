// T106 (US4), FR-031: a dispute affordance must be present on every
// assessment screen and reachable in one step — asserted on both the
// verdict and the reveal, reached by driving the real state machine (a
// turn that reaches the cap, then ending the session) rather than by
// emitting a state directly.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/assessment/presentation/dispute_action.dart';
import 'package:dry_run/features/assessment/presentation/reveal_screen.dart';
import 'package:dry_run/features/assessment/presentation/verdict_screen.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_streak_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';

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

/// Drives a fresh cubit all the way to `Verdict`: opens, sends a turn
/// scripted to land on the cap, then ends the session — the same public
/// path `_CapReachedNotice`'s button uses, never an emitted state.
Future<(DailySessionCubit, FakeAssessmentRepository)> _cubitAtVerdict() async {
  final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
  final FakeAssessmentRepository assessmentRepository = FakeAssessmentRepository()
    ..requestHandler = (Session session) async => Ok(_assessment(session.id));
  final DailySessionCubit cubit = DailySessionCubit(
    sessionRepository: sessionRepository,
    streakRepository: FakeStreakRepository(),
    assessmentRepository: assessmentRepository,
    recognitionService: FakeRecognitionService(),
    configRepository: FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        contentManifestUrl: '/v1/content/manifest.json',
        chat: ChatConfig(turnCap: 1, wrapUpAtTurn: 1, minTurnChars: 5),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      ),
    analyticsClient: FakeAnalyticsClient(),
    micRationaleRepository: FakeMicRationaleRepository(),
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
  return (cubit, assessmentRepository);
}

void main() {
  testWidgets('the dispute affordance is on the verdict screen, reachable in one tap', (
    WidgetTester tester,
  ) async {
    final (DailySessionCubit cubit, FakeAssessmentRepository assessmentRepository) = await _cubitAtVerdict();
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DailySessionCubit>.value(value: cubit, child: const VerdictScreen()),
      ),
    );
    await tester.pump();

    // The verdict screen is a lazy `ListView`; on a test-sized window the
    // dispute control is below the fold and is not built until scrolled to.
    await tester.scrollUntilVisible(
      find.byType(DisputeAction),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final Finder disputeButton = find.widgetWithText(
      OutlinedButton,
      AppLocalizations.of(tester.element(find.byType(VerdictScreen)))!.verdictDisputeAction,
    );
    expect(disputeButton, findsOneWidget);
    await tester.tap(disputeButton);
    await tester.pump();
    expect(assessmentRepository.disputeCalls, 1);
  });

  testWidgets('the dispute affordance is on the reveal screen too', (WidgetTester tester) async {
    final (DailySessionCubit cubit, FakeAssessmentRepository assessmentRepository) = await _cubitAtVerdict();
    addTearDown(cubit.close);
    cubit.revealAssessment();

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DailySessionCubit>.value(value: cubit, child: const RevealScreen()),
      ),
    );
    await tester.pump();

    final Finder disputeButton = find.widgetWithText(
      OutlinedButton,
      AppLocalizations.of(tester.element(find.byType(RevealScreen)))!.verdictDisputeAction,
    );
    expect(disputeButton, findsOneWidget);
    await tester.tap(disputeButton);
    await tester.pump();
    expect(assessmentRepository.disputeCalls, 1);
  });
}
