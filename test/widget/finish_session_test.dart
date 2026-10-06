// FR-023, US4 scenario 1. The wrap-up card told the learner "it's a good
// place to end and see how it went" and gave them nothing to end it with:
// the only way through was an unlabelled app-bar icon. A learner who
// assumed the tutor would close the session itself never got an
// assessment at all (reported from a physical device, 2026-09-04).
//
// Driven through the real state machine — a turn scripted to land on the
// wrap-up threshold — rather than by emitting `WrappingUp` directly, so
// this also proves the control appears on the path a learner takes.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_screen.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
// Aliased: `Verdict` is both a wire enum and a Cubit state.
import 'package:dry_run/features/chat/presentation/daily_session_state.dart' as chat;
import 'package:dry_run/features/chat/presentation/widgets/composer.dart';
import 'package:dry_run/features/chat/presentation/widgets/wrap_up_banner.dart';
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

Session _session({SessionStatus status = SessionStatus.chatting}) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: status,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

Assessment _assessment(String sessionId) => Assessment(
      sessionId: sessionId,
      matchedApproach: 'hashmap',
      matchedVerdict: MatchedVerdict.optimal,
      insightsHit: const <String>['complement_lookup'],
      insightsMissed: const <String>[],
      wrongTurnsTaken: const <String>[],
      complexity: const Complexity(
        referenceTime: 'O(n)',
        referenceSpace: 'O(n)',
        assessment: 'correct',
      ),
      verdict: Verdict.pass,
      confidence: 0.8,
      feedback: 'Clear reasoning.',
      editorial: 'Use a hash map.',
    );

void main() {
  testWidgets('the wrap-up card carries the control that ends the session', (
    WidgetTester tester,
  ) async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session();
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
          // Wrap up at the first turn, cap well above it — this is the
          // wrap-up state, not the cap.
          chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 1, minTurnChars: 5),
          trial: TrialConfig(turnCap: 12),
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

    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      return Stream<TurnEvent>.fromIterable(const <TurnEvent>[
        TurnEvent.meta(
          ServerCounters(
            turnIndex: 1,
            turnsRemaining: 11,
            hintsRevealed: 0,
            hintsRemaining: 3,
            sessionEnded: null,
            leakBlocked: false,
          ),
        ),
      ]);
    };
    await cubit.sendTyped('I would walk the list once with a map of seen values.');
    await tester.pump();

    expect(cubit.state, isA<chat.WrappingUp>());
    expect(find.byType(WrapUpBanner), findsOneWidget);

    final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(DailyScreen)))!;
    final Finder finish = find.widgetWithText(FilledButton, l10n.wrapUpFinishAction);
    expect(finish, findsOneWidget, reason: 'the card that recommends ending must offer it');
    // The tutor never closes the session — the learner has to, and the
    // card now says so rather than leaving them to guess.
    expect(find.text(l10n.endSessionExplainer), findsOneWidget);

    await tester.tap(finish);
    await tester.pump();

    expect(
      cubit.state,
      isA<chat.Verdict>(),
      reason: 'finishing goes straight for the assessment — that is the whole point of the control',
    );
  });

  group('a session that is already over', () {
    // Resuming today after finishing put the composer, the mic, the finish
    // nudge and the app bar's Finish action all back on screen, for a
    // session the relay would refuse every one of them for — the learner
    // could tap all four and get nothing (found on a physical device).
    Future<DailySessionCubit> pumpResumed(
      WidgetTester tester, {
      required SessionStatus status,
      Assessment? stored,
    }) async {
      final FakeAssessmentRepository assessments = FakeAssessmentRepository();
      if (stored != null) {
        assessments.seed(stored);
      }
      final DailySessionCubit cubit = DailySessionCubit(
        sessionRepository: FakeSessionRepository()..initialSession = _session(status: status),
        streakRepository: FakeStreakRepository(),
        assessmentRepository: assessments,
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository(),
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
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('reopens on the assessment it already holds, not on a live composer', (
      WidgetTester tester,
    ) async {
      final DailySessionCubit cubit = await pumpResumed(
        tester,
        status: SessionStatus.complete,
        stored: _assessment('session-1'),
      );

      expect(cubit.state, isA<chat.Verdict>());
      expect(find.byType(Composer), findsNothing);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('offers no Finish — there is nothing left to finish', (
      WidgetTester tester,
    ) async {
      await pumpResumed(
        tester,
        status: SessionStatus.complete,
        stored: _assessment('session-1'),
      );
      final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(DailyScreen)))!;

      expect(find.text(l10n.finishActionLabel), findsNothing);
      expect(find.text(l10n.finishNudgeBody), findsNothing);
    });

    testWidgets('closed with no assessment stored says so, rather than pretending it is live', (
      WidgetTester tester,
    ) async {
      final DailySessionCubit cubit = await pumpResumed(
        tester,
        status: SessionStatus.pendingJudge,
      );

      expect(cubit.state, isA<chat.SessionClosed>());
      expect(find.byType(Composer), findsNothing);
      final AppLocalizations l10n = AppLocalizations.of(tester.element(find.byType(DailyScreen)))!;
      expect(find.text(l10n.sessionClosedTitle), findsOneWidget);
    });
  });

  testWidgets('the finish control is withheld while there is nothing to assess', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: WrapUpBanner(onFinish: null)),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
