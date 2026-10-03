// A summary covers only the turns the relay folded into it: the first
// `summary_covers` of the request's `messages`. The app used to mark every
// replayed turn covered, so the turns the relay had kept verbatim were
// never sent again. And the next request took its summary from the
// Cubit's copy of the session, which never received it. Found on device
// 2026-09-25: the learner's full answer vanished and "before" went out
// with no context. `session` below is deliberately never refreshed, as in
// the Cubit.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/features/chat/data/session_repository_impl.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/daily/data/daily_repository_impl.dart';
import 'package:dry_run/features/problem/data/problem_repository_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_key_repository.dart';
import '../fakes/fake_outbox_repository.dart';
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


Map<String, Object?> _meta(int turn, {String? summary, int? covers}) => <String, Object?>{
      'turn_index': turn,
      'turns_remaining': 12 - turn,
      'hints_revealed': 0,
      'hints_remaining': 3,
      'session_ended': null,
      'leak_blocked': false,
      'summary': ?summary,
      'summary_covers': ?covers,
    };

class _Harness {
  _Harness(this.db, this.repository, this.relayClient);

  final AppDatabase db;
  final SessionRepositoryImpl repository;
  final MockRelayClient relayClient;

  /// Every request sent, in order.
  final List<ChatRequestDto> sent = <ChatRequestDto>[];

  /// What the next call answers: a meta frame, or an error to throw.
  final List<Object> replies = <Object>[];

  static Future<_Harness> create() async {
    final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
    final MockRelayClient relayClient = MockRelayClient();
    final FakeTrustedTimeSource timeSource = FakeTrustedTimeSource();
    final FakeRemoteConfigRepository configRepository = FakeRemoteConfigRepository()..cachedValue = _config;
    await db.into(db.cachedProblems).insert(
          CachedProblemsCompanion.insert(
            problemId: 'vp-0001',
            schemaVersion: 2,
            title: 'Pair Sum',
            ramp: 'easy',
            tags: const <String>[],
            source: 'authored',
            statement: 'Return the two positions that add up to the target.',
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
    final _Harness h = _Harness(db, repository, relayClient);
    when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer((Invocation invocation) {
      h.sent.add(invocation.namedArguments[#request] as ChatRequestDto);
      final Object reply = h.replies.removeAt(0);
      if (reply is RelayException) return Stream<SseFrame>.error(reply);
      return Stream<SseFrame>.fromIterable(<SseFrame>[
        TokenFrame('reply ${h.sent.length}'),
        MetaFrame(reply as Map<String, Object?>),
        const DoneFrame(),
      ]);
    });
    return h;
  }

  Future<void> send(Session session, String text) async {
    try {
      await for (final _ in repository.sendTurn(session, text, InputMode.text)) {}
    } on RelayException {
      // The failed row stays in the conversation as `failedRetryable`.
    }
  }

  List<String> lastSentTexts() => sent.last.messages.map((m) => m.text).toList();
}

void main() {
  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'vp-0001', messages: const []));
  });

  test('only the first summary_covers replayed turns are dropped; the rest are sent again', () async {
    final _Harness h = await _Harness.create();
    addTearDown(h.db.close);
    final Session session = await h.repository.openOrResumeToday();

    for (int turn = 1; turn <= 3; turn++) {
      h.replies.add(_meta(turn));
      await h.send(session, 'learner $turn');
    }
    // Turn 4 replays 7 turns; the relay folds the first 2 into a summary.
    h.replies.add(_meta(4, summary: 'they started with a plan', covers: 2));
    await h.send(session, 'learner 4');
    expect(h.lastSentTexts(), hasLength(7));
    expect(h.sent.last.earlierLearnerTurns, isNull, reason: 'nothing is covered yet');

    h.replies.add(_meta(5));
    await h.send(session, 'learner 5');
    expect(h.sent.last.summary, 'they started with a plan');
    expect(
      h.sent.last.earlierLearnerTurns,
      <String>['learner 1'],
      reason: 'the learner turn inside the summary is still sent for the word filter',
    );
    expect(h.lastSentTexts(), <String>[
      'learner 2',
      'reply 2',
      'learner 3',
      'reply 3',
      'learner 4',
      'reply 4',
      'learner 5',
    ]);
  });

  test('a summary without summary_covers (an older relay) marks nothing covered', () async {
    final _Harness h = await _Harness.create();
    addTearDown(h.db.close);
    final Session session = await h.repository.openOrResumeToday();

    h.replies.add(_meta(1, summary: 'a summary from an older relay'));
    await h.send(session, 'learner 1');
    h.replies.add(_meta(2));
    await h.send(session, 'learner 2');

    expect(h.lastSentTexts(), <String>['learner 1', 'reply 1', 'learner 2']);
  });

  test('a turn that failed and was not retried is not sent to the tutor', () async {
    final _Harness h = await _Harness.create();
    addTearDown(h.db.close);
    final Session session = await h.repository.openOrResumeToday();

    h.replies.add(const RelayException(RelayError.trialConsumed()));
    await h.send(session, 'the failed one');
    h.replies.add(_meta(1));
    await h.send(session, 'the next one');

    expect(h.lastSentTexts(), <String>['the next one']);
  });
}
