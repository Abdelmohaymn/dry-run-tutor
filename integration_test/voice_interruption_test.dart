// SC-005: an incoming call mid-recording, another app taking the mic,
// backgrounding mid-recording, a permission revoked mid-session, and an
// empty recognition result must all leave **zero recordings and zero
// composed turns lost**. There is no audio to lose (Constitution VII) —
// what this asserts is that every interruption path returns the learner
// to a composer they can act from again, never a stuck state and never a
// silently-accepted empty turn.
//
// `speech_to_text` itself, and the OS events that interrupt it (a real
// phone call, another app's mic request, backgrounding), are not
// scriptable from Dart — `RecognitionService` is substituted with a
// scriptable fake so each interruption is deterministic here. The claim
// this protects — that nothing is lost — is exercised for real only on a
// physical device driving an actual call/background/permission-revoke,
// per quickstart.md; this suite is what makes the *app's* handling of
// each interruption reproducible in CI between those manual passes.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/fakes/fake_analytics_client.dart';
import '../test/fakes/fake_assessment_repository.dart';
import '../test/fakes/fake_streak_repository.dart';
import '../test/fakes/fake_config_repository.dart';
import '../test/fakes/fake_mic_rationale_repository.dart';
import '../test/fakes/fake_recognition_service.dart';
import '../test/fakes/fake_session_repository.dart';

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
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  DailySessionCubit buildCubit(FakeRecognitionService recognitionService) {
    final FakeRemoteConfigRepository configRepository = FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        contentManifestUrl: '/v1/content/manifest.json',
        chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      );
    return DailySessionCubit(
      sessionRepository: FakeSessionRepository()..initialSession = _session(),
      streakRepository: FakeStreakRepository(),
      assessmentRepository: FakeAssessmentRepository(),
      recognitionService: recognitionService,
      configRepository: configRepository,
      analyticsClient: FakeAnalyticsClient(),
      micRationaleRepository: FakeMicRationaleRepository(),
    );
  }

  // Every scenario below drives the same assertion: after the
  // interruption, the Cubit is back in `Composing` with no draft — the
  // recording never became a turn, and nothing is stuck.
  Future<void> expectRecoversToComposing(DailySessionCubit cubit) async {
    await Future<void>.delayed(Duration.zero);
    final DailySessionState state = cubit.state;
    if (state is! Composing) {
      throw StateError('expected Composing after the interruption, got $state');
    }
    if (state.draft != null) {
      throw StateError('expected no draft after an interrupted recording, got ${state.draft}');
    }
  }

  group('voice interruption recovery (SC-005)', () {
    test('a stream closing with no final result (a call, or another app taking the mic)', () async {
      final FakeRecognitionService recognitionService = FakeRecognitionService();
      final DailySessionCubit cubit = buildCubit(recognitionService);
      addTearDown(cubit.close);
      addTearDown(recognitionService.dispose);

      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.startRecording();
      await recognitionService.dispose(); // closes with no FinalTextEvent
      await expectRecoversToComposing(cubit);
    });

    test('backgrounding mid-recording with no final result', () async {
      final FakeRecognitionService recognitionService = FakeRecognitionService();
      final DailySessionCubit cubit = buildCubit(recognitionService);
      addTearDown(cubit.close);

      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.startRecording();
      recognitionService.emit(const RecognitionErrorEvent('backgrounded', permanent: true));
      await expectRecoversToComposing(cubit);
    });

    test('permission revoked mid-session (a permanent recognition error)', () async {
      final FakeRecognitionService recognitionService = FakeRecognitionService();
      final DailySessionCubit cubit = buildCubit(recognitionService);
      addTearDown(cubit.close);

      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.startRecording();
      recognitionService.emit(const RecognitionErrorEvent('permission_denied', permanent: true));
      await expectRecoversToComposing(cubit);
    });

    test('an empty recognition result consumes nothing and composes nothing', () async {
      final FakeRecognitionService recognitionService = FakeRecognitionService();
      final DailySessionCubit cubit = buildCubit(recognitionService);
      addTearDown(cubit.close);

      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('   '));
      await expectRecoversToComposing(cubit);
    });

    test('a transient recognition error does not interrupt the session', () async {
      final FakeRecognitionService recognitionService = FakeRecognitionService();
      final DailySessionCubit cubit = buildCubit(recognitionService);
      addTearDown(cubit.close);

      // `DailySessionCubit` refuses every action until `open()` has
      // resolved — it throws rather than guess at a session.
      await cubit.open();

      await cubit.startRecording();
      recognitionService.emit(const RecognitionErrorEvent('no_speech_detected', permanent: false));
      await Future<void>.delayed(Duration.zero);
      if (cubit.state is! Recording) {
        throw StateError('a transient error must not end the listen session, got ${cubit.state}');
      }
    });
  });
}
