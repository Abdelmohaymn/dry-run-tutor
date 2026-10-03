// R-009 / SC-012, modelled directly on the worker's redact.test.ts: one
// known key string, zero occurrences across every log line, every
// analytics payload, and every database row written during a simulated
// session. `KeyRepositoryImpl` writes only through `SecureKeyStore`
// (never Drift, never shared_preferences); this test proves that holds
// even once the rest of a session's writes — problem cache, session,
// messages, config cache, a buffered analytics event — land in the same
// database the key repository never touches.
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/db/converters.dart';
import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/core/network/dto/turn_dto.dart';
import 'package:dry_run/core/network/redacting_log_interceptor.dart';
import 'package:dry_run/core/network/sse_parser.dart';
import 'package:dry_run/core/time/trusted_instant.dart';
import 'package:dry_run/core/time/trusted_time_source.dart';
import 'package:dry_run/features/keys/data/key_repository_impl.dart';
import 'package:dry_run/features/keys/data/secure_key_store.dart';
import 'package:dry_run/features/keys/domain/learner_key.dart';
import 'package:dry_run/features/problem/domain/problem.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_problem_repository.dart';
import '../fakes/mock_relay_client.dart';

const String _knownKey = 'gsk_thisIsAKnownTestKeyThatMustNeverLeak12345';

class _InMemorySecureKeyStore implements SecureKeyStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class _FixedTimeSource implements TrustedTimeSource {
  @override
  Future<TrustedInstant> now() async => TrustedInstant(
        utc: DateTime.utc(2026, 1, 1),
        source: TrustedTimeSourceKind.trustedTime,
        isStale: false,
      );

  @override
  Future<String> today() async => '2026-01-01';
}

void main() {
  setUpAll(() {
    registerFallbackValue(ChatRequestDto(problemId: 'fallback', messages: const <TurnDto>[]));
  });

  test('RedactingLogInterceptor scrubs the key wherever it appears in a log line', () {
    final String logLine = 'Authorization: Bearer $_knownKey — request failed';
    expect(RedactingLogInterceptor.redact(logLine), isNot(contains(_knownKey)));

    final Map<String, String> headers = RedactingLogInterceptor.redactHeaders(<String, dynamic>{
      'X-User-Key': _knownKey,
      'Content-Type': 'application/json',
    });
    expect(headers.values, isNot(contains(_knownKey)));
  });

  test(
    'the key survives only in secure storage across a simulated full session — zero occurrences in Drift or analytics',
    () async {
      final AppDatabase db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final _InMemorySecureKeyStore store = _InMemorySecureKeyStore();
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
            'turn_index': 1,
            'turns_remaining': 9,
            'hints_revealed': 0,
            'hints_remaining': 3,
            'session_ended': null,
            'leak_blocked': false,
          }),
        ]),
      );
      final KeyRepositoryImpl keyRepository = KeyRepositoryImpl(
        store: store,
        relayClient: relayClient,
        installRepository: FakeInstallRepository(),
        problemRepository: FakeProblemRepository()
          ..availableProblems = const <Problem>[
            Problem(
              schemaVersion: 2,
              id: 'vp-0001',
              title: 'Two Sum',
              ramp: 'easy',
              tags: <String>['arrays'],
              source: 'authored',
              statement: 'Given an array, return indices of the two numbers that add to target.',
              constraints: <String>['1 <= n <= 1e5'],
              estSpeakSeconds: 60,
              collections: <String>['warmup'],
              glossaryTerms: <String>['hashmap'],
              hintCount: 3,
            ),
          ],
        configRepository: FakeRemoteConfigRepository()
          ..cachedValue = const RuntimeConfig(
            minSupportedVersion: '1.0.0',
            killedProblemIds: <String>[],
            contentManifestUrl: '/v1/content/manifest.json',
            chat: ChatConfig(turnCap: 12, wrapUpAtTurn: 9, minTurnChars: 5),
            trial: TrialConfig(turnCap: 4),
            keyedProviders: <String>['groq'],
          ),
      );
      await keyRepository.saveAndValidate(
        const LearnerKey(providerId: 'groq', value: _knownKey),
      );

      // The rest of a session's writes — none of which the key repository
      // ever touches.
      await db.into(db.cachedConfig).insert(
            CachedConfigCompanion.insert(
              json: '{"min_supported_version":"1.0.0","keyed_providers":["groq"]}',
              fetchedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.into(db.cachedProblems).insert(
            CachedProblemsCompanion.insert(
              problemId: 'vp-0001',
              schemaVersion: 2,
              title: 'Two Sum',
              ramp: 'easy',
              tags: const <String>['arrays'],
              source: 'authored',
              statement: 'Given an array, return indices of the two numbers that add to target.',
              constraints: const <String>['1 <= n <= 1e5'],
              estSpeakSeconds: 60,
              collections: const <String>['warmup'],
              glossaryTerms: const <String>['hashmap'],
              hintCount: 3,
              fetchedAt: DateTime.utc(2026, 1, 1),
            ),
          );
      await db.into(db.sessions).insert(
            SessionsCompanion.insert(
              id: 'session-1',
              problemId: 'vp-0001',
              day: '2026-01-01',
              path: SessionPath.keyed,
              status: SessionStatus.chatting,
              startedAt: DateTime.utc(2026, 1, 1),
              providerId: const Value<String?>('groq'),
            ),
          );
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'message-1',
              sessionId: 'session-1',
              seq: 0,
              role: TurnRole.user,
              body: 'I would use a hashmap to track seen values.',
              kind: MessageKind.turn,
              delivery: Delivery.sent,
              createdAt: DateTime.utc(2026, 1, 1),
            ),
          );

      final AnalyticsClientImpl analytics = AnalyticsClientImpl(
        eventDao: db.eventDao,
        timeSource: _FixedTimeSource(),
        relayClient: MockRelayClient(),
        resolveInstallId: () async => 'install-1',
      );
      addTearDown(analytics.dispose);
      analytics.emit(EventName.keySaved, props: const <String, Object>{'provider': 'groq'});
      // `emit` is fire-and-forget; let the buffered write land before the
      // scan below reads it back.
      await Future<void>.delayed(Duration.zero);

      final String dump = await _dumpEveryTable(db);
      expect(dump, isNot(contains(_knownKey)));

      // The one place it is allowed to be.
      expect(await store.read('keys.value'), _knownKey);
    },
  );
}

Future<String> _dumpEveryTable(AppDatabase db) async {
  final StringBuffer buffer = StringBuffer()
    ..writeln(await db.select(db.installIdentity).get())
    ..writeln(await db.select(db.cachedProblems).get())
    ..writeln(await db.select(db.sessions).get())
    ..writeln(await db.select(db.messages).get())
    ..writeln(await db.select(db.drafts).get())
    ..writeln(await db.select(db.assessments).get())
    ..writeln(await db.select(db.outbox).get())
    ..writeln(await db.select(db.streakDays).get())
    ..writeln(await db.select(db.cachedConfig).get())
    ..writeln(await db.select(db.bufferedEvents).get());
  return buffer.toString();
}
