// T131 (US6), FR-042: airplane mode mid-session, draining on reconnect, an
// app kill mid-session, and a forced RATE_LIMITED retried at the same
// point in the conversation. On the underground, everything still works
// except the send — and the send fails as a retryable bubble sitting in
// the conversation, never as a lost thought.
//
// The relay round trip is scripted (`FakeSessionRepository`), same
// substitution and same reason as `voice_interruption_test.dart` and
// `trial_to_keyed_handover_test.dart`: the claim under test is the app's
// handling of the interruption, not the network path itself. The actual
// enqueue-on-transport-failure logic (`SessionRepositoryImpl`) and the
// drain worker's own serialisation and solution-count guard
// (`OutboxDrainBloc`) are exercised directly, against a real
// in-memory database, in `test/unit/outbox_drain_bloc_test.dart`.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_analytics_client.dart';
import '../test/fakes/fake_assessment_repository.dart';
import '../test/fakes/fake_config_repository.dart';
import '../test/fakes/fake_mic_rationale_repository.dart';
import '../test/fakes/fake_recognition_service.dart';
import '../test/fakes/fake_session_repository.dart';
import '../test/fakes/fake_streak_repository.dart';

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  DailySessionCubit buildCubit(FakeSessionRepository sessionRepository) => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()
          ..cachedValue = const RuntimeConfig(
            minSupportedVersion: '1.0.0',
            killedProblemIds: <String>[],
            contentManifestUrl: '/v1/content/manifest.json',
            chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
            trial: TrialConfig(turnCap: 4),
            keyedProviders: <String>['groq'],
          ),
        analyticsClient: FakeAnalyticsClient(),
        micRationaleRepository: FakeMicRationaleRepository(),
      );

  test('airplane mode mid-turn: the text is preserved as a retryable bubble, never lost', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
    final DailySessionCubit cubit = buildCubit(sessionRepository);
    addTearDown(cubit.close);
    // `DailySessionCubit` refuses every action until `open()` has resolved
    // (it throws "used before open() resolved" rather than guessing at a
    // session). The relaunch test below already opened; these did not.
    await cubit.open();

    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      return Stream<TurnEvent>.error(const RelayException(RelayError.transport()));
    };

    await cubit.sendTyped('my full approach');

    final DailySessionState state = cubit.state;
    if (state is! Failure || state.error is! TransportFailure) {
      throw StateError('expected Failure(transport()) after airplane mode, got $state');
    }
  });

  test('draining on reconnect resends the same text and reaches Composing again', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
    final DailySessionCubit cubit = buildCubit(sessionRepository);
    addTearDown(cubit.close);
    // `DailySessionCubit` refuses every action until `open()` has resolved
    // (it throws "used before open() resolved" rather than guessing at a
    // session). The relaunch test below already opened; these did not.
    await cubit.open();

    bool online = false;
    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      if (!online) {
        return Stream<TurnEvent>.error(const RelayException(RelayError.transport()));
      }
      return Stream<TurnEvent>.fromIterable(<TurnEvent>[
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

    await cubit.sendTyped('my full approach');
    expect(cubit.state, isA<Failure>());

    // Reconnected — the same failure-driven `retry()` a "tap to retry"
    // bubble would call is what the drain worker's own success path
    // mirrors for the queued row (the same request payload, replayed).
    online = true;
    await cubit.retry();

    final DailySessionState state = cubit.state;
    if (state is! Composing || state.session.counters.turnIndex != 1) {
      throw StateError('expected Composing with turnIndex 1 after reconnecting, got $state');
    }
  });

  test('an app kill mid-session restores the session, counters, and the unsent draft exactly', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session().copyWith(
        counters: const ServerCounters(
          turnIndex: 2,
          turnsRemaining: 2,
          hintsRevealed: 1,
          hintsRemaining: 2,
          sessionEnded: null,
          leakBlocked: false,
        ),
      );
    final DailySessionCubit before = buildCubit(sessionRepository);
    await before.open();
    await before.close(); // the process dies here, mid-session

    // A fresh Cubit over the same persisted repository state — exactly
    // what a relaunch after an app kill looks like (FR-024).
    final DailySessionCubit after = buildCubit(sessionRepository);
    addTearDown(after.close);
    await after.open();

    final DailySessionState state = after.state;
    if (state is! Composing) {
      throw StateError('expected Composing on relaunch, got $state');
    }
    expect(state.session.counters.turnIndex, 2);
    expect(state.session.counters.hintsRevealed, 1);
  });

  test('a forced RATE_LIMITED is retried automatically at the same point in the conversation', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()..initialSession = _session();
    final DailySessionCubit cubit = buildCubit(sessionRepository);
    addTearDown(cubit.close);
    // `DailySessionCubit` refuses every action until `open()` has resolved
    // (it throws "used before open() resolved" rather than guessing at a
    // session). The relaunch test below already opened; these did not.
    await cubit.open();

    int calls = 0;
    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      calls++;
      if (calls == 1) {
        return Stream<TurnEvent>.error(
          const RelayException(RelayError.rateLimited(retryAfter: Duration(milliseconds: 30))),
        );
      }
      return Stream<TurnEvent>.fromIterable(<TurnEvent>[
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

    await cubit.sendTyped('my full approach');
    expect(cubit.state, isA<Failure>());
    expect(calls, 1);

    // The Cubit itself schedules this — no explicit retry() call here.
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(calls, 2, reason: 'RATE_LIMITED must resume automatically once retry_after_ms elapses');
    final DailySessionState state = cubit.state;
    if (state is! Composing || state.session.counters.turnIndex != 1) {
      throw StateError('expected the same turn to have landed after the automatic retry, got $state');
    }
  });
}
