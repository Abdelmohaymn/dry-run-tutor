// CloudVoiceRepositoryImpl against fakes for everything but the file system:
// the clip's temp file is real, so "kept", "deleted" and "byte-identical" are
// proved on disk, not assumed. Covers the quota arithmetic (nextClipLimit),
// each Worker answer's effect on the clip (the plan's retry table), manual
// retry, discard, cancel, the orphan sweep, and the 10-minute cooldown.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dry_run/core/config/runtime_config.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/network/dto/stt_dto.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:dry_run/features/cloud_voice/data/cloud_voice_repository_impl.dart';
import 'package:dry_run/features/cloud_voice/data/voice_quota_store.dart';
import 'package:dry_run/features/cloud_voice/domain/cloud_voice_failure.dart';
import 'package:dry_run/features/cloud_voice/domain/voice_quota.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';
import 'package:dry_run/features/voice/domain/spoken_language_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../fakes/fake_audio_recorder_port.dart';
import '../fakes/fake_config_repository.dart';
import '../fakes/fake_install_repository.dart';
import '../fakes/fake_trusted_time_source.dart';
import '../fakes/mock_relay_client.dart';

class _FakeSpokenLanguageRepository implements SpokenLanguageRepository {
  String? localeId;

  @override
  Future<String?> read() async => localeId;

  @override
  Future<void> write(String id) async => localeId = id;
}

RuntimeConfig _config({VoiceConfig? voice}) => RuntimeConfig(
  minSupportedVersion: '1.0.0',
  killedProblemIds: const <String>[],
  chat: const ChatConfig(turnCap: 4, wrapUpAtTurn: 3, minTurnChars: 5),
  trial: const TrialConfig(turnCap: 4),
  keyedProviders: const <String>[],
  voice: voice,
);

const VoiceConfig _voiceOn = VoiceConfig(
  enabled: true,
  secondsPerDevice: 300,
  maxClipSeconds: 120,
);

SttResponseDto _ok(String text, {int secondsLeft = 240, int maxClip = 120}) =>
    SttResponseDto(
      text: text,
      secondsLeft: secondsLeft,
      maxClipSeconds: maxClip,
    );

RelayException get _transport => const RelayException(RelayError.transport());

