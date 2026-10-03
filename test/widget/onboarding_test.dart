// The app explained nothing about itself. A first real session on a device
// ended with the learner not knowing that the tutor never says "correct",
// that hints and examples cost nothing, that the assessment only arrives
// when *they* end the session, or that notifications had never been
// permitted. None of that is discoverable from a chat screen.
//
// What is asserted here is the part that must not regress: the carousel
// covers those points, the reminder is genuinely armed from inside it,
// both exits mark the welcome seen (so the guard cannot loop), and the
// walkthrough runs entirely locally — no session, no relay, no turn.
import 'dart:async';

import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/router/app_route.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/presentation/widgets/typing_indicator.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/onboarding/presentation/practice_screen.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/onboarding/presentation/welcome_screen.dart';
import 'package:dry_run/features/voice/domain/recognition_availability.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:dry_run/features/voice/presentation/widgets/waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_settings_repository.dart';

late FakeAnalyticsClient analyticsClient;
late FakeInstallRepository installRepository;
late FakeSettingsRepository settingsRepository;
late FakeRecognitionService recognitionService;
late FakeMicRationaleRepository micRationaleRepository;
late FakeSessionRepository sessionRepository;

ServerCounters _countersAt(int turnIndex) => ServerCounters(
      turnIndex: turnIndex,
      turnsRemaining: 5 - turnIndex,
      hintsRevealed: 0,
      hintsRemaining: 3,
      sessionEnded: null,
      leakBlocked: false,
    );

PracticeScreen _practiceScreen() => PracticeScreen(
      recognitionService: recognitionService,
      micRationaleRepository: micRationaleRepository,
      installRepository: installRepository,
      sessionRepository: sessionRepository,
    );

Future<GoRouter> _pumpWelcome(WidgetTester tester) async {
  final GoRouter router = GoRouter(
    initialLocation: AppRoute.welcome.path,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoute.welcome.path,
        builder: (_, _) => WelcomeScreen(
          installRepository: installRepository,
          settingsRepository: settingsRepository,
          analyticsClient: analyticsClient,
        ),
      ),
      GoRoute(path: AppRoute.welcomePractice.path, builder: (_, _) => _practiceScreen()),
      GoRoute(path: AppRoute.daily.path, builder: (_, _) => const Scaffold(body: SizedBox.shrink())),
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
  return router;
}

String _location(GoRouter router) => router.routerDelegate.currentConfiguration.uri.toString();

AppLocalizations _l10n(WidgetTester tester, Type screen) =>
    AppLocalizations.of(tester.element(find.byType(screen)))!;

