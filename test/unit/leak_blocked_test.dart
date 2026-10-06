// T082: `meta.leak_blocked == true` stores the reply as
// `MessageKind.fallbackRedirect` — conversation, never a glitch.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/features/chat/data/session_repository_impl.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/problem/data/problem_repository_impl.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_outbox_repository.dart';
import '../fakes/fake_key_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

const RuntimeConfig _config = RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: <String>[],
  chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
  trial: TrialConfig(turnCap: 4),
  keyedProviders: <String>['groq'],
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
            // As if `/v1/daily` had already served it for today.
            manifestDate: Value(await timeSource.today()),
            fetchedAt: timeSource.utc,
          ),
        );

    final ProblemRepositoryImpl problemRepository = ProblemRepositoryImpl(
      relayClient: relayClient,
      problemDao: db.problemDao,
      timeSource: timeSource,
      installRepository: FakeInstallRepository(),
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
}
