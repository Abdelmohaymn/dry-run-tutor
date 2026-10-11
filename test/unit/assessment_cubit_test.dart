// T105 (US4): `worker/src/lib/judge-core.ts` claims the judge slot before
// calling the provider and releases it again on any provider failure, so
// a retry after THIS install's own failed attempt gets a genuine second
// try — never `SESSION_ALREADY_JUDGED`. `DailySessionCubit.retry()` from
// a `Failure` reached via `_pursueAssessment` must actually re-request the
// judge, not just sit there, and must land on `Verdict` once the retry
// succeeds.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/assessment/domain/complexity.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
// `Verdict` is ambiguous between the wire enum (above) and this file's
// Cubit state — the state half is imported under a prefix so both names
// stay usable in the same file.
import 'package:dry_run/features/chat/presentation/daily_session_state.dart' hide Verdict;
import 'package:dry_run/features/chat/presentation/daily_session_state.dart' as state show Verdict;
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

Session _capReachedSession() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: const ServerCounters(
        turnIndex: 12,
        turnsRemaining: 0,
        hintsRevealed: 0,
        hintsRemaining: 3,
        sessionEnded: 'cap',
        leakBlocked: false,
      ),
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

Assessment _assessment(String sessionId) => Assessment(
      sessionId: sessionId,
      matchedApproach: 'hash_map',
      matchedVerdict: MatchedVerdict.acceptable,
      insightsHit: const <String>['used a hashmap'],
      insightsMissed: const <String>[],
      wrongTurnsTaken: const <String>[],
      complexity: const Complexity(
        referenceTime: 'O(n)',
        referenceSpace: 'O(n)',
        assessment: 'correct',
      ),
      verdict: Verdict.pass,
      confidence: 0.8,
      feedback: 'Solid reasoning throughout.',
      editorial: '## The move\n\nUse a hashmap.',
    );

void main() {
  late FakeAssessmentRepository assessmentRepository;
  blocTest<DailySessionCubit, DailySessionState>(
    'a failed assessment is retryable, and the retry does not report the session as already assessed',
    build: () {
      final FakeSessionRepository sessionRepository = FakeSessionRepository()
        ..initialSession = _capReachedSession();
      assessmentRepository = FakeAssessmentRepository();
      int call = 0;
      assessmentRepository.requestHandler = (Session session) async {
        call++;
        if (call == 1) {
          return const Err(RelayError.transport());
        }
        return Ok(_assessment(session.id));
      };
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: assessmentRepository,
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
    },
    seed: () => DailySessionState.capReached(_capReachedSession()),
    act: (DailySessionCubit cubit) async {
      await cubit.endSessionUser();
      await cubit.retry();
    },
    expect: () => <Matcher>[
      isA<Judging>(),
      isA<Failure>().having((Failure s) => s.error, 'error', const RelayError.transport()),
      isA<Judging>(),
      isA<state.Verdict>().having((state.Verdict s) => s.assessment.verdict, 'verdict', Verdict.pass),
    ],
    verify: (DailySessionCubit cubit) {
      expect(assessmentRepository.requestCalls, 2, reason: 'the retry must actually re-request the judge');
    },
  );

  DailySessionCubit buildCubit() {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _capReachedSession();
    return DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: assessmentRepository,
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
  }

  // The judge path used to emit a RATE_LIMITED failure and schedule
  // nothing, leaving a Finish with no button and no pending retry
  // (found on a physical device, 2026-10-11).
  blocTest<DailySessionCubit, DailySessionState>(
    'RATE_LIMITED on Finish retries the judge by itself after retryAfter',
    build: () {
      assessmentRepository = FakeAssessmentRepository();
      int call = 0;
      assessmentRepository.requestHandler = (Session session) async {
        call++;
        if (call == 1) {
          return const Err(RelayError.rateLimited(retryAfter: Duration(milliseconds: 50)));
        }
        return Ok(_assessment(session.id));
      };
      return buildCubit();
    },
    seed: () => DailySessionState.capReached(_capReachedSession()),
    act: (DailySessionCubit cubit) => cubit.endSessionUser(),
    wait: const Duration(milliseconds: 300),
    expect: () => <Matcher>[
      isA<Judging>(),
      isA<Failure>().having((Failure s) => s.error, 'error', isA<RateLimited>()),
      isA<Judging>(),
      isA<state.Verdict>().having((state.Verdict s) => s.assessment.verdict, 'verdict', Verdict.pass),
    ],
    verify: (DailySessionCubit cubit) {
      expect(assessmentRepository.requestCalls, 2);
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'tapping Try again during a rate-limit wait retries once, not twice',
    build: () {
      assessmentRepository = FakeAssessmentRepository();
      int call = 0;
      assessmentRepository.requestHandler = (Session session) async {
        call++;
        if (call == 1) {
          return const Err(RelayError.rateLimited(retryAfter: Duration(milliseconds: 100)));
        }
        return Ok(_assessment(session.id));
      };
      return buildCubit();
    },
    seed: () => DailySessionState.capReached(_capReachedSession()),
    act: (DailySessionCubit cubit) async {
      await cubit.endSessionUser();
      // Early tap: the pending timer must be cancelled.
      await cubit.retry();
    },
    // Well past the 100 ms the cancelled timer would have fired at.
    wait: const Duration(milliseconds: 400),
    expect: () => <Matcher>[
      isA<Judging>(),
      isA<Failure>().having((Failure s) => s.error, 'error', isA<RateLimited>()),
      isA<Judging>(),
      isA<state.Verdict>(),
    ],
    verify: (DailySessionCubit cubit) {
      expect(assessmentRepository.requestCalls, 2, reason: 'the timer must not fire a third request');
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'Review the assessment on a closed session with no assessment goes after it',
    build: () {
      assessmentRepository = FakeAssessmentRepository();
      assessmentRepository.requestHandler =
          (Session session) async => Ok(_assessment(session.id));
      return buildCubit();
    },
    seed: () => DailySessionState.sessionClosed(
      _capReachedSession().copyWith(status: SessionStatus.pendingJudge),
    ),
    act: (DailySessionCubit cubit) => cubit.openClosedAssessment(),
    expect: () => <Matcher>[
      isA<Judging>(),
      isA<state.Verdict>().having((state.Verdict s) => s.assessment.verdict, 'verdict', Verdict.pass),
    ],
    verify: (DailySessionCubit cubit) {
      expect(assessmentRepository.requestCalls, 1);
    },
  );
}
