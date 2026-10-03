// T098 (US3): `DailySessionCubit.pullHint()` across the four scenarios
// that make the hint ladder a safety valve rather than another turn to
// spend — turn count never moves, the ladder's exhaustion reads as a
// closing line rather than an error, the cap never blocks a hint, and a
// fresh install's taster survives a hint pulled before a single word is
// spoken.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/hint_rung.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
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

Session _sessionWith({
  required ServerCounters counters,
  SessionPath path = SessionPath.trial,
}) =>
    Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: path,
      status: SessionStatus.chatting,
      counters: counters,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
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
  blocTest<DailySessionCubit, DailySessionState>(
    'turn count stays put while hint count decreases (FR-019, research.md R-007)',
    build: () {
      final Session before = _sessionWith(
        counters: const ServerCounters(
          turnIndex: 1,
          turnsRemaining: 11,
          hintsRevealed: 0,
          hintsRemaining: 3,
          sessionEnded: null,
          leakBlocked: false,
        ),
      );
      final Session after = before.copyWith(
        counters: const ServerCounters(
          turnIndex: 1,
          turnsRemaining: 11,
          hintsRevealed: 1,
          hintsRemaining: 2,
          sessionEnded: null,
          leakBlocked: false,
        ),
      );
      final FakeSessionRepository sessionRepository = FakeSessionRepository()
        ..initialSession = before
        ..watchSession = after
        ..pullHintHandler =
            (Session session) async => const Ok(HintRung(index: 1, text: 'Think about lookups.', exhausted: false));
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: FakeAnalyticsClient(),
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.composing(
      _sessionWith(
        counters: const ServerCounters(
          turnIndex: 1,
          turnsRemaining: 11,
          hintsRevealed: 0,
          hintsRemaining: 3,
          sessionEnded: null,
          leakBlocked: false,
        ),
      ),
      null,
    ),
    act: (DailySessionCubit cubit) => cubit.pullHint(),
    expect: () => <Matcher>[
      // The dots, where the hint will land, for as long as the pull is
      // on the wire (FR-025).
      isA<PullingHint>(),
      isA<Composing>()
          .having((Composing s) => s.session.counters.turnIndex, 'turnIndex', 1)
          .having((Composing s) => s.session.counters.hintsRevealed, 'hintsRevealed', 1)
          .having((Composing s) => s.session.counters.hintsRemaining, 'hintsRemaining', 2),
    ],
  );

  late FakeAnalyticsClient exhaustedAnalytics;
  blocTest<DailySessionCubit, DailySessionState>(
    'a ladder-exhausted pull renders the closing line and leaves the session open',
    build: () {
      final Session already = _sessionWith(
        counters: const ServerCounters(
          turnIndex: 2,
          turnsRemaining: 10,
          hintsRevealed: 3,
          hintsRemaining: 0,
          sessionEnded: null,
          leakBlocked: false,
        ),
      );
      final FakeSessionRepository sessionRepository = FakeSessionRepository()
        ..initialSession = already
        ..watchSession = already
        ..pullHintHandler = (Session session) async => const Ok(
              HintRung(
                index: 4,
                text: "That's every nudge I have for this one.",
                exhausted: true,
              ),
            );
      exhaustedAnalytics = FakeAnalyticsClient();
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: exhaustedAnalytics,
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.composing(
      _sessionWith(
        counters: const ServerCounters(
          turnIndex: 2,
          turnsRemaining: 10,
          hintsRevealed: 3,
          hintsRemaining: 0,
          sessionEnded: null,
          leakBlocked: false,
        ),
      ),
      null,
    ),
    act: (DailySessionCubit cubit) => cubit.pullHint(),
    // The refreshed session is identical to the seeded one — a pull that
    // hits the fixed closing line changes nothing about `ServerCounters`
    // — so `Cubit` (which dedupes by `==`) emits nothing new. That
    // absence is itself the assertion: the session never closes, so
    // nothing routes away from `Composing`.
    expect: () => <Matcher>[
      // The dots, where the hint will land, for as long as the pull is
      // on the wire (FR-025).
      isA<PullingHint>(),
      isA<Composing>(),
    ],
    verify: (DailySessionCubit cubit) {
      expect(cubit.state, isA<Composing>());
      expect(cubit.state, isNot(isA<Failure>()));
      expect(
        exhaustedAnalytics.emitted.map(((EventName, Map<String, Object>?) e) => e.$1),
        contains(EventName.hintLadderExhausted),
      );
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'a hint is still delivered after the turn cap — the cap bounds conversation, not hints (FR-028)',
    build: () {
      final Session before = _sessionWith(
        counters: const ServerCounters(
          turnIndex: 12,
          turnsRemaining: 0,
          hintsRevealed: 0,
          hintsRemaining: 3,
          sessionEnded: 'cap',
          leakBlocked: false,
        ),
      );
      final Session after = before.copyWith(
        counters: const ServerCounters(
          turnIndex: 12,
          turnsRemaining: 0,
          hintsRevealed: 1,
          hintsRemaining: 2,
          sessionEnded: 'cap',
          leakBlocked: false,
        ),
      );
      final FakeSessionRepository sessionRepository = FakeSessionRepository()
        ..initialSession = before
        ..watchSession = after
        ..pullHintHandler =
            (Session session) async => const Ok(HintRung(index: 1, text: 'Think about lookups.', exhausted: false));
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: FakeAnalyticsClient(),
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.capReached(
      _sessionWith(
        counters: const ServerCounters(
          turnIndex: 12,
          turnsRemaining: 0,
          hintsRevealed: 0,
          hintsRemaining: 3,
          sessionEnded: 'cap',
          leakBlocked: false,
        ),
      ),
    ),
    act: (DailySessionCubit cubit) => cubit.pullHint(),
    expect: () => <Matcher>[
      // The dots, where the hint will land, for as long as the pull is
      // on the wire (FR-025).
      isA<PullingHint>(),
      isA<CapReached>().having((CapReached s) => s.session.counters.hintsRevealed, 'hintsRevealed', 1),
    ],
  );

  late FakeAnalyticsClient freshInstallAnalytics;
  blocTest<DailySessionCubit, DailySessionState>(
    'a hint pulled before speaking on a fresh install does not consume the taster',
    build: () {
      final Session before = _sessionWith(counters: ServerCounters.initial);
      final Session after = before.copyWith(
        counters: const ServerCounters(
          turnIndex: 0,
          turnsRemaining: 0,
          hintsRevealed: 1,
          hintsRemaining: 2,
          sessionEnded: null,
          leakBlocked: false,
        ),
      );
      final FakeSessionRepository sessionRepository = FakeSessionRepository()
        ..initialSession = before
        ..watchSession = after
        ..pullHintHandler =
            (Session session) async => const Ok(HintRung(index: 1, text: 'Think about lookups.', exhausted: false));
      freshInstallAnalytics = FakeAnalyticsClient();
      return DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: freshInstallAnalytics,
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.composing(_sessionWith(counters: ServerCounters.initial), null),
    act: (DailySessionCubit cubit) => cubit.pullHint(),
    expect: () => <Matcher>[
      // The dots, where the hint will land, for as long as the pull is
      // on the wire (FR-025).
      isA<PullingHint>(),
      isA<Composing>().having((Composing s) => s.session.counters.turnIndex, 'turnIndex', 0),
    ],
    verify: (DailySessionCubit cubit) {
      expect(
        freshInstallAnalytics.emitted.map(((EventName, Map<String, Object>?) e) => e.$1),
        isNot(contains(EventName.trialSessionStarted)),
        reason: 'a hint pull alone must never look like the taster starting',
      );
    },
  );
}
