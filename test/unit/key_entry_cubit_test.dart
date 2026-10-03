// T084 — US2 scenario 5: a rejected key returns to entry with what the
// learner typed preserved, and FR-005b: a key is never persisted before
// its probe succeeds.
import 'package:bloc_test/bloc_test.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/errors/result.dart';
import 'package:dry_run/features/keys/presentation/key_entry_cubit.dart';
import 'package:dry_run/features/keys/presentation/key_entry_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fakes/fake_analytics_client.dart';
import '../fakes/fake_key_repository.dart';

void main() {
  late FakeKeyRepository keyRepository;
  late FakeAnalyticsClient analyticsClient;

  setUp(() {
    keyRepository = FakeKeyRepository();
    analyticsClient = FakeAnalyticsClient();
  });

  KeyEntryCubit buildCubit() => KeyEntryCubit(
        keyRepository: keyRepository,
        providers: const <String>['groq', 'gemini'],
        analyticsClient: analyticsClient,
      );

  test('opens on the first offered provider and emits key_entry_started', () {
    buildCubit();
    final (EventName, Map<String, Object>?)? started = analyticsClient.emitted
        .cast<(EventName, Map<String, Object>?)?>()
        .firstWhere((event) => event!.$1 == EventName.keyEntryStarted, orElse: () => null);
    expect(started, isNotNull);
    expect(started!.$2?['provider'], 'groq');
  });

  blocTest<KeyEntryCubit, KeyEntryState>(
    'a valid key persists and the state carries the provider',
    build: buildCubit,
    act: (KeyEntryCubit cubit) {
      cubit.updateValue('gsk_a-real-looking-key');
      return cubit.submit();
    },
    expect: () => <Object>[
      const KeyEntryState.entering(
        providers: <String>['groq', 'gemini'],
        providerId: 'groq',
        value: 'gsk_a-real-looking-key',
      ),
      const KeyEntryState.probing(
        providers: <String>['groq', 'gemini'],
        providerId: 'groq',
        value: 'gsk_a-real-looking-key',
      ),
      const KeyEntryState.saved(providerId: 'groq'),
    ],
    verify: (_) {
      expect(keyRepository.storedKey?.providerId, 'groq');
      expect(keyRepository.storedKey?.value, 'gsk_a-real-looking-key');
    },
  );

  blocTest<KeyEntryCubit, KeyEntryState>(
    'a rejected key is never persisted and the typed value survives (US2 scenario 5)',
    build: buildCubit,
    setUp: () {
      keyRepository.scriptedResult = const Err<void>(RelayError.invalidKey());
    },
    act: (KeyEntryCubit cubit) {
      cubit.updateValue('gsk_a-bad-key');
      return cubit.submit();
    },
    expect: () => <Object>[
      const KeyEntryState.entering(
        providers: <String>['groq', 'gemini'],
        providerId: 'groq',
        value: 'gsk_a-bad-key',
      ),
      const KeyEntryState.probing(
        providers: <String>['groq', 'gemini'],
        providerId: 'groq',
        value: 'gsk_a-bad-key',
      ),
      const KeyEntryState.rejected(
        providers: <String>['groq', 'gemini'],
        providerId: 'groq',
        value: 'gsk_a-bad-key',
        error: RelayError.invalidKey(),
      ),
    ],
    verify: (_) {
      expect(keyRepository.storedKey, isNull);
    },
  );

  blocTest<KeyEntryCubit, KeyEntryState>(
    'switching provider after a rejection preserves the typed value',
    build: buildCubit,
    setUp: () {
      keyRepository.scriptedResult = const Err<void>(RelayError.invalidKey());
    },
    act: (KeyEntryCubit cubit) async {
      cubit.updateValue('gsk_still-typed');
      await cubit.submit();
      cubit.selectProvider('gemini');
    },
    skip: 3,
    expect: () => <Object>[
      const KeyEntryState.entering(
        providers: <String>['groq', 'gemini'],
        providerId: 'gemini',
        value: 'gsk_still-typed',
      ),
    ],
  );
}
