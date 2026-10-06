// SC-017 / T077: no learner reaches the cap un-nudged. `CapReached` must
// be unreachable without first passing through `WrappingUp` — asserted
// here by driving two consecutive turns that cross both thresholds and
// checking the exact state sequence, not just the final state.
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
  glossaryTerms: <String>[],
  hintCount: 3,
);

Session _sessionAt(int turnIndex) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: ServerCounters(
        turnIndex: turnIndex,
        turnsRemaining: 3 - turnIndex,
        hintsRevealed: 0,
        hintsRemaining: 3,
        sessionEnded: null,
        leakBlocked: false,
      ),
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

void main() {
  blocTest<DailySessionCubit, DailySessionState>(
    'the turn that reaches wrap_up_at_turn emits WrappingUp, and only the next one — the terminal '
    'turn — can emit CapReached',
    build: () {
      final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _sessionAt(1);
      int call = 0;
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        call++;
        // turn_cap: 3, wrap_up_at_turn: 2 — the first turn sent here lands
        // exactly on the wrap-up threshold, the second on the cap.
        final ServerCounters counters = call == 1
            ? const ServerCounters(
                turnIndex: 2,
                turnsRemaining: 1,
                hintsRevealed: 0,
                hintsRemaining: 3,
                sessionEnded: null,
                leakBlocked: false,
              )
            : const ServerCounters(
                turnIndex: 3,
                turnsRemaining: 0,
                hintsRevealed: 0,
                hintsRemaining: 3,
                sessionEnded: 'cap',
                leakBlocked: false,
              );
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[TurnEvent.meta(counters)]);
      };
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()
          ..cachedValue = const RuntimeConfig(
            minSupportedVersion: '1.0.0',
            killedProblemIds: <String>[],
            chat: ChatConfig(turnCap: 3, wrapUpAtTurn: 2, minTurnChars: 5),
            trial: TrialConfig(turnCap: 4),
            keyedProviders: <String>['groq'],
          ),
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.composing(_sessionAt(1), null),
    act: (DailySessionCubit cubit) async {
      await cubit.sendTyped('Turn one, still short of the cap.');
      await cubit.sendTyped('Turn two, the terminal one.');
    },
    expect: () => <Matcher>[
      isA<Sending>(),
      isA<WrappingUp>().having((WrappingUp s) => s.session.counters.turnIndex, 'turnIndex', 2),
      isA<Sending>(),
      isA<CapReached>().having((CapReached s) => s.session.counters.turnIndex, 'turnIndex', 3),
    ],
  );
}
