// FR-019, research.md R-007: counters come only from the `meta` frame,
// never from local arithmetic. The case that breaks any client that
// counts locally — a hint pull advances `hintsRevealed` while leaving
// `turnIndex` unchanged — is asserted directly against
// `SessionRepositoryImpl`, the one writer of `ServerCounters`.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/features/chat/data/session_repository_impl.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/chat/domain/hint_rung.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/chat/domain/turn_event.dart';
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

void main() {
  late AppDatabase db;
  late MockRelayClient relayClient;
  late SessionRepositoryImpl repository;
  late FakeTrustedTimeSource timeSource;
  late FakeRemoteConfigRepository configRepository;

  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'vp-0001', messages: const []));
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relayClient = MockRelayClient();
    timeSource = FakeTrustedTimeSource();
    configRepository = FakeRemoteConfigRepository()
      ..cachedValue = const RuntimeConfig(
        minSupportedVersion: '1.0.0',
        killedProblemIds: <String>[],
        chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 8),
        trial: TrialConfig(turnCap: 4),
        keyedProviders: <String>['groq'],
      );

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
            glossaryTerms: const <String>['hashmap'],
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
    repository = SessionRepositoryImpl(
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
  });

  tearDown(() => db.close());

  test('a hint pull leaves turnIndex unchanged while advancing hintsRevealed', () async {
    final Session opened = await repository.openOrResumeToday();

    // First turn: turnIndex 0 -> 1.
    when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer(
      (_) => Stream<SseFrame>.fromIterable(<SseFrame>[
        const TokenFrame('Tell me about your approach.'),
        const MetaFrame(<String, Object?>{
          'turn_index': 1,
          'turns_remaining': 9,
          'hints_revealed': 0,
          'hints_remaining': 3,
          'session_ended': null,
          'leak_blocked': false,
        }),
        const DoneFrame(),
      ]),
    );

    ServerCountersSnapshot? afterTurn;
    await for (final TurnEvent event in repository.sendTurn(opened, 'I would use a hashmap.', InputMode.voice)) {
      if (event is TurnEventMeta) {
        afterTurn = ServerCountersSnapshot(event.counters.turnIndex, event.counters.hintsRevealed);
      }
    }
    expect(afterTurn, isNotNull);
    expect(afterTurn!.turnIndex, 1);
    expect(afterTurn.hintsRevealed, 0);

    // A hint pull: turnIndex must stay at 1; hintsRevealed advances.
    when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer(
      (_) => Stream<SseFrame>.fromIterable(<SseFrame>[
        const TokenFrame('Rung 1: think about what you need to look up quickly.'),
        const MetaFrame(<String, Object?>{
          'turn_index': 1,
          'turns_remaining': 9,
          'hints_revealed': 1,
          'hints_remaining': 2,
          'session_ended': null,
          'leak_blocked': false,
        }),
        const DoneFrame(),
      ]),
    );

    final Result<HintRung> hintResult = await repository.pullHint(opened);
    expect(hintResult, isA<Ok<HintRung>>());
    final HintRung rung = (hintResult as Ok<HintRung>).value;
    expect(rung.index, 1);

    final Session resumed = await repository.openOrResumeToday();
    expect(resumed.counters.turnIndex, 1, reason: 'a hint pull must never move turnIndex');
    expect(resumed.counters.hintsRevealed, 1, reason: 'a hint pull must advance hintsRevealed');
  });
}

class ServerCountersSnapshot {
  const ServerCountersSnapshot(this.turnIndex, this.hintsRevealed);
  final int turnIndex;
  final int hintsRevealed;
}
