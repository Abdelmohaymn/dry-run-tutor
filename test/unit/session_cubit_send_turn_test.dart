// Principle V / FR-012: no path reaches `Sending` without passing through
// `ReviewingTranscript`. T056 asserts the exact state sequence a spoken
// turn drives: Composing → Recording → Recognising → ReviewingTranscript
// → Sending → Streaming → Composing.
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
import 'package:dry_run/features/voice/domain/recognition_event.dart';
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
  glossaryTerms: <String>['hashmap'],
  hintCount: 3,
);

Session _session({ServerCounters counters = ServerCounters.initial}) => Session(
      id: 'session-1',
      problem: _problem,
      day: '2026-01-01',
      path: SessionPath.trial,
      status: SessionStatus.chatting,
      counters: counters,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );

void main() {
  late FakeSessionRepository sessionRepository;
  late FakeRecognitionService recognitionService;
  late FakeRemoteConfigRepository configRepository;
  late FakeAnalyticsClient analyticsClient;
  late FakeMicRationaleRepository micRationaleRepository;

  setUp(() {
    sessionRepository = FakeSessionRepository()..initialSession = _session();
    recognitionService = FakeRecognitionService();
    configRepository = FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        contentManifestUrl: '/v1/content/manifest.json',
        chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      );
    analyticsClient = FakeAnalyticsClient();
    micRationaleRepository = FakeMicRationaleRepository();
  });

  DailySessionCubit buildCubit() => DailySessionCubit(
        sessionRepository: sessionRepository,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: recognitionService,
        configRepository: configRepository,
        analyticsClient: analyticsClient,
        micRationaleRepository: micRationaleRepository,
      );

  // Feature 004: repair is structurally unavailable on the trial path
  // (research.md R-009), so a trial-path spoken turn no longer holds on
  // `Recognising` at all — plan.md §The hold window's "if trial path ...
  // open review with raw. Done." skips that state entirely (SC-004).
  blocTest<DailySessionCubit, DailySessionState>(
    'a spoken turn drives Composing → Recording → ReviewingTranscript → Sending → Streaming → Composing',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        return Stream<TurnEvent>.fromIterable(<TurnEvent>[
          const TurnEvent.token('Tell me about your approach.'),
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

      await cubit.startRecording();
      recognitionService.emit(const FinalTextEvent('I would use a hashmap to track seen values.'));
      await Future<void>.delayed(Duration.zero);
      await cubit.send();
    },
    expect: () => <Matcher>[
      isA<Recording>(),
      isA<ReviewingTranscript>().having(
        (ReviewingTranscript s) => s.draft.text,
        'draft.text',
        'I would use a hashmap to track seen values.',
      ),
      isA<Sending>(),
      isA<Streaming>().having((Streaming s) => s.partialText, 'partialText', 'Tell me about your approach.'),
      isA<Composing>().having((Composing s) => s.session.counters.turnIndex, 'turnIndex', 1),
    ],
    verify: (DailySessionCubit cubit) {
      final (EventName, Map<String, Object>?)? turnSent = analyticsClient.emitted
          .cast<(EventName, Map<String, Object>?)?>()
          .firstWhere((event) => event!.$1 == EventName.chatTurnSent, orElse: () => null);
      expect(turnSent, isNotNull, reason: 'chat_turn_sent must be emitted on a successful send (T081)');
      expect(turnSent!.$2?['input_mode'], 'voice');
      expect(turnSent.$2?['turn_index'], 1);
      expect(turnSent.$2?['path'], 'trial');
    },
  );

  blocTest<DailySessionCubit, DailySessionState>(
    'send() from a state that is not ReviewingTranscript is a no-op — no path reaches Sending without it',
    build: buildCubit,
    seed: () => DailySessionState.composing(_session(), null),
    act: (DailySessionCubit cubit) async {
      sessionRepository.sendTurnHandler = (Session session, String text, InputMode mode) {
        fail('sendTurn must never be called without passing through ReviewingTranscript');
      };
      await cubit.send();
    },
    expect: () => <DailySessionState>[],
  );
}
