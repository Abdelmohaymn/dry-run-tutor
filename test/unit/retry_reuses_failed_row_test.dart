// A successful retry must move the row the learner's words are already
// in, never append a second copy of them.
//
// `retryFailedTurn` (the bubble's own "tap to retry") always passed the
// existing row's id. The `Failure` banner's "Try again" — `retry()` — did
// not, so a retry that succeeded left the original bubble reading
// "Not sent — tap to retry" and painted an identical second bubble
// underneath it. Found on a physical device, 2026-09-06: the dev relay
// returned `UNCLEAR_RETRY`, the retry succeeded, and the conversation
// showed the same spoken turn twice — one of the two still marked failed.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/chat/domain/message.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';

const String _failedRowId = 'row-that-failed';
const String _turnText = 'my full approach to the problem';

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

DailySessionCubit _cubit(FakeSessionRepository sessionRepository) => DailySessionCubit(
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

void main() {
  test('the banner retry reuses the failed row rather than appending a copy', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session()
      ..messages = <Message>[
        const Message(
          id: _failedRowId,
          seq: 1,
          role: TurnRole.user,
          text: _turnText,
          kind: MessageKind.turn,
          delivery: Delivery.failedRetryable,
          inputMode: InputMode.voice,
        ),
      ];

    bool firstAttempt = true;
    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      if (firstAttempt) {
        firstAttempt = false;
        return Stream<TurnEvent>.error(const RelayException(RelayError.unclearRetry()));
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

    final DailySessionCubit cubit = _cubit(sessionRepository);
    addTearDown(cubit.close);
    await cubit.open();

    await cubit.sendTyped(_turnText);
    expect(cubit.state, isA<Failure>(), reason: 'the first attempt must fail');

    await cubit.retry();

    expect(
      sessionRepository.retriedMessageIds,
      <String?>[null, _failedRowId],
      reason: 'the retry must name the row the words are already in',
    );
  });
  test('saving a key resends the pending turn into the row that failed', () async {
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session()
      ..messages = <Message>[
        const Message(
          id: _failedRowId,
          seq: 1,
          role: TurnRole.user,
          text: _turnText,
          kind: MessageKind.turn,
          delivery: Delivery.failedRetryable,
          inputMode: InputMode.text,
        ),
      ];

    bool firstAttempt = true;
    sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
      if (firstAttempt) {
        firstAttempt = false;
        return Stream<TurnEvent>.error(const RelayException(RelayError.trialConsumed()));
      }
      return Stream<TurnEvent>.fromIterable(<TurnEvent>[
        const TurnEvent.meta(
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

    final DailySessionCubit cubit = _cubit(sessionRepository);
    addTearDown(cubit.close);
    await cubit.open();

    await cubit.sendTyped(_turnText);
    expect(cubit.state, isA<Failure>(), reason: 'the trial must be spent');

    await cubit.promoteToKeyed('groq');

    expect(
      sessionRepository.retriedMessageIds,
      <String?>[null, _failedRowId],
      reason: 'the resend after saving a key must name the row the words are already in',
    );
  });
}
