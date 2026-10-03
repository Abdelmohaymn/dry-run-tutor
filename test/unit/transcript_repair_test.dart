// quickstart.md §4. The repository is where FR-006 (fail open) is
// implemented — every failure mode below must return `null`, never throw.
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/network/dto/repair_dto.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/core/models/wire_enums.dart';
import 'package:dry_run/features/chat/domain/server_counters.dart';
import 'package:dry_run/features/chat/domain/session.dart';
import 'package:dry_run/features/keys/domain/learner_key.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:dry_run/features/transcript/data/transcript_repair_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_install_repository.dart';
import '../fakes/fake_key_repository.dart';
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
  hintCount: 3,
);

Session _session({required SessionPath path}) => Session(
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
  setUpAll(() {
    registerFallbackValue(RepairRequestDto(problemId: 'vp-0001', transcript: 'x'));
  });

  late MockRelayClient relayClient;
  late FakeKeyRepository keyRepository;
  late FakeInstallRepository installRepository;
  late TranscriptRepairRepositoryImpl repository;

  setUp(() {
    relayClient = MockRelayClient();
    keyRepository = FakeKeyRepository()
      ..storedKey = const LearnerKey(providerId: 'groq', value: 'gsk_test');
    installRepository = FakeInstallRepository();
    repository = TranscriptRepairRepositoryImpl(
      relayClient: relayClient,
      keyRepository: keyRepository,
      installRepository: installRepository,
    );
  });

  test('a 200 with changed: true returns the repaired text', () async {
    when(() => relayClient.repair(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        )).thenAnswer(
      (_) async => RepairResponseDto(repaired: 'I would use a hash map', changed: true),
    );

    final String? result = await repository.repair(
      session: _session(path: SessionPath.keyed),
      transcript: 'I would use a hash mop',
    );

    expect(result, 'I would use a hash map');
  });

  test('a 200 with changed: false returns null', () async {
    when(() => relayClient.repair(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        )).thenAnswer(
      (_) async => RepairResponseDto(repaired: 'unchanged text', changed: false),
    );

    final String? result = await repository.repair(
      session: _session(path: SessionPath.keyed),
      transcript: 'unchanged text',
    );

    expect(result, isNull);
  });

  for (final RelayError error in <RelayError>[
    const RelayError.badRequest(),
    const RelayError.invalidKey(),
    const RelayError.rateLimited(retryAfter: Duration(seconds: 5)),
    const RelayError.unclearRetry(),
    const RelayError.transport(),
  ]) {
    test('a thrown RelayException(${error.runtimeType}) returns null and throws nothing', () async {
      when(() => relayClient.repair(
            installId: any(named: 'installId'),
            request: any(named: 'request'),
            userKey: any(named: 'userKey'),
            providerId: any(named: 'providerId'),
          )).thenThrow(RelayException(error));

      final String? result = await repository.repair(
        session: _session(path: SessionPath.keyed),
        transcript: 'some transcript',
      );

      expect(result, isNull);
    });
  }

  test('a transport-level exception also returns null', () async {
    when(() => relayClient.repair(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        )).thenThrow(Exception('socket closed'));

    final String? result = await repository.repair(
      session: _session(path: SessionPath.keyed),
      transcript: 'some transcript',
    );

    expect(result, isNull);
  });

  test('a trial-path session never reaches RelayClient.repair()', () async {
    final String? result = await repository.repair(
      session: _session(path: SessionPath.trial),
      transcript: 'some transcript',
    );

    expect(result, isNull);
    verifyNever(() => relayClient.repair(
          installId: any(named: 'installId'),
          request: any(named: 'request'),
          userKey: any(named: 'userKey'),
          providerId: any(named: 'providerId'),
        ));
  });
}
