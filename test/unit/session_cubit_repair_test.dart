// quickstart.md §5. The hold window and the late-arrival rule
// (plan.md §The hold window, research.md R-006, FR-015, FR-017).
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_streak_repository.dart';
import '../fakes/fake_transcript_repair_repository.dart';

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

const RuntimeConfig _configRepairEnabled = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
  repair: RepairConfig(enabled: true, minChars: 10, timeoutMs: 1500),
);

/// A short real timeout so a "repair never arrives in time" scenario does
/// not cost the test suite several real seconds — what matters is the
/// ORDER of events around the timeout, not its literal magnitude.
const RuntimeConfig _configRepairShortTimeout = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
  repair: RepairConfig(enabled: true, minChars: 10, timeoutMs: 50),
);

const RuntimeConfig _configRepairDisabled = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

Session _session({SessionPath path = SessionPath.keyed}) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: path,
      status: SessionStatus.chatting,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

void main() {
  late FakeSessionRepository sessionRepository;
  late FakeRecognitionService recognitionService;
  late FakeRemoteConfigRepository configRepository;
  late FakeTranscriptRepairRepository transcriptRepairRepository;

  setUp(() {
    sessionRepository = FakeSessionRepository()..initialSession = _session();
    recognitionService = FakeRecognitionService();
    configRepository = FakeRemoteConfigRepository()..cachedValue = _configRepairEnabled;
    transcriptRepairRepository = FakeTranscriptRepairRepository();
  });

  DailySessionCubit buildCubit() => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: recognitionService,
        configRepository: configRepository,
        analyticsClient: FakeAnalyticsClient(),
        micRationaleRepository: FakeMicRationaleRepository(),
        transcriptRepairRepository: transcriptRepairRepository,
      );

  blocTest<DailySessionCubit, DailySessionState>(
    'repair returns in 200ms with a 1500ms timeout: Recording -> Recognising -> ReviewingTranscript(repaired)',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hash mop to store seen values'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      transcriptRepairRepository.pendingCompleters.single.complete(
        'I would use a hash map to store seen values',
      );
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<Recording>(),
      isA<Recognising>(),
      isA<ReviewingTranscript>()
          .having((ReviewingTranscript s) => s.draft.text, 'draft.text',
              'I would use a hash map to store seen values')
          .having((ReviewingTranscript s) => s.draft.recognised, 'draft.recognised',
              'I would use a hash mop to store seen values')
          .having((ReviewingTranscript s) => s.draft.repaired, 'draft.repaired',
              'I would use a hash map to store seen values'),
    ],
  );

  // US2 scenarios 1 and 2: revert restores exactly what was heard, and a
  // subsequent send sends that raw text, not the repaired one.
  final Session repairedReviewSession = _session();
  const Draft repairedDraft = Draft(
    text: 'I would use a hash map to store seen values',
    recognised: 'I would use a hash mop to store seen values',
    repaired: 'I would use a hash map to store seen values',
    inputMode: InputMode.voice,
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'revertRepair() restores draft.text to draft.recognised byte for byte',
    build: buildCubit,
    seed: () => DailySessionState.reviewingTranscript(repairedReviewSession, repairedDraft),
    act: (DailySessionCubit cubit) => cubit.revertRepair(),
    expect: () => <Matcher>[
      isA<ReviewingTranscript>().having(
        (ReviewingTranscript s) => s.draft.text,
        'draft.text',
        'I would use a hash mop to store seen values',
      ),
    ],
    verify: (DailySessionCubit cubit) {
      final ReviewingTranscript reverted = cubit.state as ReviewingTranscript;
      expect(reverted.draft.text, reverted.draft.recognised);
    },
  );

  String? sentText;
  blocTest<DailySessionCubit, DailySessionState>(
    'after a revert, send() sends the raw (recognised) text, not the repaired one',
    build: buildCubit,
    seed: () => DailySessionState.reviewingTranscript(
      repairedReviewSession,
      repairedDraft.copyWith(text: repairedDraft.recognised),
    ),
    act: (DailySessionCubit cubit) async {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        sentText = text;
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          const TurnEvent.token('ok'),
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
      await cubit.send();
    },
    verify: (DailySessionCubit cubit) {
      expect(sentText, 'I would use a hash mop to store seen values');
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'repair times out: review opens with the raw text, then a late-arriving repair is applied because the draft is untouched',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      configRepository.cachedValue = _configRepairShortTimeout;
      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hash mop to store seen values'));
      await Future<void>.delayed(Duration.zero);
      // Past the 50ms timeout, but the completer is never completed here —
      // the "repair takes 3s" scenario, simulated without waiting 3s.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      transcriptRepairRepository.pendingCompleters.single.complete(
        'I would use a hash map to store seen values',
      );
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<Recording>(),
      isA<Recognising>(),
      isA<ReviewingTranscript>()
          .having((ReviewingTranscript s) => s.draft.text, 'draft.text',
              'I would use a hash mop to store seen values')
          .having((ReviewingTranscript s) => s.draft.repaired, 'draft.repaired', isNull),
      isA<ReviewingTranscript>()
          .having((ReviewingTranscript s) => s.draft.text, 'draft.text',
              'I would use a hash map to store seen values')
          .having((ReviewingTranscript s) => s.draft.repaired, 'draft.repaired',
              'I would use a hash map to store seen values'),
    ],
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'repair times out and the learner typed before it arrived: the late result is dropped, draft.text stays the learner\'s own',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      configRepository.cachedValue = _configRepairShortTimeout;
      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hash mop to store seen values'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The learner edits the raw draft before the late repair lands.
      cubit.updateDraftText('actually I would sort the list first');
      transcriptRepairRepository.pendingCompleters.single.complete(
        'I would use a hash map to store seen values',
      );
      await Future<void>.delayed(Duration.zero);
    },
    verify: (DailySessionCubit cubit) {
      final ReviewingTranscript current = cubit.state as ReviewingTranscript;
      expect(current.draft.text, 'actually I would sort the list first');
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'repair times out and the learner re-recorded before it arrived: the late result is dropped',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      configRepository.cachedValue = _configRepairShortTimeout;
      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hash mop to store seen values'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      // The learner abandons the transcript and starts over.
      await cubit.reRecord();
      transcriptRepairRepository.pendingCompleters.single.complete(
        'I would use a hash map to store seen values',
      );
      await Future<void>.delayed(Duration.zero);
    },
    verify: (DailySessionCubit cubit) {
      // Still Recording — the late repair found no ReviewingTranscript to
      // land on and was dropped, silently.
      expect(cubit.state, isA<Recording>());
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'repair.enabled == false: Recording -> ReviewingTranscript(raw) with no Recognising hold at all',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      configRepository.cachedValue = _configRepairDisabled;
      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hash mop to store seen values'));
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Matcher>[
      isA<Recording>(),
      isA<ReviewingTranscript>().having((ReviewingTranscript s) => s.draft.text, 'draft.text',
          'I would use a hash mop to store seen values'),
    ],
    verify: (DailySessionCubit cubit) {
      expect(transcriptRepairRepository.callCount, 0);
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'a typed draft never calls TranscriptRepairRepository.repair()',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) => cubit.sendTyped('I would use a hash map'),
    verify: (DailySessionCubit cubit) {
      expect(transcriptRepairRepository.callCount, 0);
    },
  );
}
