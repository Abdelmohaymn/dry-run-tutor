// Cloud voice path of DailySessionCubit (plan T8.3): engine choice, stop and
// upload, the D2 retry loop, the D4 fallback notices, and cleanup.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/cloud_voice/domain/cloud_voice_failure.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/voice/domain/recognition_availability.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_cloud_voice_repository.dart';
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
  statement: 'Given an array of integers, return indices of the two numbers that add up to target.',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>['hashmap'],
  hintCount: 3,
);

// Repair is off so a final transcript opens the review step immediately.
const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

Session _session() => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.keyed,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

const Duration _sixty = Duration(seconds: 60);

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeSessionRepository sessionRepository;
  late FakeRecognitionService recognitionService;
  late FakeCloudVoiceRepository cloud;

  setUp(() {
    sessionRepository = FakeSessionRepository()..initialSession = _session();
    recognitionService = FakeRecognitionService();
    cloud = FakeCloudVoiceRepository()..clipLimitToReturn = _sixty;
  });

  DailySessionCubit buildCubit() => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: recognitionService,
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        micRationaleRepository: FakeMicRationaleRepository(),
        cloudVoiceRepository: cloud,
      );

  DailySessionState composing() => DailySessionState.composing(_session(), null);

  group('engine choice', () {
    blocTest<DailySessionCubit, DailySessionState>(
      'limit null: the on-device recogniser is used and Recording.limit is null',
      build: buildCubit,
      seed: composing,
      setUp: () => cloud.clipLimitToReturn = null,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        recognitionService.emit(const PartialTextEvent('hello'));
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>().having((Recording s) => s.limit, 'limit', isNull),
        isA<Recording>()
            .having((Recording s) => s.limit, 'limit', isNull)
            .having((Recording s) => s.partialText, 'partialText', 'hello'),
      ],
      verify: (_) {
        expect(cloud.recordLimits, isEmpty);
      },
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'limit 60s: Recording.limit is 60s and the platform availability is not consulted',
      build: buildCubit,
      seed: composing,
      // An unavailable platform recogniser must not matter on the cloud path.
      setUp: () => recognitionService.availabilityToReturn = RecognitionAvailability.unsupported,
      act: (DailySessionCubit cubit) => cubit.startRecording(),
      expect: () => <Matcher>[
        isA<Recording>().having((Recording s) => s.limit, 'limit', _sixty),
      ],
      verify: (_) {
        expect(cloud.recordLimits, <Duration>[_sixty]);
        expect(recognitionService.availabilityCalls, 0);
      },
    );
  });

  group('stop and transcript', () {
    blocTest<DailySessionCubit, DailySessionState>(
      'stopRecording emits Recognising, then a FinalTextEvent opens the review with inputMode voice',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emit(const FinalTextEvent('use a hashmap to store seen values'));
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Recognising>(),
        isA<ReviewingTranscript>()
            .having((ReviewingTranscript s) => s.draft.inputMode, 'inputMode', InputMode.voice)
            .having((ReviewingTranscript s) => s.draft.text, 'text', 'use a hashmap to store seen values'),
      ],
      verify: (_) {
        expect(cloud.stopCalls, 1);
      },
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'the stream closing after a final event does not produce the nothing-heard notice',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emit(const FinalTextEvent('use a hashmap to store seen values'));
        await _pump();
        await cloud.closeStream();
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Recognising>(),
        isA<ReviewingTranscript>(),
      ],
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'the stream closing with no terminal event is still the nothing-heard interruption',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cloud.closeStream();
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Composing>().having((Composing s) => s.notice, 'notice', DailySessionCubit.nothingHeardNotice),
      ],
    );
  });

  group('failures', () {
    blocTest<DailySessionCubit, DailySessionState>(
      'rejected emits Composing with the cloudVoiceFailedNotice',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emitFailure(CloudVoiceFailure.rejected);
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Recognising>(),
        isA<Composing>().having((Composing s) => s.notice, 'notice', DailySessionCubit.cloudVoiceFailedNotice),
      ],
    );

    for (final String reason in <String>[CloudVoiceFailure.unavailable, CloudVoiceFailure.exhausted]) {
      blocTest<DailySessionCubit, DailySessionState>(
        '$reason emits Composing with the cloudVoiceFallbackNotice',
        build: buildCubit,
        seed: composing,
        act: (DailySessionCubit cubit) async {
          await cubit.startRecording();
          await cubit.stopRecording();
          cloud.emitFailure(reason);
          await _pump();
        },
        expect: () => <Matcher>[
          isA<Recording>(),
          isA<Recognising>(),
          isA<Composing>()
              .having((Composing s) => s.notice, 'notice', DailySessionCubit.cloudVoiceFallbackNotice),
        ],
      );
    }
  });

  group('retry loop (D2)', () {
    blocTest<DailySessionCubit, DailySessionState>(
      'retryable emits VoiceUploadFailed; retryVoiceUpload emits Recognising then the review',
      build: buildCubit,
      seed: composing,
      setUp: () => cloud.retryResults.add(const FinalTextEvent('use a hashmap to store seen values')),
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emitRetryable();
        await _pump();
        await cubit.retryVoiceUpload();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Recognising>(),
        isA<VoiceUploadFailed>(),
        isA<Recognising>(),
        isA<ReviewingTranscript>()
            .having((ReviewingTranscript s) => s.draft.inputMode, 'inputMode', InputMode.voice),
      ],
      verify: (_) {
        expect(cloud.retryUploadCalls, 1);
      },
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'a second retryable result lands back on VoiceUploadFailed, and a third try can succeed',
      build: buildCubit,
      seed: composing,
      setUp: () => cloud.retryResults.addAll(<RecognitionEvent>[
        const RecognitionErrorEvent(CloudVoiceFailure.retryable, permanent: false),
        const FinalTextEvent('use a hashmap to store seen values'),
      ]),
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emitRetryable();
        await _pump();
        await cubit.retryVoiceUpload();
        await cubit.retryVoiceUpload();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Recognising>(),
        isA<VoiceUploadFailed>(),
        isA<Recognising>(),
        isA<VoiceUploadFailed>(),
        isA<Recognising>(),
        isA<ReviewingTranscript>(),
      ],
      verify: (_) {
        expect(cloud.retryUploadCalls, 2);
      },
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'a retry that comes back non-retryable follows the fallback row',
      build: buildCubit,
      seed: composing,
      setUp: () => cloud.retryResults
          .add(const RecognitionErrorEvent(CloudVoiceFailure.unavailable, permanent: true)),
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emitRetryable();
        await _pump();
        await cubit.retryVoiceUpload();
      },
      skip: 3,
      expect: () => <Matcher>[
        isA<Recognising>(),
        isA<Composing>()
            .having((Composing s) => s.notice, 'notice', DailySessionCubit.cloudVoiceFallbackNotice),
      ],
    );

    blocTest<DailySessionCubit, DailySessionState>(
      'discardVoiceClip calls discardPending and emits Composing with no notice',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.stopRecording();
        cloud.emitRetryable();
        await _pump();
        await cubit.discardVoiceClip();
      },
      skip: 3,
      expect: () => <Matcher>[
        isA<Composing>()
            .having((Composing s) => s.notice, 'notice', isNull)
            .having((Composing s) => s.draft, 'draft', isNull),
      ],
      verify: (_) {
        expect(cloud.discardPendingCalls, 1);
        expect(cloud.hasPendingClip, isFalse);
      },
    );
  });

  group('cleanup and the clip limit', () {
    test('closing the cubit while in VoiceUploadFailed calls the cloud cancel()', () async {
      final DailySessionCubit cubit = buildCubit();
      await cubit.open();
      await cubit.startRecording();
      await cubit.stopRecording();
      cloud.emitRetryable();
      await _pump();
      expect(cubit.state, isA<VoiceUploadFailed>());
      expect(cloud.cancelCalls, 0);

      await cubit.close();

      expect(cloud.cancelCalls, 1);
    });

    int cancelCallsAfterCancel = -1;
    blocTest<DailySessionCubit, DailySessionState>(
      'cancelRecording calls the cloud cancel() and returns to Composing; the closing stream is not "nothing heard"',
      build: buildCubit,
      seed: composing,
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        await cubit.cancelRecording();
        // Read before bloc_test closes the cubit, which cancels again.
        cancelCallsAfterCancel = cloud.cancelCalls;
        await cloud.closeStream();
        await _pump();
      },
      expect: () => <Matcher>[
        isA<Recording>(),
        isA<Composing>().having((Composing s) => s.notice, 'notice', isNull),
      ],
      verify: (_) {
        expect(cancelCallsAfterCancel, 1);
        expect(recognitionService.cancelCalls, 0);
      },
    );

    // The ticker runs on a real Stopwatch, so a short limit is used instead
    // of fakeAsync (which does not move Stopwatch).
    blocTest<DailySessionCubit, DailySessionState>(
      'the ticker reaching the limit calls stop() exactly once',
      build: buildCubit,
      seed: composing,
      setUp: () => cloud.clipLimitToReturn = const Duration(milliseconds: 300),
      act: (DailySessionCubit cubit) async {
        await cubit.startRecording();
        // Several tick periods past the limit: a second stop would show here.
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      },
      expect: () => contains(isA<Recognising>()),
      verify: (DailySessionCubit cubit) {
        expect(cloud.stopCalls, 1);
        expect(cubit.state, isA<Recognising>());
      },
    );
  });
}
