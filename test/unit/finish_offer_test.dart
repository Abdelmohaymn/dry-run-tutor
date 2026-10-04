// Feature 005: the relay's finish check (`meta.ready_to_finish`) turns into
// an offer the learner answers. Never ends the session by itself; Keep going
// hides it for the rest of the session and tells the relay to stop checking.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/analytics/event_name.dart';
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
  statement: 'Return the two positions that add up to target.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

ServerCounters _counters(int turnIndex, {bool ready = false, String? ended}) => ServerCounters(
      turnIndex: turnIndex,
      turnsRemaining: 15 - turnIndex,
      hintsRevealed: 0,
      hintsRemaining: 3,
      sessionEnded: ended,
      leakBlocked: false,
      readyToFinish: ready,
    );

Session _sessionAt(int turnIndex) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: _counters(turnIndex),
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

DailySessionCubit _cubit(FakeSessionRepository repo, FakeAnalyticsClient analytics) => DailySessionCubit(
      sessionRepository: repo,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          contentManifestUrl: '/v1/content/manifest.json',
          chat: ChatConfig(turnCap: 15, wrapUpAtTurn: 12, minTurnChars: 5),
          trial: TrialConfig(turnCap: 15),
          keyedProviders: <String>['nebius'],
        ),
      analyticsClient: analytics,
      micRationaleRepository: FakeMicRationaleRepository(),
    );

/// Replies to each sent turn with the next counters in [replies].
FakeSessionRepository _repo(List<ServerCounters> replies) {
  final FakeSessionRepository repo = FakeSessionRepository()..initialSession = _sessionAt(1);
  int call = 0;
  repo.sendTurnHandler = (Session session, String text, InputMode mode) =>
      Stream<TurnEvent>.fromIterable(<TurnEvent>[TurnEvent.meta(replies[call++])]);
  return repo;
}

void main() {
  final FakeAnalyticsClient analytics = FakeAnalyticsClient();
  late FakeSessionRepository repo;

  blocTest<DailySessionCubit, DailySessionState>(
    'ready_to_finish turns into FinishOffered, and a turn without it stays Composing',
    build: () {
      repo = _repo(<ServerCounters>[_counters(2), _counters(3, ready: true)]);
      return _cubit(repo, analytics);
    },
    seed: () => DailySessionState.composing(_sessionAt(1), null),
    act: (DailySessionCubit cubit) async {
      await cubit.sendTyped('Two loops over every pair, I think.');
      await cubit.sendTyped('Remember each value with its index and look up target minus it.');
    },
    expect: () => <Matcher>[
      isA<Sending>(),
      isA<Composing>(),
      isA<Sending>(),
      isA<FinishOffered>().having((FinishOffered s) => s.session.counters.turnIndex, 'turnIndex', 3),
    ],
    verify: (_) {
      expect(analytics.emitted.map((e) => e.$1), contains(EventName.finishOfferShown));
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'Keep going hides the offer for the rest of the session and tells the relay to stop checking',
    build: () {
      repo = _repo(<ServerCounters>[_counters(4, ready: true)]);
      return _cubit(repo, analytics);
    },
    seed: () => DailySessionState.finishOffered(_sessionAt(3)),
    act: (DailySessionCubit cubit) async {
      cubit.dismissFinishOffer();
      await cubit.sendTyped('Let me also think about duplicates.');
    },
    expect: () => <Matcher>[
      isA<Composing>(),
      isA<Sending>(),
      isA<Composing>().having((Composing s) => s.session.counters.turnIndex, 'turnIndex', 4),
    ],
    verify: (_) {
      expect(repo.sendTurnFinishOfferDismissed, <bool>[true]);
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'the cap still wins over a ready answer on the terminal turn',
    build: () {
      repo = _repo(<ServerCounters>[_counters(15, ready: true, ended: 'cap')]);
      return _cubit(repo, analytics);
    },
    seed: () => DailySessionState.composing(_sessionAt(14), null),
    act: (DailySessionCubit cubit) => cubit.sendTyped('Last thing I would say.'),
    expect: () => <Matcher>[isA<Sending>(), isA<CapReached>()],
  );
}
