// Saving a key must check it with `key_check: true`, which the relay
// answers without spending a turn. Before that flag existed, the check was
// a full tutor turn on the first available problem, often today's, so the
// learner lost a turn just by saving a key (found on device 2026-09-25).
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/dto/turn_dto.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/features/keys/data/key_repository_impl.dart';
import 'package:dry_run/features/keys/data/secure_key_store.dart';
import 'package:dry_run/features/keys/domain/learner_key.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_problem_repository.dart';
import '../fakes/mock_relay_client.dart';

class _MemoryStore implements SecureKeyStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'fallback', messages: const <TurnDto>[]));
  });

  test('saving a key sends key_check: true, so the check spends no turn', () async {
    final MockRelayClient relayClient = MockRelayClient();
    when(
      () => relayClient.chat(
        installId: any(named: 'installId'),
        request: any(named: 'request'),
        userKey: any(named: 'userKey'),
        providerId: any(named: 'providerId'),
      ),
    ).thenAnswer(
      (_) => Stream<SseFrame>.fromIterable(<SseFrame>[
        const MetaFrame(<String, Object?>{
          'turn_index': 0,
          'turns_remaining': 15,
          'hints_revealed': 0,
          'hints_remaining': 3,
          'session_ended': null,
          'leak_blocked': false,
        }),
      ]),
    );

    final KeyRepositoryImpl repository = KeyRepositoryImpl(
      store: _MemoryStore(),
      relayClient: relayClient,
      installRepository: FakeInstallRepository(),
      problemRepository: FakeProblemRepository()
        ..availableProblems = const <Problem>[
          Problem(
            schemaVersion: 2,
            id: 'vp-0001',
            title: 'Pair Sum',
            ramp: 'easy',
            tags: <String>[],
            source: 'authored',
            statement: 'Return the two positions that add up to the target.',
            constraints: <String>[],
            estSpeakSeconds: 60,
            collections: <String>[],
            glossaryTerms: <String>[],
            hintCount: 3,
          ),
        ],
      configRepository: FakeRemoteConfigRepository()
        ..cachedValue = const RuntimeConfig(
          minSupportedVersion: '1.0.0',
          killedProblemIds: <String>[],
          contentManifestUrl: '/v1/content/manifest.json',
          chat: ChatConfig(turnCap: 15, wrapUpAtTurn: 12, minTurnChars: 3),
          trial: TrialConfig(turnCap: 4),
          keyedProviders: <String>['groq'],
        ),
    );

    await repository.saveAndValidate(const LearnerKey(providerId: 'groq', value: 'gsk_test'));

    final ChatRequestDto sent = verify(
      () => relayClient.chat(
        installId: any(named: 'installId'),
        request: captureAny(named: 'request'),
        userKey: any(named: 'userKey'),
        providerId: any(named: 'providerId'),
      ),
    ).captured.single as ChatRequestDto;
    expect(sent.toJson()['key_check'], isTrue);
  });
}
