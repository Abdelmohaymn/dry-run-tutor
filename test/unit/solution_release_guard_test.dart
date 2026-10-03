// T107 (US4), FR-021: the second solution request must be unsendable from
// any state but `ConfirmSolutionRelease`. `confirmSolutionRelease()` is
// the **only** call path that can send it — every other state's attempt
// is a no-op, asserted here by checking that `SessionRepository.sendTurn`
// was never even called, not just that the state didn't change.
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

Session _sessionWithOneSolutionAsk() => const Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 1,
    );

RuntimeConfig get _config => const RuntimeConfig(
      minSupportedVersion: '1.0.0',
      killedProblemIds: <String>[],
      contentManifestUrl: '/v1/content/manifest.json',
      chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
      trial: TrialConfig(turnCap: 4),
      keyedProviders: <String>['groq'],
    );

void main() {
  late FakeSessionRepository sessionRepository;

  DailySessionCubit buildCubit() => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: FakeAnalyticsClient(),
        micRationaleRepository: FakeMicRationaleRepository(),
      );

  setUp(() {
    sessionRepository = FakeSessionRepository()..initialSession = _sessionWithOneSolutionAsk();
  });

  for (final DailySessionState Function(Session) seedOf in <DailySessionState Function(Session)>[
    (Session s) => DailySessionState.composing(s, null),
    (Session s) => DailySessionState.wrappingUp(s),
    (Session s) => DailySessionState.capReached(s),
  ]) {
    final DailySessionState seeded = seedOf(_sessionWithOneSolutionAsk());
    blocTest<DailySessionCubit, DailySessionState>(
      'confirmSolutionRelease() is a no-op from ${seeded.runtimeType}',
      build: buildCubit,
      seed: () => seedOf(_sessionWithOneSolutionAsk()),
      act: (DailySessionCubit cubit) => cubit.confirmSolutionRelease(),
      expect: () => <Matcher>[],
      verify: (DailySessionCubit cubit) {
        expect(
          sessionRepository.sendTurnSolutionRequestCounts,
          isEmpty,
          reason: 'a second solution request must never reach sendTurn from ${seeded.runtimeType}',
        );
      },
    );
  }

  blocTest<DailySessionCubit, DailySessionState>(
    'requestSolution() on an already-asked session routes to ConfirmSolutionRelease instead of sending',
    build: buildCubit,
    seed: () => DailySessionState.composing(_sessionWithOneSolutionAsk(), null),
    act: (DailySessionCubit cubit) => cubit.requestSolution(),
    expect: () => <Matcher>[isA<ConfirmSolutionRelease>()],
    verify: (DailySessionCubit cubit) {
      expect(sessionRepository.sendTurnSolutionRequestCounts, isEmpty);
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'confirmSolutionRelease() is the one path that actually sends the second request',
    build: buildCubit,
    seed: () => DailySessionState.confirmSolutionRelease(_sessionWithOneSolutionAsk()),
    act: (DailySessionCubit cubit) {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        return Stream<TurnEvent>.fromIterable(const <TurnEvent>[
          TurnEvent.meta(
            ServerCounters(
              turnIndex: 3,
              turnsRemaining: 8,
              hintsRevealed: 0,
              hintsRemaining: 3,
              sessionEnded: 'solution',
              leakBlocked: false,
            ),
          ),
        ]);
      };
      return cubit.confirmSolutionRelease();
    },
    verify: (DailySessionCubit cubit) {
      expect(sessionRepository.sendTurnSolutionRequestCounts, <int?>[2]);
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'a first solution request is an ordinary turn — no confirm screen, nothing warns or blocks it',
    build: () {
      sessionRepository.initialSession = _sessionWithOneSolutionAsk().copyWith(solutionRequestCount: 0);
      return buildCubit();
    },
    seed: () => DailySessionState.composing(
      _sessionWithOneSolutionAsk().copyWith(solutionRequestCount: 0),
      null,
    ),
    act: (DailySessionCubit cubit) {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        return Stream<TurnEvent>.fromIterable(const <TurnEvent>[
          TurnEvent.meta(
            ServerCounters(
              turnIndex: 2,
              turnsRemaining: 9,
              hintsRevealed: 0,
              hintsRemaining: 3,
              sessionEnded: null,
              leakBlocked: false,
            ),
          ),
        ]);
      };
      return cubit.requestSolution();
    },
    verify: (DailySessionCubit cubit) {
      expect(sessionRepository.sendTurnSolutionRequestCounts, <int?>[1]);
      expect(cubit.state, isNot(isA<ConfirmSolutionRelease>()));
    },
  );
}
