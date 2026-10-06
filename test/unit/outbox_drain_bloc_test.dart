// T132 (US6): the one event-driven Bloc drains strictly one row at a
// time — a queued turn must never race a queued judge for the same
// session (data-model.md §6) — and Principle III's solution-count guard:
// a replayed row can never carry a higher solution count than the
// session's own current truth.
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/dto/judge_dto.dart';
import 'package:dry_run/core/network/dto/turn_dto.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/core/queue/outbox_drain_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_outbox_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  late AppDatabase db;
  late MockRelayClient relayClient;
  late FakeTrustedTimeSource timeSource;
  late FakeOutboxRepository outboxRepository;

  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'vp-0001', messages: const <TurnDto>[]));
    registerFallbackValue(
      JudgeRequestDto(problemId: 'vp-0001', conversation: const <TurnDto>[], endedBy: 'cap'),
    );
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relayClient = MockRelayClient();
    timeSource = FakeTrustedTimeSource();
    outboxRepository = FakeOutboxRepository();

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
            hintCount: 0,
            fetchedAt: timeSource.utc,
          ),
        );
  });

  tearDown(() => db.close());

  OutboxDrainBloc buildBloc() {
    // No real `connectivity_plus` platform channel exists in a test
    // harness — a mock with an empty stream keeps the bloc's own
    // connectivity-triggered drain out of these tests entirely, which
    // only ever fire `DrainRequested` themselves.
    final _MockConnectivity connectivity = _MockConnectivity();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => const Stream<List<ConnectivityResult>>.empty());
    return OutboxDrainBloc(
      outboxRepository: outboxRepository,
      relayClient: relayClient,
      messageDao: db.messageDao,
      sessionDao: db.sessionDao,
      assessmentDao: db.assessmentDao,
      timeSource: timeSource,
      resolveInstallId: () async => 'install-1',
      resolveKeyedHeaders: (SessionRow session) async => (null, null),
      connectivity: connectivity,
    );
  }

  test('a queued turn and a queued judge for the same session never race', () async {
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            problemId: 'vp-0001',
            day: '2026-01-10',
            path: SessionPath.trial,
            status: SessionStatus.chatting,
            startedAt: timeSource.utc,
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'msg1',
            sessionId: 's1',
            seq: 0,
            role: TurnRole.user,
            body: 'my answer',
            kind: MessageKind.turn,
            delivery: Delivery.failedRetryable,
            createdAt: timeSource.utc,
          ),
        );

    final List<String> callOrder = <String>[];
    when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer((_) async* {
      callOrder.add('chat-start');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      callOrder.add('chat-end');
      yield const TokenFrame('ok');
      yield const MetaFrame(<String, Object?>{
        'turn_index': 1,
        'turns_remaining': 3,
        'hints_revealed': 0,
        'hints_remaining': 0,
        'session_ended': null,
        'leak_blocked': false,
      });
    });
    when(() => relayClient.trialJudge(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer((_) async {
      callOrder.add('judge-start');
      return AssessmentDto(
        matchedApproach: 'none',
        matchedVerdict: 'none',
        insightsHit: const <String>[],
        insightsMissed: const <String>[],
        wrongTurnsTaken: const <String>[],
        complexity: ComplexityDto(
          userClaimedTime: null,
          userClaimedSpace: null,
          referenceTime: 'O(n)',
          referenceSpace: 'O(n)',
          assessment: 'not_stated',
        ),
        verdict: 'unclear',
        confidence: 0.5,
        feedback: 'ok',
        editorial: 'ok',
      );
    });

    await outboxRepository.enqueue(
      sessionId: 's1',
      kind: OutboxKind.chatTurn,
      payload: <String, Object?>{
        'user_message_id': 'msg1',
        'request': ChatRequestDto(problemId: 'vp-0001', messages: const <TurnDto>[]).toJson(),
      },
      solutionRequestCountAtEnqueue: 0,
    );
    await outboxRepository.enqueue(
      sessionId: 's1',
      kind: OutboxKind.judge,
      payload: <String, Object?>{
        'request': JudgeRequestDto(problemId: 'vp-0001', conversation: const <TurnDto>[], endedBy: 'cap').toJson(),
      },
      solutionRequestCountAtEnqueue: 0,
    );

    final OutboxDrainBloc bloc = buildBloc();
    addTearDown(bloc.close);
    bloc.add(const DrainRequested());
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(callOrder, <String>['chat-start', 'chat-end', 'judge-start']);
    expect(outboxRepository.enqueued, isEmpty, reason: 'both rows drained successfully');
  });

  test(
    'a replayed row can never carry a higher solution count than the session already holds',
    () async {
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 's2',
              problemId: 'vp-0001',
              day: '2026-01-10',
              path: SessionPath.trial,
              status: SessionStatus.chatting,
              solutionRequestCount: const Value(2),
              startedAt: timeSource.utc,
            ),
          );
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'msg2',
              sessionId: 's2',
              seq: 0,
              role: TurnRole.user,
              body: 'give me the solution',
              kind: MessageKind.turn,
              delivery: Delivery.failedRetryable,
              createdAt: timeSource.utc,
            ),
          );

      ChatRequestDto? captured;
      when(() => relayClient.trialChat(installId: any(named: 'installId'), request: any(named: 'request')))
          .thenAnswer((Invocation invocation) {
        captured = invocation.namedArguments[#request] as ChatRequestDto;
        return Stream<SseFrame>.fromIterable(<SseFrame>[
          const TokenFrame('ok'),
          const MetaFrame(<String, Object?>{
            'turn_index': 3,
            'turns_remaining': 1,
            'hints_revealed': 0,
            'hints_remaining': 0,
            'session_ended': 'solution',
            'leak_blocked': false,
          }),
        ]);
      });

      // This row was built back when the session's own count was still
      // 0 (`solutionRequestCountAtEnqueue: 0`) and asked for 1 — but the
      // session has since genuinely advanced to 2 through some other
      // accepted turn. Replaying the stale ask of "1" would be a regression.
      await outboxRepository.enqueue(
        sessionId: 's2',
        kind: OutboxKind.chatTurn,
        payload: <String, Object?>{
          'user_message_id': 'msg2',
          'request': ChatRequestDto(
            problemId: 'vp-0001',
            messages: const <TurnDto>[],
            solutionRequestCount: 1,
          ).toJson(),
        },
        solutionRequestCountAtEnqueue: 0,
      );

      final OutboxDrainBloc bloc = buildBloc();
      addTearDown(bloc.close);
      bloc.add(const DrainRequested());
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(captured, isNotNull);
      expect(
        captured!.solutionRequestCount,
        2,
        reason: 'clamped to the session\'s current truth, never the stale row value',
      );
    },
  );
}
