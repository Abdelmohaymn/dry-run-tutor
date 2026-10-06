// Speaking a turn used to cost two full-screen navigations — `/session/record`
// to talk, `/session/review` to fix the transcript — and the conversation was
// invisible for both. This drives a whole spoken turn through the real state
// machine and asserts the learner never leaves the daily screen: the message
// list stays mounted from the first word to the send, and each step renders
// inside the composer's own slot.
//
// The guarantees that matter are unchanged and asserted here too: the review
// step is still mandatory (Principle V, FR-012) — recognition lands in
// `InlineReview`, never straight into a send.
import 'dart:async';

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
import 'package:dry_run/features/chat/presentation/widgets/composer.dart';
import 'package:dry_run/features/chat/presentation/widgets/inline_recorder.dart';
import 'package:dry_run/features/chat/presentation/widgets/inline_review.dart';
import 'package:dry_run/features/chat/presentation/widgets/message_list.dart';
import 'package:dry_run/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
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
  title: 'Pair Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'You are given a list of integers and a target number.',
  constraints: <String>['2 <= nums.length <= 10^7'],
  examples: <ProblemExample>[
    ProblemExample(input: 'nums = [2, 7], target = 9', output: '[0, 1]'),
  ],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>['hashmap'],
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
  late FakeRecognitionService recognitionService;
  late DailySessionCubit cubit;

  setUp(() {
    recognitionService = FakeRecognitionService();
    cubit = DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: recognitionService,
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
      micRationaleRepository: FakeMicRationaleRepository(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await recognitionService.dispose();
  });

  Future<void> pumpDaily(WidgetTester tester) async {
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
  }

  testWidgets('recording and transcript review both happen on the daily screen', (
    WidgetTester tester,
  ) async {
    await pumpDaily(tester);

    expect(find.byType(Composer), findsOneWidget);
    expect(find.byType(MessageList), findsOneWidget);

    await cubit.startRecording();
    await tester.pump();

    expect(cubit.state, isA<Recording>());
    expect(find.byType(DailyScreen), findsOneWidget, reason: 'no navigation happened');
    expect(find.byType(InlineRecorder), findsOneWidget);
    expect(
      find.byType(MessageList),
      findsOneWidget,
      reason: 'the conversation stays on screen while the learner speaks',
    );

    recognitionService.emit(const PartialTextEvent('I would use a hash map'));
    // Two pumps: one to let the broadcast stream deliver into the Cubit,
    // one to paint the state it emitted.
    await tester.pump();
    await tester.pump();
    expect(find.text('I would use a hash map'), findsOneWidget);

    recognitionService.emit(const FinalTextEvent('I would use a hash map to track seen values.'));
    await tester.pump();
    await tester.pump();

    expect(
      cubit.state,
      isA<ReviewingTranscript>(),
      reason: 'Principle V: recognition lands in review, never straight into a send',
    );
    expect(find.byType(InlineReview), findsOneWidget);
    expect(find.byType(MessageList), findsOneWidget);
    expect(find.byType(InlineRecorder), findsNothing);
  });

  testWidgets('waiting for the tutor reads as a reply arriving, not as machinery', (
    WidgetTester tester,
  ) async {
    // A spinner is the right shape for "the app is loading" and the wrong
    // one for "someone is answering you", and it sat in the composer
    // rather than where the reply was about to appear.
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session();
    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: recognitionService,
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
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

    // A stream that stays open and never yields, so `Sending` is what is
    // on screen for as long as the assertion needs it to be.
    final StreamController<TurnEvent> inFlight = StreamController<TurnEvent>();
    addTearDown(inFlight.close);
    sessionRepository.sendTurnHandler =
        (Session session, String text, InputMode mode) => inFlight.stream;
    unawaited(cubit.sendTyped('I would walk the list once with a map of seen values.'));
    await tester.pump();
    await tester.pump();

    expect(cubit.state, isA<Sending>());
    expect(find.byType(TypingIndicator), findsOneWidget);
    expect(
      find.byType(CircularProgressIndicator),
      findsNothing,
      reason: 'the waiting belongs in the conversation, not in the composer',
    );
  });

  testWidgets('a typed turn sends on one tap, without a review step', (
    WidgetTester tester,
  ) async {
    await pumpDaily(tester);

    // The field is part of the composer now — no mode to switch into.
    await tester.enterText(find.byType(TextField), 'Walk the list once with a map.');
    await tester.pump();
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();

    expect(cubit.state, isNot(isA<ReviewingTranscript>()));
    expect(find.byType(InlineReview), findsNothing);
    expect(find.byType(MessageList), findsOneWidget);
  });
}
