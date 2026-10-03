// T103 (US3): the cap bounds conversation, not hints (FR-028) and not the
// learner's ability to close the session (FR-023) — both affordances must
// still be on screen once `CapReached` is reached, driven through the real
// state machine rather than an emitted state, so this also proves neither
// control silently vanished behind the cap.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_screen.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/hints/presentation/hint_action.dart';
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

void main() {
  testWidgets('CapReached keeps both the hint action and the end-session affordance on screen', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          contentManifestUrl: '/v1/content/manifest.json',
          chat: ChatConfig(turnCap: 4, wrapUpAtTurn: 3, minTurnChars: 5),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
      analyticsClient: FakeAnalyticsClient(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<DailySessionCubit>.value(value: cubit, child: const DailyScreen()),
      ),
    );
    await cubit.open();
    await tester.pump();

    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      return Stream<TurnEvent>.fromIterable(const <TurnEvent>[
        TurnEvent.meta(
          ServerCounters(
            turnIndex: 4,
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
    await tester.pump();

    expect(cubit.state, isA<CapReached>());
    expect(find.byType(HintAction), findsOneWidget, reason: 'FR-028: hints stay live at the cap');
    expect(
      find.widgetWithText(
        OutlinedButton,
        AppLocalizations.of(tester.element(find.byType(DailyScreen)))!.endSessionLabel,
      ),
      findsOneWidget,
      reason: 'FR-023: the cap must not remove the learner\'s ability to close the session',
    );
  });
}
