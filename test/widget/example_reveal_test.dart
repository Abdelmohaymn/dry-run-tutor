// Examples arrive the way hints do: one at a time, on the learner's own
// ask, into the conversation they scroll back through — not behind a modal
// that closes and takes the example with it. Two things have to hold for
// that to be true: the bubble has to say which example it is, and the
// control has to stop offering one when they have all been shown.
//
// Nothing here touches the relay. Examples ship inside the cached public
// half, so a reveal is a local insert and costs no turn and no allowance.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/l10n/generated/app_localizations.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/text/example_body.dart';
import 'package:dry_run/core/theme/app_theme.dart';
import 'package:dry_run/features/chat/domain/message.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/widgets/message_list.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/problem/presentation/examples_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';

const List<ProblemExample> _examples = <ProblemExample>[
  ProblemExample(
    input: 'words = ["abc", "ada"]',
    output: '"ada"',
    explanation: 'The first word that reads the same in both directions.',
  ),
  ProblemExample(input: 'words = ["def"]', output: '""'),
];

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0003',
  title: 'First Palindromic String',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'You are given a list of words.',
  constraints: <String>[],
  examples: _examples,
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

Message _exampleMessage(int seq, ProblemExample example) => Message(
      id: 'example-$seq',
      seq: seq,
      role: TurnRole.tutor,
      text: renderExampleBody(example.input, example.output, example.explanation),
      kind: MessageKind.example,
      delivery: Delivery.sent,
    );

Future<void> _pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: appTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('a revealed example is labelled by its ordinal, like a hint rung', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      MessageList(
        messages: <Message>[
          _exampleMessage(0, _examples[0]),
          _exampleMessage(1, _examples[1]),
        ],
        hintCount: 3,
        exampleCount: _examples.length,
      ),
    );

    expect(find.text('Example 1 of 2'), findsOneWidget);
    expect(find.text('Example 2 of 2'), findsOneWidget);
    // The body renders as markdown, so the backticks around the input are
    // formatting, not text the learner reads.
    expect(find.textContaining('words = ["abc", "ada"]'), findsOneWidget);
    expect(find.textContaining('`'), findsNothing);
  });

  testWidgets('the control stops offering an example once they are all out', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Column(
        children: <Widget>[
          ExamplesAction(problem: _problem, revealed: 1, onPressed: () {}),
          ExamplesAction(problem: _problem, revealed: 2, onPressed: () {}),
        ],
      ),
    );

    final Iterable<OutlinedButton> buttons = tester.widgetList<OutlinedButton>(
      find.byType(OutlinedButton),
    );
    expect(buttons.first.onPressed, isNotNull, reason: 'one example is still unshown');
    expect(buttons.last.onPressed, isNull, reason: 'every example has been shown');
  });

  testWidgets('a problem with no authored examples offers no control at all', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      ExamplesAction(
        problem: const Problem(
          schemaVersion: 2,
          id: 'vp-0001',
          title: 'Pair Sum',
          ramp: 'easy',
          tags: <String>[],
          source: 'authored',
          statement: 'You are given a list of integers.',
          constraints: <String>[],
          estSpeakSeconds: 60,
          collections: <String>[],
          glossaryTerms: <String>[],
          hintCount: 3,
        ),
        revealed: 0,
        onPressed: () {},
      ),
    );

    expect(find.byType(OutlinedButton), findsNothing);
  });

  test('pullExample reveals in order and is a no-op once exhausted', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session();
    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
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
    await cubit.open();

    await cubit.pullExample();
    await cubit.pullExample();
    await cubit.pullExample();

    expect(
      sessionRepository.examplesRevealed,
      _examples.length,
      reason: 'the third ask has nothing left to reveal and must not wrap around',
    );
  });
}
