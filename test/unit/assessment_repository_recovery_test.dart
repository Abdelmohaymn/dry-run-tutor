// Recovery of a judged-on-the-server-but-lost-on-the-phone assessment
// (PLAN_02, AC3-AC7): the relay keeps no assessment, so the repository
// resets the claim and judges the local conversation again, and whatever
// fails along the way is surfaced as itself, never as the original
// SESSION_ALREADY_JUDGED.
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/core/network/dto/judge_dto.dart';
import 'package:dry_run/core/network/dto/turn_dto.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/assessment/data/assessment_repository_impl.dart';
import 'package:dry_run/features/assessment/domain/assessment.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_key_repository.dart';
import '../fakes/fake_outbox_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

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
  hintCount: 0,
);

const RelayException _alreadyJudged =
    RelayException(RelayError.sessionAlreadyJudged(ctx: JudgedContext.repeatJudge));

AssessmentDto _dto() => AssessmentDto(
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
      verdict: 'pass',
      confidence: 0.8,
      feedback: 'recovered',
      editorial: 'ed',
    );

void main() {
  late AppDatabase db;
  late MockRelayClient relay;
  late FakeOutboxRepository outbox;
  late AssessmentRepositoryImpl repo;

  setUpAll(() {
    registerFallbackValue(
      JudgeRequestDto(problemId: 'vp-0001', conversation: const <TurnDto>[], endedBy: 'cap'),
    );
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relay = MockRelayClient();
    outbox = FakeOutboxRepository();
    final FakeTrustedTimeSource time = FakeTrustedTimeSource();

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
            fetchedAt: time.utc,
          ),
        );

    repo = AssessmentRepositoryImpl(
      relayClient: relay,
      assessmentDao: db.assessmentDao,
      sessionDao: db.sessionDao,
      messageDao: db.messageDao,
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          chat: ChatConfig(turnCap: 4, wrapUpAtTurn: 3, minTurnChars: 5),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
      keyRepository: FakeKeyRepository(),
      installRepository: FakeInstallRepository(),
      timeSource: time,
      outboxRepository: outbox,
    );

    when(() => relay.recoverJudge(installId: any(named: 'installId'), problemId: any(named: 'problemId')))
        .thenAnswer((_) async {});
  });

  tearDown(() => db.close());

  /// Seeds a `pendingJudge` session with one turn, as `endSessionUser()` leaves it.
  Future<Session> seed(SessionPath path) async {
    final FakeTrustedTimeSource time = FakeTrustedTimeSource();
    await db.into(db.sessions).insert(
          SessionsCompanion.insert(
            id: 's1',
            problemId: 'vp-0001',
            day: '2026-01-10',
            path: path,
            status: SessionStatus.pendingJudge,
            startedAt: time.utc,
          ),
        );
    await db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: 'm1',
            sessionId: 's1',
            seq: 0,
            role: TurnRole.user,
            body: 'my answer',
            kind: MessageKind.turn,
            delivery: Delivery.sent,
            createdAt: time.utc,
          ),
        );
    return Session(
      id: 's1',
      problem: _problem,
      day: '2026-01-10',
      path: path,
      status: SessionStatus.pendingJudge,
      counters: ServerCounters.initial,
      isRepeat: false,
      disputed: false,
      solutionRequestCount: 0,
    );
  }

  void keyedJudge(Object Function() answer) {
    when(() => relay.judge(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        )).thenAnswer((_) async {
      final Object r = answer();
      if (r is Exception) {
        throw r;
      }
      return r as AssessmentDto;
    });
  }

  Future<SessionRow?> sessionRow() => db.sessionDao.byId('s1');

  test('AC3: already judged with a cached assessment returns it without a reset', () async {
    final Session session = await seed(SessionPath.keyed);
    // Cache one via a first successful request, then repeat.
    keyedJudge(() => _dto());
    expect(await repo.request(session), isA<Ok<Assessment>>());
    keyedJudge(() => _alreadyJudged);

    final Result<Assessment> result = await repo.request(session);

    expect(result, isA<Ok<Assessment>>());
    expect((result as Ok<Assessment>).value.feedback, 'recovered');
    verifyNever(() => relay.recoverJudge(
          installId: any(named: 'installId'),
          problemId: any(named: 'problemId'),
        ));
  });

  test('AC4: already judged and nothing cached resets then re-judges', () async {
    final Session session = await seed(SessionPath.keyed);
    int calls = 0;
    keyedJudge(() => calls++ == 0 ? _alreadyJudged : _dto());

    final Result<Assessment> result = await repo.request(session);

    expect(result, isA<Ok<Assessment>>());
    expect(await db.assessmentDao.forSession('s1'), isNotNull);
    expect((await sessionRow())!.status, SessionStatus.complete);
    expect(calls, 2);
    verify(() => relay.recoverJudge(installId: any(named: 'installId'), problemId: 'vp-0001')).called(1);
  });

  test('AC5: a failing reset surfaces its own error and queues nothing', () async {
    final Session session = await seed(SessionPath.keyed);
    keyedJudge(() => _alreadyJudged);
    when(() => relay.recoverJudge(installId: any(named: 'installId'), problemId: any(named: 'problemId')))
        .thenThrow(const RelayException(RelayError.transport()));

    final Result<Assessment> result = await repo.request(session);

    expect(result, isA<Err<Assessment>>());
    expect((result as Err<Assessment>).error, isA<TransportFailure>());
    expect(outbox.enqueued, isEmpty);
    expect(await db.assessmentDao.forSession('s1'), isNull);
    expect((await sessionRow())!.status, SessionStatus.pendingJudge);
  });

  test('AC6: a failing re-judge surfaces its own error', () async {
    final Session session = await seed(SessionPath.keyed);
    int calls = 0;
    keyedJudge(
      () => calls++ == 0
          ? _alreadyJudged
          : const RelayException(RelayError.rateLimited(retryAfter: Duration(seconds: 5))),
    );

    final Result<Assessment> result = await repo.request(session);

    expect((result as Err<Assessment>).error, isA<RateLimited>());
    expect(outbox.enqueued, isEmpty);
    expect(await db.assessmentDao.forSession('s1'), isNull);
  });

  test('AC7: a second already-judged after the reset is UnclearRetry, never SessionAlreadyJudged',
      () async {
    final Session session = await seed(SessionPath.keyed);
    keyedJudge(() => _alreadyJudged);

    final Result<Assessment> result = await repo.request(session);

    final RelayError error = (result as Err<Assessment>).error;
    expect(error, isA<UnclearRetry>());
    expect(error, isNot(isA<SessionAlreadyJudged>()));
    verify(() => relay.recoverJudge(installId: any(named: 'installId'), problemId: any(named: 'problemId')))
        .called(1);
  });

  test('trial path: recovery uses trialJudge for both calls', () async {
    final Session session = await seed(SessionPath.trial);
    int calls = 0;
    when(() => relay.trialJudge(installId: any(named: 'installId'), request: any(named: 'request')))
        .thenAnswer((_) async {
      if (calls++ == 0) {
        throw _alreadyJudged;
      }
      return _dto();
    });

    final Result<Assessment> result = await repo.request(session);

    expect(result, isA<Ok<Assessment>>());
    expect(calls, 2);
    verify(() => relay.recoverJudge(installId: any(named: 'installId'), problemId: 'vp-0001')).called(1);
    verifyNever(() => relay.judge(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        ));
    expect((await sessionRow())!.status, SessionStatus.complete);
  });
}