void main() {
  tearDown(() => recognitionService.dispose());

  setUp(() {
    analyticsClient = FakeAnalyticsClient();
    installRepository = FakeInstallRepository()..welcomeSeen = false;
    settingsRepository = FakeSettingsRepository();
    recognitionService = FakeRecognitionService();
    // Already shown, so the walkthrough's typed path is what these
    // assertions exercise — the rationale sheet has its own test below.
    micRationaleRepository = FakeMicRationaleRepository()..shown = true;
    // No warm-up session by default, so the existing assertions keep
    // exercising the offline script they were written against; the live
    // path has its own tests below.
    sessionRepository = FakeSessionRepository();
  });

  group('the welcome carousel', () {
    testWidgets('opens on the premise, and reaches the practice offer', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      expect(find.text(l10n.welcomeSlide1Title), findsOneWidget);

      // Every slide, in order, through the control a learner would use.
      for (final String title in <String>[
        l10n.welcomeSlide2Title,
        l10n.welcomeSlide3Title,
        l10n.welcomeSlide4Title,
        l10n.welcomeSlide5Title,
        l10n.welcomeSlide6Title,
        l10n.welcomeSlide7Title,
        l10n.welcomeSlide8Title,
      ]) {
        await tester.tap(find.text(l10n.welcomeNextAction));
        await tester.pumpAndSettle();
        expect(find.text(title), findsOneWidget);
      }

      expect(find.text(l10n.welcomeTryAction), findsOneWidget);
      expect(find.text(l10n.welcomeSkipPracticeAction), findsOneWidget);
      expect(_location(router), AppRoute.welcome.path);
    });

    testWidgets('the slides cover the four things the device session showed were missing', (
      WidgetTester tester,
    ) async {
      await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      // The premise leads. Then: Socratic by design, hints are free,
      // finishing is the learner's, and the key is free to get.
      expect(l10n.welcomeSlide1Body, contains('AI'));
      expect(l10n.welcomeSlide4Title, contains('never tells'));
      expect(l10n.welcomeSlide4Body, contains('costs you a turn'));
      expect(l10n.welcomeSlide5Body, contains('Finish'));
      expect(l10n.welcomeSlide7Body, contains('free API key'));
    });

    testWidgets('the reminder slide actually arms the reminder', (WidgetTester tester) async {
      await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      await tester.tap(find.text(l10n.welcomeSkipAction));
      await tester.pumpAndSettle();
      // Skip lands on the last slide; walk back to the reminder one.
      for (int i = 0; i < 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(600, 0));
        await tester.pumpAndSettle();
      }
      expect(find.text(l10n.welcomeSlide6Title), findsOneWidget);

      await tester.tap(find.text(l10n.welcomeEnableRemindersAction));
      await tester.pumpAndSettle();

      expect(settingsRepository.scheduled, isNotNull);
      expect(settingsRepository.permissionRequests, 1);
      expect(find.text(l10n.welcomeRemindersOnNotice), findsOneWidget);
    });

    testWidgets('a blocked permission is said out loud, not swallowed', (
      WidgetTester tester,
    ) async {
      settingsRepository.permissionGranted = false;
      await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      await tester.tap(find.text(l10n.welcomeSkipAction));
      await tester.pumpAndSettle();
      for (int i = 0; i < 2; i++) {
        await tester.drag(find.byType(PageView), const Offset(600, 0));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text(l10n.welcomeEnableRemindersAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.welcomeRemindersBlockedNotice), findsOneWidget);
    });

    testWidgets('both exits mark the welcome seen — the guard can never loop', (
      WidgetTester tester,
    ) async {
      final GoRouter router = await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      await tester.tap(find.text(l10n.welcomeSkipAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.welcomeSkipPracticeAction));
      await tester.pumpAndSettle();

      expect(installRepository.welcomeSeen, isTrue);
      expect(_location(router), AppRoute.daily.path);
      expect(
        installRepository.practicePending,
        isFalse,
        reason: 'declining the walkthrough must not queue it for the next launch',
      );
    });

    testWidgets('taking the walkthrough also marks it seen', (WidgetTester tester) async {
      final GoRouter router = await _pumpWelcome(tester);
      final AppLocalizations l10n = _l10n(tester, WelcomeScreen);

      await tester.tap(find.text(l10n.welcomeSkipAction));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.welcomeTryAction));
      await tester.pumpAndSettle();

      expect(installRepository.welcomeSeen, isTrue);
      expect(_location(router), AppRoute.welcomePractice.path);
      // Set on the way in, not on the way out: closing the app on the
      // walkthrough's first frame still comes back to it.
      expect(installRepository.practicePending, isTrue);
    });
  });

  group('the practice walkthrough', () {
    Future<void> pumpPractice(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _practiceScreen(),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// The walkthrough with somewhere to go: both its exits navigate, and
    /// the plain-`home` harness above has no router to navigate with.
    Future<GoRouter> pumpPracticeRouted(WidgetTester tester) async {
      final GoRouter router = GoRouter(
        initialLocation: AppRoute.welcomePractice.path,
        routes: <RouteBase>[
          GoRoute(path: AppRoute.welcomePractice.path, builder: (_, _) => _practiceScreen()),
          GoRoute(
            path: AppRoute.daily.path,
            builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
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
      return router;
    }

    /// A warm-up session, so the walkthrough runs live rather than on its
    /// offline script.
    Session liveSession({ServerCounters counters = ServerCounters.initial}) => Session(
          id: 'practice-1',
          problem: const Problem(
            schemaVersion: 2,
            id: 'vp-0000',
            title: 'Largest in the list',
            ramp: 'easy',
            tags: <String>[],
            source: 'authored',
            statement: "You're given a list of numbers. Find the largest one and return it.",
            constraints: <String>[],
            estSpeakSeconds: 45,
            collections: <String>['practice'],
            glossaryTerms: <String>[],
            hintCount: 3,
          ),
          day: '2026-01-01',
          path: SessionPath.trial,
          status: SessionStatus.chatting,
          counters: counters,
          isRepeat: false,
          disputed: false,
          solutionRequestCount: 0,
        );

    Future<void> sendPractice(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
    }

    testWidgets('the tutor answers what was actually said, not the turn number', (
      WidgetTester tester,
    ) async {
      // The bug this screen was rewritten for: a learner who says "sort
      // it" was told "that is the idea — walk the list once", because the
      // reply was chosen by turn index and had never read the answer.
      sessionRepository.practiceSession = liveSession();
      final List<String> sent = <String>[];
      sessionRepository.sendTurnHandler = (Session s, String text, InputMode mode) {
        sent.add(text);
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          TurnEvent.token('Sorting orders every number. '),
          const TurnEvent.token('Do you need all of them in place to answer this?'),
          TurnEvent.meta(_countersAt(sent.length)),
        ]);
      };
      await pumpPracticeRouted(tester);

      await sendPractice(tester, 'I would sort the list and take the last one.');

      expect(sent, <String>['I would sort the list and take the last one.']);
      expect(find.textContaining('Do you need all of them in place'), findsOneWidget);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);
      expect(find.text(l10n.practiceTutorReply1), findsNothing, reason: 'a scripted line got through');
    });

    testWidgets('it shows the warm-up the relay actually served', (WidgetTester tester) async {
      sessionRepository.practiceSession = liveSession();
      await pumpPracticeRouted(tester);

      expect(find.text('Largest in the list'), findsOneWidget);
      expect(find.textContaining('Find the largest one'), findsOneWidget);
    });

    testWidgets('it runs to five turns, then offers today', (WidgetTester tester) async {
      sessionRepository.practiceSession = liveSession();
      int turn = 0;
      sessionRepository.sendTurnHandler = (Session s, String text, InputMode mode) {
        turn++;
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          TurnEvent.token('Reply $turn.'),
          TurnEvent.meta(_countersAt(turn)),
        ]);
      };
      await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      for (int i = 1; i <= 4; i++) {
        await sendPractice(tester, 'Turn $i.');
        expect(find.byType(TextField), findsOneWidget, reason: 'closed early, after $i turns');
      }

      await sendPractice(tester, 'Turn 5.');
      expect(find.text(l10n.practiceDoneTitle), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('a turn that fails twice says so, in the app\'s own words', (WidgetTester tester) async {
      sessionRepository.practiceSession = liveSession();
      int calls = 0;
      sessionRepository.sendTurnHandler = (Session s, String text, InputMode mode) {
        calls++;
        return Stream<TurnEvent>.error(const RelayException(RelayError.unclearRetry()));
      };
      await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await sendPractice(tester, 'I would walk the list once.');

      expect(calls, 2, reason: 'one silent retry before the error shows');
      expect(find.textContaining(l10n.errUnclearRetry), findsOneWidget);
      expect(find.textContaining('Code: UNCLEAR_RETRY'), findsOneWidget);
      // And the walkthrough is still usable — a failed turn is not the end.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('a turn that fails once is retried silently', (WidgetTester tester) async {
      sessionRepository.practiceSession = liveSession();
      int calls = 0;
      sessionRepository.sendTurnHandler = (Session s, String text, InputMode mode) {
        calls++;
        if (calls == 1) {
          return Stream<TurnEvent>.error(const RelayException(RelayError.unclearRetry()));
        }
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          const TurnEvent.token('What would you keep track of?'),
          TurnEvent.meta(_countersAt(1)),
        ]);
      };
      await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await sendPractice(tester, 'I would walk the list once.');

      expect(calls, 2);
      expect(find.text('What would you keep track of?'), findsOneWidget);
      expect(find.textContaining(l10n.errUnclearRetry), findsNothing);
    });

    testWidgets('the end card waits for the last reply, and a failed last turn does not end the run', (
      WidgetTester tester,
    ) async {
      // Found on a device: the fifth send showed "That is the whole app"
      // over a reply that had not arrived yet, which then failed.
      sessionRepository.practiceSession = liveSession();
      int turn = 0;
      StreamController<TurnEvent>? last;
      sessionRepository.sendTurnHandler = (Session s, String text, InputMode mode) {
        turn++;
        if (turn < 5) {
          return Stream<TurnEvent>.fromIterable(<TurnEvent>[
            TurnEvent.token('Reply $turn.'),
            TurnEvent.meta(_countersAt(turn)),
          ]);
        }
        last = StreamController<TurnEvent>();
        return last!.stream;
      };
      await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);
      for (int i = 1; i <= 4; i++) {
        await sendPractice(tester, 'Turn $i.');
      }

      await tester.enterText(find.byType(TextField), 'Turn 5.');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      expect(find.text(l10n.practiceDoneTitle), findsNothing, reason: 'shown before the reply arrived');

      // Both attempts at the fifth turn fail.
      last!.addError(const RelayException(RelayError.unclearRetry()));
      await last!.close();
      await tester.pump();
      last!.addError(const RelayException(RelayError.unclearRetry()));
      await last!.close();
      await tester.pumpAndSettle();

      expect(find.textContaining(l10n.errUnclearRetry), findsOneWidget);
      expect(find.text(l10n.practiceDoneTitle), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('with no session at all it still walks, on its own script', (
      WidgetTester tester,
    ) async {
      // Offline at first launch. The fallback must not look like a broken
      // screen, and must not pretend to have read anything.
      sessionRepository.practiceSession = null;
      await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await sendPractice(tester, 'I would sort it.');
      expect(find.text(l10n.practiceTutorReply1), findsOneWidget);
    });

    testWidgets('system back leaves for today rather than closing the app', (
      WidgetTester tester,
    ) async {
      // Found on a device: the carousel hands off with `go`, so the
      // walkthrough is the entire stack and back popped into nothing —
      // Android closed the app.
      installRepository.practicePending = true;
      final GoRouter router = await pumpPracticeRouted(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(_location(router), AppRoute.daily.path);
      expect(installRepository.practicePending, isFalse);
    });

    testWidgets('it can be left at any point — the walkthrough is an offer', (
      WidgetTester tester,
    ) async {
      installRepository.practicePending = true;
      final GoRouter router = await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.tap(find.text(l10n.practiceSkipAction));
      await tester.pumpAndSettle();

      expect(_location(router), AppRoute.daily.path);
      expect(
        installRepository.practicePending,
        isFalse,
        reason: 'a skipped walkthrough that stays pending reopens into itself forever',
      );
    });

    testWidgets('finishing it clears the return-here flag too', (WidgetTester tester) async {
      installRepository.practicePending = true;
      final GoRouter router = await pumpPracticeRouted(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.enterText(find.byType(TextField), 'I would loop and keep the biggest.');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Once per number, so O(n).');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.practiceStartTodayAction));
      await tester.pumpAndSettle();

      expect(_location(router), AppRoute.daily.path);
      expect(installRepository.practicePending, isFalse);
    });

    testWidgets('runs the whole scripted loop without any repository at all', (
      WidgetTester tester,
    ) async {
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      expect(find.text(l10n.practiceProblemTitle), findsOneWidget);
      expect(find.text(l10n.practiceTutorOpener), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'I would loop and keep the biggest.');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      // The dots, where the reply is about to land.
      expect(find.byType(TypingIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text(l10n.practiceTutorReply1), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Once per number, so O(n).');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text(l10n.practiceTutorReply2), findsOneWidget);
      // The composer gives way to the exit once the script is done.
      expect(find.text(l10n.practiceDoneTitle), findsOneWidget);
      expect(find.text(l10n.practiceStartTodayAction), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the hint affordance is taught here, before it matters', (
      WidgetTester tester,
    ) async {
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.tap(find.text(l10n.hintActionLabel));
      await tester.pumpAndSettle();

      expect(find.text(l10n.practiceHintText), findsOneWidget);
      // One canned rung, so it cannot be tapped into nonsense.
      final OutlinedButton hint = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(hint.onPressed, isNull);
    });

    testWidgets('the mic works here — a walkthrough of a voice app has to be speakable', (
      WidgetTester tester,
    ) async {
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(find.byType(Waveform), findsOneWidget, reason: 'recording, in place');

      recognitionService.emit(const PartialTextEvent('I would loop and keep'));
      await tester.pump();
      await tester.pump();
      expect(find.text('I would loop and keep'), findsOneWidget);

      recognitionService.emit(const FinalTextEvent('I would loop and keep the biggest.'));
      await tester.pump();
      await tester.pump();

      // Principle V, taught here: the words land in the composer to be
      // read and fixed, never straight into a send.
      expect(find.byType(Waveform), findsNothing);
      final TextField field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'I would loop and keep the biggest.');
      expect(find.text(l10n.practiceTutorReply1), findsNothing);
    });

    testWidgets('the microphone rationale precedes the first recording attempt (FR-014)', (
      WidgetTester tester,
    ) async {
      micRationaleRepository.shown = false;
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(find.text(l10n.micRationaleTitle), findsOneWidget);
      expect(
        find.byType(Waveform),
        findsNothing,
        reason: 'nothing listens until the rationale has been read',
      );
    });

    testWidgets('a phone that cannot do speech says so and leaves the keyboard', (
      WidgetTester tester,
    ) async {
      recognitionService.availabilityToReturn = RecognitionAvailability.unsupported;
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.tap(find.byIcon(Icons.mic));
      await tester.pumpAndSettle();

      expect(find.text(l10n.practiceRecognitionUnavailableNotice), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('an empty turn offers no send at all', (WidgetTester tester) async {
      await pumpPractice(tester);
      final AppLocalizations l10n = _l10n(tester, PracticeScreen);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      // Sharing the daily composer means whitespace never even presents a
      // send affordance: the trailing control is still the mic, so there
      // is nothing to tap that could spend a turn.
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.text(l10n.practiceTutorReply1), findsNothing);
    });
  });
}
