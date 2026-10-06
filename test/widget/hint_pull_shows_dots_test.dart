// The rewarded video closes and the rung still has to come back from the
// relay. That gap used to leave the screen exactly as it was — a tap that
// did nothing, right after the learner had watched a video for it.
//
// Driven through the real state machine rather than an emitted state, so
// this also proves the dots go away again and the composer comes back to
// whichever state the hint was pulled from.
import 'dart:async';

import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/features/chat/domain/hint_rung.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_screen.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:dry_run/features/hints/presentation/hint_action.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
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

void main() {
  testWidgets('a hint on the wire paints the dots, then hands the composer back', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
    final Completer<Result<HintRung>> onTheWire = Completer<Result<HintRung>>();
    sessionRepository.pullHintHandler = (Session _) => onTheWire.future;

    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          chat: ChatConfig(turnCap: 4, wrapUpAtTurn: 3, minTurnChars: 5),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
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

    expect(find.byType(TypingIndicator), findsNothing, reason: 'nothing is waiting yet');

    unawaited(cubit.pullHint());
    await tester.pump();

    expect(cubit.state, isA<PullingHint>());
    expect(
      find.byType(TypingIndicator),
      findsOneWidget,
      reason: 'the waiting belongs where the hint is about to land',
    );
    expect(
      find.byType(HintAction),
      findsNothing,
      reason: 'the controls step aside so a second tap cannot buy a second video',
    );

    onTheWire.complete(
      const Ok<HintRung>(HintRung(index: 1, text: 'Think about what you have already seen.', exhausted: false)),
    );
    await tester.pump();
    await tester.pump();

    expect(cubit.state, isA<Composing>());
    expect(find.byType(TypingIndicator), findsNothing, reason: 'the dots must not outlive the pull');
    expect(find.byType(HintAction), findsOneWidget, reason: 'the composer comes back where it was');
  });
}
