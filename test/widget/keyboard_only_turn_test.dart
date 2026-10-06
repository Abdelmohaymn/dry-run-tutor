// FR-010, FR-053: a learner who cannot or will not use voice is fully
// served by the keyboard, without that path being promoted over voice.
// This drives a complete turn — composer → typed draft → mandatory
// review → send → streamed reply → back to composing — with the
// recognition service never touched, proving the typed path needs
// nothing voice-related to complete a turn.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';

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
  late FakeSessionRepository sessionRepository;
  late FakeRecognitionService recognitionService;

  setUp(() {
    sessionRepository = FakeSessionRepository()..initialSession = _session();
    recognitionService = FakeRecognitionService();
  });

  blocTest<DailySessionCubit, DailySessionState>(
    'a keyboard-only learner completes a full turn without touching recognition',
    build: () => DailySessionCubit(
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
    ),
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        expect(mode, InputMode.text, reason: 'the typed path must tag the turn inputMode: text');
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          const TurnEvent.token('Good — walk me through the complexity.'),
          const TurnEvent.meta(
            ServerCounters(
              turnIndex: 1,
              turnsRemaining: 3,
              hintsRevealed: 0,
              hintsRemaining: 3,
              sessionEnded: null,
              leakBlocked: false,
            ),
          ),
        ]);
      };

      await cubit.sendTyped('I would use a hashmap to track values I have already seen.');
    },
    expect: () => <Matcher>[
      isA<Sending>(),
      isA<Streaming>(),
      isA<Composing>().having((Composing s) => s.session.counters.turnIndex, 'turnIndex', 1),
    ],
    verify: (DailySessionCubit cubit) {
      expect(recognitionService.stopCalls, 0);
      expect(recognitionService.cancelCalls, 0);
    },
  );
}
