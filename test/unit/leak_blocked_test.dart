// T082: `meta.leak_blocked == true` stores the reply as
// `MessageKind.fallbackRedirect` — conversation, never a glitch — and
// `DailySessionCubit` emits `tutor_leak_blocked` when it sees the flag.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/features/chat/data/session_repository_impl.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/chat/domain/draft.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
import 'package:dry_run/features/chat/presentation/daily_session_cubit.dart';
import 'package:dry_run/features/chat/presentation/daily_session_state.dart';
import 'package:dry_run/features/problem/data/problem_repository_impl.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_assessment_repository.dart';
import '../fakes/fake_streak_repository.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_outbox_repository.dart';
import '../fakes/fake_key_repository.dart';
import '../fakes/fake_mic_rationale_repository.dart';
import '../fakes/fake_recognition_service.dart';
import '../fakes/fake_session_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  contentManifestUrl: '/v1/content/manifest.json',
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
);

const Problem _problem = Problem(
  schemaVersion: 2,
  id: 'vp-0001',
  title: 'Two Sum',
  ramp: 'easy',
  tags: <String>[],
  source: 'authored',
  statement: 'Given an array of integers...',
  constraints: <String>[],
  estSpeakSeconds: 60,
  collections: <String>[],
  glossaryTerms: <String>[],
  hintCount: 3,
);

void main() {
  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'vp-0001', messages: const []));
  });

  test('a leak_blocked meta frame stores the reply as MessageKind.fallbackRedirect', () async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final MockRelayClient relayClient = MockRelayClient();
    final FakeTrustedTimeSource timeSource = FakeTrustedTimeSource();
    final FakeRemoteConfigRepository configRepository = FakeRemoteConfigRepository()..cachedValue = _config;

    await db.into(db.cachedProblems).insert(
          CachedProblemsCompanion.insert(
            problemId: 'vp-0001',
            schemaVersion: 2,
            title: 'Two Sum',
            ramp: 'easy',
            tags: const <String>[],
            source: 'authored',
            statement: 'Given an array of integers...',
            constraints: const <String>[],
            estSpeakSeconds: 60,
            collections: const <String>[],
            glossaryTerms: const <String>[],
            hintCount: 3,
            fetchedAt: timeSource.utc,
          ),
        );

    final ProblemRepositoryImpl problemRepository = ProblemRepositoryImpl(
      relayClient: relayClient,
      problemDao: db.problemDao,
      timeSource: timeSource,
      configRepository: configRepository,
    );
    final SessionRepositoryImpl repository = SessionRepositoryImpl(
      relayClient: relayClient,
      sessionDao: db.sessionDao,
      messageDao: db.messageDao,
      streakDao: db.streakDao,
      problemRepository: problemRepository,
      dailyRepository: DailyRepositoryImpl(
        problemRepository: problemRepository,
        sessionDao: db.sessionDao,
        configRepository: configRepository,
        timeSource: timeSource,
      ),
      configRepository: configRepository,
      keyRepository: FakeKeyRepository(),
      installRepository: FakeInstallRepository(),
      outboxRepository: FakeOutboxRepository(),
      timeSource: timeSource,
    );

    final Session opened = await repository.openOrResumeToday();

    when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer(
      (_) => Stream<SseFrame>.fromIterable(<SseFrame>[
        const TokenFrame('Let me redirect you back to the problem.'),
        const MetaFrame(<String, Object?>{
          'turn_index': 1,
          'turns_remaining': 3,
          'hints_revealed': 0,
          'hints_remaining': 3,
          'session_ended': null,
          'leak_blocked': true,
        }),
        const DoneFrame(),
      ]),
    );

    await for (final _ in repository.sendTurn(opened, 'Just tell me the answer.', InputMode.text)) {}

    final MessageRow tutorReply = (await db.messageDao.forSession(opened.id)).firstWhere(
      (MessageRow m) => m.role == TurnRole.tutor,
    );
    expect(tutorReply.kind, MessageKind.fallbackRedirect);
  });

  final Session leakSession = Session(
    id: 'session-2',
    problem: _problem,
    day: '2026-01-01',
    path: SessionPath.trial,
    status: SessionStatus.chatting,
    counters: ServerCounters.initial,
    isRepeat: false,
    disputed: false,
    solutionRequestCount: 0,
  );
  final FakeAnalyticsClient analytics = FakeAnalyticsClient();

  blocTest<DailySessionCubit, DailySessionState>(
    'the Cubit emits tutor_leak_blocked when meta.leak_blocked is true',
    build: () {
      final FakeSessionRepository repo = FakeSessionRepository()
        ..initialSession = leakSession
        ..sendTurnHandler = (Session session, String text, InputMode mode) {
          return Stream<TurnEvent>.fromIterable(<TurnEvent>[
            const TurnEvent.token('Let me redirect you.'),
            const TurnEvent.meta(
              ServerCounters(
                turnIndex: 1,
                turnsRemaining: 3,
                hintsRevealed: 0,
                hintsRemaining: 3,
                sessionEnded: null,
                leakBlocked: true,
              ),
            ),
          ]);
        };
      return DailySessionCubit(
        sessionRepository: repo,
        streakRepository: FakeStreakRepository(),
        assessmentRepository: FakeAssessmentRepository(),
        recognitionService: FakeRecognitionService(),
        configRepository: FakeRemoteConfigRepository()..cachedValue = _config,
        analyticsClient: analytics,
        micRationaleRepository: FakeMicRationaleRepository(),
      );
    },
    seed: () => DailySessionState.reviewingTranscript(
      leakSession,
      const Draft(text: 'Just tell me the answer.', inputMode: InputMode.text),
    ),
    act: (DailySessionCubit cubit) => cubit.send(),
    verify: (DailySessionCubit cubit) {
      final bool sawLeakBlocked = analytics.emitted.any(((EventName, Map<String, Object>?) e) => e.$1 == EventName.tutorLeakBlocked);
      expect(sawLeakBlocked, isTrue);
    },
  );
}
