// T151/T153 (US8): the batch drain itself. `emit()`'s buffering is
// `test/security/no_key_leak_test.dart`'s (T030) and
// `test/unit/analytics_contract_test.dart`'s (T049) to cover; this file
// is `drain()` — ≤100 events per `POST /v1/event`, and FR-051's "a
// rejected batch changes nothing visible": logged (in dev only), dropped
// after a bounded number of attempts, never surfaced as a thrown
// exception a caller would have to handle.
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:dry_run/core/db/app_database.dart';
import 'package:dry_run/core/network/dto/event_dto.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

void main() {
  late AppDatabase db;
  late MockRelayClient relayClient;
  late FakeTrustedTimeSource timeSource;
  late AnalyticsClientImpl analytics;

  setUpAll(() {
    registerFallbackValue(EventBatchDto(events: const <EventDto>[]));
  });

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    relayClient = MockRelayClient();
    timeSource = FakeTrustedTimeSource();
    analytics = AnalyticsClientImpl(
      eventDao: db.eventDao,
      timeSource: timeSource,
      relayClient: relayClient,
      resolveInstallId: () async => 'install-1',
    );
  });

  tearDown(() async {
    analytics.dispose();
    await db.close();
  });

  test('a batch the relay accepts is removed from the buffer', () async {
    when(() => relayClient.sendEvents(installId: any(named: 'installId'), batch: any(named: 'batch')))
        .thenAnswer((_) async {});

    analytics.emit(EventName.onboardingStarted);
    analytics.emit(EventName.onboardingDone);
    await Future<void>.delayed(Duration.zero);

    await analytics.drain();

    expect(await db.eventDao.due(), isEmpty);
    verify(() => relayClient.sendEvents(installId: 'install-1', batch: any(named: 'batch'))).called(1);
  });

  test('more than 100 buffered events drain in more than one batch of ≤100', () async {
    when(() => relayClient.sendEvents(installId: any(named: 'installId'), batch: any(named: 'batch')))
        .thenAnswer((_) async {});

    for (int i = 0; i < 150; i++) {
      analytics.emit(EventName.hintLadderExhausted);
    }
    await Future<void>.delayed(Duration.zero);

    await analytics.drain();

    expect(await db.eventDao.due(), isEmpty);
    final List<dynamic> calls = verify(
      () => relayClient.sendEvents(installId: 'install-1', batch: captureAny(named: 'batch')),
    ).captured;
    expect(calls, hasLength(2)); // 100 + 50, never one batch of 150
    final List<EventBatchDto> batches = calls.cast<EventBatchDto>();
    expect(batches[0].events, hasLength(100));
    expect(batches[1].events, hasLength(50));
  });

  test('a rejected batch never throws out of drain() — FR-051, US8 scenario 3', () async {
    when(() => relayClient.sendEvents(installId: any(named: 'installId'), batch: any(named: 'batch')))
        .thenThrow(Exception('the relay said no'));

    analytics.emit(EventName.revealShown);
    await Future<void>.delayed(Duration.zero);

    await expectLater(analytics.drain(), completes);
  });

  test('a rejected batch is dropped only after a bounded number of attempts, not on the first failure', () async {
    when(() => relayClient.sendEvents(installId: any(named: 'installId'), batch: any(named: 'batch')))
        .thenThrow(Exception('the relay said no'));

    analytics.emit(EventName.revealShown);
    await Future<void>.delayed(Duration.zero);

    await analytics.drain();
    expect(await db.eventDao.due(), isNotEmpty, reason: 'a single failure must not drop the event yet');

    // Bounded, not unbounded: after enough failed attempts the row is
    // gone, so a permanently rejecting batch can't grow the buffer
    // forever.
    for (int i = 0; i < 10; i++) {
      await analytics.drain();
    }
    expect(await db.eventDao.due(), isEmpty, reason: 'a permanently rejected batch must eventually be dropped');
  });
}
