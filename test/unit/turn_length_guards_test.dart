// T078: below `min_turn_chars` the app declines locally with EMPTY_TURN's
// own copy and consumes no turn (US1 scenario 7); over `Turn.text`'s
// 8000-character ceiling the app trims at a sentence boundary and shows
// the trimmed text back for a fresh confirm, rather than sending it to be
// refused as BAD_REQUEST.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
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

DailySessionCubit _buildCubit(FakeSessionRepository sessionRepository, {int minTurnChars = 8}) => DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: const <String>[],
          chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: minTurnChars),
          trial: const TrialConfig(turnCap: 4),
          keyedProviders: const <String>['groq'],
        ),
      micRationaleRepository: FakeMicRationaleRepository(),
    );

void main() {
  blocTest<DailySessionCubit, DailySessionState>(
    'a turn below min_turn_chars is declined locally with EmptyTurn and consumes no turn',
    build: () {
      final FakeSessionRepository repo = FakeSessionRepository()..initialSession = _session();
      repo.sendTurnHandler = (Session s, String t, InputMode m) {
        fail('sendTurn must never be called for a turn below min_turn_chars');
      };
      return _buildCubit(repo);
    },
    seed: () => DailySessionState.reviewingTranscript(
      _session(),
      const Draft(text: 'ok', inputMode: InputMode.text),
    ),
    act: (DailySessionCubit cubit) => cubit.send(),
    expect: () => <Matcher>[
      isA<Failure>().having((Failure s) => s.error, 'error', const RelayError.emptyTurn()),
    ],
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'a turn over the 8000-character ceiling is trimmed at a sentence boundary and shown back, not sent',
    build: () {
      final FakeSessionRepository repo = FakeSessionRepository()..initialSession = _session();
      repo.sendTurnHandler = (Session s, String t, InputMode m) {
        fail('an over-length turn must be trimmed and re-shown, not sent');
      };
      return _buildCubit(repo);
    },
    seed: () {
      final String longSentence = '${'a' * 7995}. This part must be cut.';
      return DailySessionState.reviewingTranscript(
        _session(),
        Draft(text: longSentence, inputMode: InputMode.text),
      );
    },
    act: (DailySessionCubit cubit) => cubit.send(),
    expect: () => <Matcher>[
      isA<ReviewingTranscript>().having(
        (ReviewingTranscript s) => s.draft.text.length,
        'trimmed length',
        lessThanOrEqualTo(8000),
      ),
    ],
  );

  // Found on device, 2026-10-02: a typed "hi" came back as "Nothing was
  // heard". With the floor at one character, a short answer like "hi",
  // "ok" or "1" reaches the relay.
  test('with min_turn_chars at 1, a one-word turn is sent', () async {
    final List<String> sent = <String>[];
    final FakeSessionRepository repo = FakeSessionRepository()..initialSession = _session();
    repo.sendTurnHandler = (Session s, String t, InputMode m) {
      sent.add(t);
      return const Stream<TurnEvent>.empty();
    };
    final DailySessionCubit cubit = _buildCubit(repo, minTurnChars: 1);
    cubit.emit(
      DailySessionState.reviewingTranscript(_session(), const Draft(text: 'hi', inputMode: InputMode.text)),
    );
    await cubit.send();
    expect(sent, <String>['hi']);
    await cubit.close();
  });
}
