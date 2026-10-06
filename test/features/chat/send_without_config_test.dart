// Regression, found on hardware 2026-09-16: tapping Send did nothing at all
// — no request, no error, no state change. `_config` was
// `_configRepository.cached()!`, and the launch path can legitimately reach
// a session with that cache empty (`main()` only refreshes over the network
// when the Drift hydrate returned something), so the `!` threw inside the
// tap handler and the button looked dead.
//
// Constitution X.6's "never deny content" is the rule this broke: a config
// the app could not read must never be able to stop a learner sending a
// turn.
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fakes/fake_assessment_repository.dart';
import '../../fakes/fake_config_repository.dart';
import '../../fakes/fake_mic_rationale_repository.dart';
import '../../fakes/fake_recognition_service.dart';
import '../../fakes/fake_session_repository.dart';
import '../../fakes/fake_streak_repository.dart';

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Pair Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given a list of integers and a target, find the pair that sums to it.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

Session get _session => const Session(
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
  test('Send reaches the relay when the config cache is empty, instead of throwing', () async {
    final List<String> sentTexts = <String>[];
    final FakeSessionRepository sessionRepository = FakeSessionRepository()
      ..initialSession = _session
      ..sendTurnHandler = (Session session, String text, InputMode mode) {
        sentTexts.add(text);
        return const Stream<TurnEvent>.empty();
      };

    final DailySessionCubit cubit = DailySessionCubit(
      sessionRepository: sessionRepository,
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: FakeRecognitionService(),
      // The whole point: nothing cached, and `load()` throws for this fake.
      configRepository: FakeRemoteConfigRepository(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );
    addTearDown(cubit.close);

    cubit.emit(
      DailySessionState.reviewingTranscript(
        _session,
        const Draft(text: 'before', inputMode: InputMode.text),
      ),
    );

    await cubit.send();

    expect(sentTexts, <String>['before'], reason: 'the turn must reach the relay, config or no config');
    expect(cubit.state, isNot(isA<ReviewingTranscript>()), reason: 'the tap must move the machine on');
  });
}