void main() {
  late Directory tempDir;
  late FakeRemoteConfigRepository configRepo;
  late FakeInstallRepository installRepo;
  late FakeTrustedTimeSource time;
  late MockRelayClient relay;
  late FakeAudioRecorderPort recorder;
  late _FakeSpokenLanguageRepository language;
  late VoiceQuotaStore store;
  late CloudVoiceRepositoryImpl repo;
  late bool online;
  late Duration now;

  /// Outcomes the relay's next `stt` calls produce, in order. A
  /// [SttResponseDto] is returned; anything else is thrown.
  late List<Object> outcomes;
  late List<Uint8List> sentAudio;
  late List<String?> sentLanguages;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('cloud_voice_test_');
    configRepo = FakeRemoteConfigRepository()
      ..cachedValue = _config(voice: _voiceOn);
    installRepo = FakeInstallRepository();
    time = FakeTrustedTimeSource();
    relay = MockRelayClient();
    recorder = FakeAudioRecorderPort();
    language = _FakeSpokenLanguageRepository();
    store = VoiceQuotaStore(await SharedPreferences.getInstance());
    online = true;
    now = Duration.zero;
    outcomes = <Object>[];
    sentAudio = <Uint8List>[];
    sentLanguages = <String?>[];

    when(
      () => relay.stt(
        installId: any(named: 'installId'),
        audio: any(named: 'audio'),
        contentType: any(named: 'contentType'),
        language: any(named: 'language'),
      ),
    ).thenAnswer((Invocation inv) async {
      sentAudio.add(
        Uint8List.fromList(inv.namedArguments[#audio] as Uint8List),
      );
      sentLanguages.add(inv.namedArguments[#language] as String?);
      final Object next = outcomes.removeAt(0);
      if (next is SttResponseDto) return next;
      throw next;
    });

    repo = CloudVoiceRepositoryImpl(
      configRepository: configRepo,
      installRepository: installRepo,
      relayClient: relay,
      timeSource: time,
      store: store,
      recorder: recorder,
      spokenLanguageRepository: language,
      isOnline: () async => online,
      tempDirPath: () async => tempDir.path,
      monotonicNow: () => now,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  List<File> clipsOnDisk() => tempDir.listSync().whereType<File>().toList();

  void verifyNoUpload() => verifyNever(
    () => relay.stt(
      installId: any(named: 'installId'),
      audio: any(named: 'audio'),
      contentType: any(named: 'contentType'),
      language: any(named: 'language'),
    ),
  );

  /// Starts a recording, lets the recorder come up, and returns the events
  /// collected so far plus the stream's completion.
  Future<({List<RecognitionEvent> events, Future<void> done})> startRecording({
    Duration limit = const Duration(seconds: 120),
  }) async {
    final List<RecognitionEvent> events = <RecognitionEvent>[];
    final Completer<void> closed = Completer<void>();
    repo.record(limit: limit).listen(events.add, onDone: closed.complete);
    // hasPermission -> tempDirPath -> start are a few microtasks plus a real
    // file write; wait until the repository is listening to the recorder's
    // levels (it is up), or the stream closed (it failed to start).
    for (
      var i = 0;
      i < 100 && !recorder.levelController.hasListener && !closed.isCompleted;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return (events: events, done: closed.future);
  }

  /// Record -> stop, returning every event the stream produced.
  Future<List<RecognitionEvent>> recordAndStop() async {
    final r = await startRecording();
    await repo.stop();
    await r.done;
    return r.events;
  }

  RecognitionErrorEvent asError(RecognitionEvent e) {
    expect(e, isA<RecognitionErrorEvent>());
    return e as RecognitionErrorEvent;
  }

  group('nextClipLimit', () {
    test('config absent gives null', () async {
      configRepo.cachedValue = null;
      expect(await repo.nextClipLimit(), isNull);
    });

    test('voice block absent gives null', () async {
      configRepo.cachedValue = _config();
      expect(await repo.nextClipLimit(), isNull);
    });

    test('voice disabled gives null', () async {
      configRepo.cachedValue = _config(
        voice: const VoiceConfig(
          enabled: false,
          secondsPerDevice: 300,
          maxClipSeconds: 120,
        ),
      );
      expect(await repo.nextClipLimit(), isNull);
    });

    test('offline gives null', () async {
      online = false;
      expect(await repo.nextClipLimit(), isNull);
    });

    test('a fresh day gives min(maxClip, secondsPerDevice)', () async {
      expect(await repo.nextClipLimit(), const Duration(seconds: 120));

      configRepo.cachedValue = _config(
        voice: const VoiceConfig(
          enabled: true,
          secondsPerDevice: 90,
          maxClipSeconds: 120,
        ),
      );
      expect(await repo.nextClipLimit(), const Duration(seconds: 90));
    });

    test('stored same-day 60 gives 60', () async {
      await store.write(
        const VoiceQuota(
          date: '2026-01-01',
          secondsLeft: 60,
          maxClipSeconds: 120,
        ),
      );
      expect(await repo.nextClipLimit(), const Duration(seconds: 60));
    });

    test('stored yesterday (0 left) gives 120', () async {
      await store.write(
        const VoiceQuota(
          date: '2025-12-31',
          secondsLeft: 0,
          maxClipSeconds: 120,
        ),
      );
      expect(await repo.nextClipLimit(), const Duration(seconds: 120));
    });

    test('stored same-day 0 gives null', () async {
      await store.write(
        const VoiceQuota(
          date: '2026-01-01',
          secondsLeft: 0,
          maxClipSeconds: 120,
        ),
      );
      expect(await repo.nextClipLimit(), isNull);
    });
  });

  group('record -> stop', () {
    test(
      'success emits levels then FinalTextEvent, persists quota, deletes the file',
      () async {
        outcomes.add(_ok('hello world', secondsLeft: 250, maxClip: 100));

        final r = await startRecording();
        recorder.levelController
          ..add(0.25)
          ..add(0.75);
        await Future<void>.delayed(Duration.zero);
        await repo.stop();
        await r.done;

        expect(r.events, hasLength(3));
        expect((r.events[0] as LevelEvent).level, 0.25);
        expect((r.events[1] as LevelEvent).level, 0.75);
        expect((r.events[2] as FinalTextEvent).text, 'hello world');

        expect(
          store.read(),
          const VoiceQuota(
            date: '2026-01-01',
            secondsLeft: 250,
            maxClipSeconds: 100,
          ),
        );
        expect(clipsOnDisk(), isEmpty);
        expect(repo.hasPendingClip, isFalse);
        expect(sentAudio.single, recorder.clipBytes);
      },
    );

    test(
      'the language query is the first two letters of the spoken locale',
      () async {
        language.localeId = 'ar-EG';
        outcomes.add(_ok('مرحبا'));
        await recordAndStop();
        expect(sentLanguages.single, 'ar');
      },
    );

    test(
      'exhausted emits the exhausted reason, persists 0, deletes the file',
      () async {
        outcomes.add(const SttRefusedException(SttRefusal.exhausted));

        final List<RecognitionEvent> events = await recordAndStop();

        final RecognitionErrorEvent error = asError(events.last);
        expect(error.reason, CloudVoiceFailure.exhausted);
        expect(error.permanent, isTrue);
        expect(store.read()?.secondsLeft, 0);
        expect(store.read()?.date, '2026-01-01');
        expect(clipsOnDisk(), isEmpty);
        expect(repo.hasPendingClip, isFalse);
        expect(await repo.nextClipLimit(), isNull);
      },
    );

    test(
      'unavailable deletes the file, then cools down for 10 minutes',
      () async {
        outcomes.add(const SttRefusedException(SttRefusal.unavailable));

        final List<RecognitionEvent> events = await recordAndStop();

        final RecognitionErrorEvent error = asError(events.last);
        expect(error.reason, CloudVoiceFailure.unavailable);
        expect(error.permanent, isTrue);
        expect(clipsOnDisk(), isEmpty);
        expect(repo.hasPendingClip, isFalse);
        // Nothing was charged, so the quota is untouched.
        expect(store.read(), isNull);

        expect(await repo.nextClipLimit(), isNull);

        now += cloudCooldown - const Duration(seconds: 1);
        expect(await repo.nextClipLimit(), isNull);

        now += const Duration(seconds: 1);
        expect(await repo.nextClipLimit(), const Duration(seconds: 120));
      },
    );

    test('bad request deletes the file and emits rejected', () async {
      outcomes.add(const RelayException(RelayError.badRequest()));

      final List<RecognitionEvent> events = await recordAndStop();

      final RecognitionErrorEvent error = asError(events.last);
      expect(error.reason, CloudVoiceFailure.rejected);
      expect(error.permanent, isTrue);
      expect(clipsOnDisk(), isEmpty);
      expect(repo.hasPendingClip, isFalse);
      // Cloud stays on while seconds remain: no cooldown.
      expect(await repo.nextClipLimit(), const Duration(seconds: 120));
    });

    test(
      'busy emits retryable (not permanent), keeps the file, sets hasPendingClip',
      () async {
        outcomes.add(const SttRefusedException(SttRefusal.busy));

        final List<RecognitionEvent> events = await recordAndStop();

        final RecognitionErrorEvent error = asError(events.last);
        expect(error.reason, CloudVoiceFailure.retryable);
        expect(error.permanent, isFalse);
        expect(repo.hasPendingClip, isTrue);
        expect(clipsOnDisk(), hasLength(1));
        expect(await clipsOnDisk().single.readAsBytes(), recorder.clipBytes);
        // Nothing was charged.
        expect(store.read(), isNull);
        // While a clip waits for retry, the next recording is not cloud.
        expect(await repo.nextClipLimit(), isNull);
      },
    );

    test(
      'a TransportFailure emits retryable (not permanent), keeps the file',
      () async {
        outcomes.add(_transport);

        final List<RecognitionEvent> events = await recordAndStop();

        final RecognitionErrorEvent error = asError(events.last);
        expect(error.reason, CloudVoiceFailure.retryable);
        expect(error.permanent, isFalse);
        expect(repo.hasPendingClip, isTrue);
        expect(clipsOnDisk(), hasLength(1));
      },
    );

    test(
      'permission denied emits the permission reason and records nothing',
      () async {
        recorder.permission = false;

        final r = await startRecording();
        await r.done;

        final RecognitionErrorEvent error = asError(r.events.single);
        expect(error.reason, CloudVoiceFailure.permission);
        expect(error.permanent, isTrue);
        expect(recorder.startCalls, 0);
        expect(clipsOnDisk(), isEmpty);
        verifyNoUpload();
      },
    );

    test(
      'a recorder that fails to start emits rejected and leaves no file',
      () async {
        recorder.startError = StateError('no mic');

        final r = await startRecording();
        await r.done;

        expect(asError(r.events.single).reason, CloudVoiceFailure.rejected);
        expect(clipsOnDisk(), isEmpty);
        verifyNoUpload();
      },
    );

    test(
      'a recorder that returns no file emits rejected without uploading',
      () async {
        recorder.stopReturnsNull = true;

        final List<RecognitionEvent> events = await recordAndStop();

        expect(asError(events.last).reason, CloudVoiceFailure.rejected);
        expect(repo.hasPendingClip, isFalse);
        verifyNoUpload();
      },
    );
  });

  group('retryUpload', () {
    test(
      'sends byte-identical audio and on success deletes the file and clears pending',
      () async {
        recorder.clipBytes = List<int>.generate(2048, (int i) => (i * 7) % 256);
        outcomes
          ..add(_transport)
          ..add(_ok('second time lucky', secondsLeft: 200));

        await recordAndStop();
        expect(repo.hasPendingClip, isTrue);

        final RecognitionEvent event = await repo.retryUpload();

        expect((event as FinalTextEvent).text, 'second time lucky');
        expect(sentAudio, hasLength(2));
        expect(sentAudio[1], sentAudio[0]);
        expect(sentAudio[1], recorder.clipBytes);
        expect(repo.hasPendingClip, isFalse);
        expect(clipsOnDisk(), isEmpty);
        expect(store.read()?.secondsLeft, 200);
      },
    );

    test(
      'failing transiently again returns retryable and still holds the file',
      () async {
        outcomes
          ..add(const SttRefusedException(SttRefusal.busy))
          ..add(_transport)
          ..add(const SttRefusedException(SttRefusal.busy));

        await recordAndStop();

        for (var i = 0; i < 2; i++) {
          final RecognitionErrorEvent error = asError(await repo.retryUpload());
          expect(error.reason, CloudVoiceFailure.retryable);
          expect(error.permanent, isFalse);
          expect(repo.hasPendingClip, isTrue);
          expect(clipsOnDisk(), hasLength(1));
        }
        expect(sentAudio, hasLength(3));
        for (final Uint8List sent in sentAudio) {
          expect(
            sent,
            recorder.clipBytes,
            reason: 'every attempt sends the same bytes',
          );
        }
      },
    );

    test('exhausted on retry deletes the file and persists 0', () async {
      outcomes
        ..add(_transport)
        ..add(const SttRefusedException(SttRefusal.exhausted));

      await recordAndStop();
      final RecognitionErrorEvent error = asError(await repo.retryUpload());

      expect(error.reason, CloudVoiceFailure.exhausted);
      expect(error.permanent, isTrue);
      expect(repo.hasPendingClip, isFalse);
      expect(clipsOnDisk(), isEmpty);
      expect(store.read()?.secondsLeft, 0);
    });

    test(
      'unavailable on retry deletes the file and starts the cooldown',
      () async {
        outcomes
          ..add(_transport)
          ..add(const SttRefusedException(SttRefusal.unavailable));

        await recordAndStop();
        final RecognitionErrorEvent error = asError(await repo.retryUpload());

        expect(error.reason, CloudVoiceFailure.unavailable);
        expect(clipsOnDisk(), isEmpty);
        expect(await repo.nextClipLimit(), isNull);
        now += cloudCooldown;
        expect(await repo.nextClipLimit(), const Duration(seconds: 120));
      },
    );

    test('throws StateError when there is no pending clip', () async {
      expect(() => repo.retryUpload(), throwsStateError);
      verifyNoUpload();
    });

    test('throws StateError after the clip was already delivered', () async {
      outcomes.add(_ok('done'));
      await recordAndStop();
      expect(() => repo.retryUpload(), throwsStateError);
    });
  });

  group('discardPending', () {
    test('deletes the kept file with no relay call', () async {
      outcomes.add(_transport);
      await recordAndStop();
      expect(clipsOnDisk(), hasLength(1));

      await repo.discardPending();

      expect(repo.hasPendingClip, isFalse);
      expect(clipsOnDisk(), isEmpty);
      verify(
        () => relay.stt(
          installId: any(named: 'installId'),
          audio: any(named: 'audio'),
          contentType: any(named: 'contentType'),
          language: any(named: 'language'),
        ),
      ).called(1); // only the original failed upload
    });

    test('is a no-op when nothing is pending', () async {
      await repo.discardPending();
      expect(repo.hasPendingClip, isFalse);
      verifyNoUpload();
    });
  });

  group('cancel', () {
    test(
      'during a recording makes no relay call and deletes the file',
      () async {
        final r = await startRecording();
        final String path = recorder.startedPath!;
        expect(File(path).existsSync(), isTrue);

        await repo.cancel();
        await r.done;

        expect(recorder.cancelCalls, 1);
        expect(File(path).existsSync(), isFalse);
        expect(r.events.whereType<FinalTextEvent>(), isEmpty);
        expect(r.events.whereType<RecognitionErrorEvent>(), isEmpty);
        verifyNoUpload();
      },
    );

    test('deletes a pending clip too', () async {
      outcomes.add(_transport);
      await recordAndStop();
      expect(clipsOnDisk(), hasLength(1));

      await repo.cancel();

      expect(repo.hasPendingClip, isFalse);
      expect(clipsOnDisk(), isEmpty);
    });

    test('stop after cancel does nothing', () async {
      final r = await startRecording();
      await repo.cancel();
      await r.done;

      await repo.stop();

      expect(recorder.stopCalls, 0);
      verifyNoUpload();
    });
  });

  group('sweepOrphanClips', () {
    test(
      'deletes stray stt_*.m4a, keeps the pending clip and non-matching files',
      () async {
        outcomes.add(_transport);
        await recordAndStop();
        final File pending = clipsOnDisk().single;

        final File orphan = await File(
          '${tempDir.path}/stt_orphan.m4a',
        ).writeAsBytes(<int>[1]);
        final File orphan2 = await File(
          '${tempDir.path}/stt_other-uuid.m4a',
        ).writeAsBytes(<int>[2]);
        final File notes = await File(
          '${tempDir.path}/notes.txt',
        ).writeAsBytes(<int>[3]);
        final File wrongExt = await File(
          '${tempDir.path}/stt_clip.mp3',
        ).writeAsBytes(<int>[4]);
        final File wrongPrefix = await File(
          '${tempDir.path}/clip_stt_1.m4a',
        ).writeAsBytes(<int>[5]);

        await repo.sweepOrphanClips();

        expect(orphan.existsSync(), isFalse);
        expect(orphan2.existsSync(), isFalse);
        expect(pending.existsSync(), isTrue);
        expect(notes.existsSync(), isTrue);
        expect(wrongExt.existsSync(), isTrue);
        expect(wrongPrefix.existsSync(), isTrue);
        expect(repo.hasPendingClip, isTrue);
      },
    );

    test('keeps the file of a recording in progress', () async {
      await startRecording();
      final String path = recorder.startedPath!;

      await repo.sweepOrphanClips();

      expect(File(path).existsSync(), isTrue);
      await repo.cancel();
    });

    test('a missing temp directory is not an error', () async {
      await tempDir.delete(recursive: true);
      await repo.sweepOrphanClips();
    });
  });

  test('120 + 120 + 120 gives limits 120, 120, 60, then null', () async {
    outcomes
      ..add(_ok('one', secondsLeft: 180))
      ..add(_ok('two', secondsLeft: 60))
      ..add(_ok('three', secondsLeft: 0));

    final List<Duration?> limits = <Duration?>[];
    for (var i = 0; i < 3; i++) {
      limits.add(await repo.nextClipLimit());
      final List<RecognitionEvent> events = await recordAndStop();
      expect(events.last, isA<FinalTextEvent>());
    }
    limits.add(await repo.nextClipLimit());

    expect(limits, <Duration?>[
      const Duration(seconds: 120),
      const Duration(seconds: 120),
      const Duration(seconds: 60),
      null,
    ]);
  });
}
