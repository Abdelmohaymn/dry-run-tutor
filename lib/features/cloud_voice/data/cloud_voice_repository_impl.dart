import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/config/remote_config_repository.dart';
import '../../../core/config/runtime_config.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/errors/result.dart';
import '../../../core/network/dto/stt_dto.dart';
import '../../../core/network/relay_client.dart';
import '../../../core/time/trusted_time_source.dart';
import '../../onboarding/domain/install_identity.dart';
import '../../onboarding/domain/install_repository.dart';
import '../../voice/domain/recognition_event.dart';
import '../../voice/domain/spoken_language_repository.dart';
import '../domain/cloud_voice_failure.dart';
import '../domain/cloud_voice_repository.dart';
import '../domain/voice_quota.dart';
import 'audio_recorder_port.dart';
import 'voice_quota_store.dart';

/// How long cloud voice stays paused after `VOICE_UNAVAILABLE`, so the next
/// mic tap goes on-device instead of straight back into the provider's limit.
const Duration cloudCooldown = Duration(minutes: 10);

/// The container the recorder writes (AAC-LC in m4a).
const String _clipContentType = 'audio/mp4';

const String _defaultLanguage = 'en';

final RegExp _orphanClipName = RegExp(r'^stt_.*\.m4a$');

/// [CloudVoiceRepository] that records through [AudioRecorderPort] and sends
/// the clip only to our relay via [RelayClient] (`POST /v1/stt`). No HTTP
/// client is used here, so audio can reach no other host.
///
/// The clip's temp file has one owner: this class. It is deleted on success,
/// on a non-retryable answer, on [discardPending], and on [cancel]. It is
/// kept only after a retryable failure (see the plan's retry table).
class CloudVoiceRepositoryImpl implements CloudVoiceRepository {
  /// [monotonicNow] is the test seam for the 10-minute cooldown. It must
  /// return a monotonically increasing reading (the default is a running
  /// [Stopwatch]); tests inject a fake to move past [cloudCooldown] without
  /// waiting. `DateTime.now()` is banned by `no_wall_clock`.
  CloudVoiceRepositoryImpl({
    required RemoteConfigRepository configRepository,
    required InstallRepository installRepository,
    required RelayClient relayClient,
    required TrustedTimeSource timeSource,
    required VoiceQuotaStore store,
    required AudioRecorderPort recorder,
    required SpokenLanguageRepository spokenLanguageRepository,
    required Future<bool> Function() isOnline,
    required Future<String> Function() tempDirPath,
    Duration Function()? monotonicNow,
    Uuid uuid = const Uuid(),
  })  : _configRepository = configRepository,
        _installRepository = installRepository,
        _relayClient = relayClient,
        _timeSource = timeSource,
        _store = store,
        _recorder = recorder,
        _spokenLanguageRepository = spokenLanguageRepository,
        _isOnline = isOnline,
        _tempDirPath = tempDirPath,
        _monotonicNow = monotonicNow ?? _stopwatchClock(),
        _uuid = uuid;

  final RemoteConfigRepository _configRepository;
  final InstallRepository _installRepository;
  final RelayClient _relayClient;
  final TrustedTimeSource _timeSource;
  final VoiceQuotaStore _store;
  final AudioRecorderPort _recorder;
  final SpokenLanguageRepository _spokenLanguageRepository;
  final Future<bool> Function() _isOnline;
  final Future<String> Function() _tempDirPath;
  final Duration Function() _monotonicNow;
  final Uuid _uuid;

  /// Monotonic reading at which the post-unavailable cooldown began; null
  /// when no cooldown is running. In memory only: a relaunch clears it.
  Duration? _cooldownStartedAt;

  /// The clip kept for "Try again" (or being uploaded right now).
  String? _pendingPath;

  /// The file the recorder is writing to, while a recording is active.
  String? _recordingPath;

  StreamController<RecognitionEvent>? _controller;
  StreamSubscription<double>? _levelSub;
  Future<void>? _starting;

  static Duration Function() _stopwatchClock() {
    final Stopwatch stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }

  @override
  bool get hasPendingClip => _pendingPath != null;

  @override
  Future<Duration?> nextClipLimit() async {
    try {
      if (hasPendingClip) return null;
      if (_inCooldown()) return null;

      final VoiceConfig? voice = _configRepository.cached()?.voice;
      if (voice == null || !voice.enabled) return null;
      if (!await _isOnline()) return null;

      final String today = await _timeSource.today();
      final VoiceQuota? quota = _store.read();
      final bool sameDay = quota != null && quota.date == today;
      final int left = sameDay ? quota.secondsLeft : voice.secondsPerDevice;
      // The smaller of the two: a limit the operator lowered since the last
      // transcription must win over the stored one, or every clip runs long.
      final int maxClip = sameDay ? math.min(quota.maxClipSeconds, voice.maxClipSeconds) : voice.maxClipSeconds;

      final int limit = math.min(maxClip, left);
      if (limit <= 0) return null;
      return Duration(seconds: limit);
    } catch (_) {
      return null;
    }
  }

  bool _inCooldown() {
    final Duration? startedAt = _cooldownStartedAt;
    if (startedAt == null) return false;
    if (_monotonicNow() - startedAt < cloudCooldown) return true;
    _cooldownStartedAt = null;
    return false;
  }

  @override
  Stream<RecognitionEvent> record({required Duration limit}) {
    // A new recording replaces any stale one; nothing is uploaded for it.
    unawaited(_abandonRecording());

    final StreamController<RecognitionEvent> controller = StreamController<RecognitionEvent>();
    _controller = controller;
    _starting = _start(controller);
    return controller.stream;
  }

  Future<void> _start(StreamController<RecognitionEvent> controller) async {
    try {
      if (!await _recorder.hasPermission()) {
        _emitAndClose(controller, const RecognitionErrorEvent(CloudVoiceFailure.permission, permanent: true));
        return;
      }
      final String tmp = await _tempDirPath();
      final String path = '$tmp/stt_${_uuid.v4()}.m4a';
      _recordingPath = path;
      await _recorder.start(path);
      if (controller.isClosed) return; // cancelled while starting
      _levelSub = _recorder.levels().listen(
        (double level) {
          if (!controller.isClosed) controller.add(LevelEvent(level));
        },
        onError: (Object _) {},
      );
    } catch (_) {
      await _deleteFile(_recordingPath);
      _recordingPath = null;
      _emitAndClose(controller, const RecognitionErrorEvent(CloudVoiceFailure.rejected, permanent: true));
    }
  }

  @override
  Future<void> stop() async {
    final StreamController<RecognitionEvent>? controller = _controller;
    if (controller == null || controller.isClosed) return;

    try {
      await _starting;
      await _levelSub?.cancel();
      _levelSub = null;
      if (controller.isClosed) return; // start failed or was cancelled

      final String? path = await _recorder.stop();
      _recordingPath = null;
      if (path == null || !await File(path).exists()) {
        await _deleteFile(path);
        _emitAndClose(controller, const RecognitionErrorEvent(CloudVoiceFailure.rejected, permanent: true));
        return;
      }

      _pendingPath = path;
      final RecognitionEvent event = await _upload();
      if (controller.isClosed) {
        // Cancelled while uploading: nothing may outlive the cancel.
        await _deleteClip();
        return;
      }
      _emitAndClose(controller, event);
    } catch (_) {
      await _deleteClip();
      _emitAndClose(controller, const RecognitionErrorEvent(CloudVoiceFailure.rejected, permanent: true));
    }
  }

  /// Uploads the pending clip and maps the outcome onto a [RecognitionEvent]
  /// and the clip's fate. Shared by [stop] and [retryUpload].
  Future<RecognitionEvent> _upload() async {
    try {
      final Uint8List audio = await File(_pendingPath!).readAsBytes();

      final Result<InstallIdentity> identity = await _installRepository.ensureIdentity();
      if (identity is! Ok<InstallIdentity>) {
        await _deleteClip();
        return _failure(CloudVoiceFailure.rejected);
      }
      final String language = _languageOf(await _spokenLanguageRepository.read());

      final SttResponseDto response = await _relayClient.stt(
        installId: identity.value.installId,
        audio: audio,
        contentType: _clipContentType,
        language: language,
      );

      await _deleteClip();
      await _persistQuota(response.secondsLeft, response.maxClipSeconds);
      return FinalTextEvent(response.text);
    } on SttRefusedException catch (e) {
      switch (e.refusal) {
        case SttRefusal.busy:
          return _failure(CloudVoiceFailure.retryable); // clip kept
        case SttRefusal.unavailable:
          await _deleteClip();
          _cooldownStartedAt = _monotonicNow();
          return _failure(CloudVoiceFailure.unavailable);
        case SttRefusal.exhausted:
          await _deleteClip();
          await _persistQuota(0, null);
          return _failure(CloudVoiceFailure.exhausted);
      }
    } on RelayException catch (e) {
      if (e.error is TransportFailure) {
        return _failure(CloudVoiceFailure.retryable); // clip kept
      }
      await _deleteClip();
      return _failure(CloudVoiceFailure.rejected);
    } catch (_) {
      await _deleteClip();
      return _failure(CloudVoiceFailure.rejected);
    }
  }

  @override
  Future<RecognitionEvent> retryUpload() {
    if (_pendingPath == null) {
      throw StateError('retryUpload() called with no pending clip');
    }
    return _upload();
  }

  @override
  Future<void> discardPending() => _deleteClip();

  @override
  Future<void> cancel() async {
    await _abandonRecording();
    await _deleteClip();
  }

  @override
  Future<void> sweepOrphanClips() async {
    try {
      final Directory dir = Directory(await _tempDirPath());
      if (!await dir.exists()) return;
      await for (final FileSystemEntity entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path == _pendingPath || entity.path == _recordingPath) continue;
        final String name = entity.uri.pathSegments.last;
        if (!_orphanClipName.hasMatch(name)) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  // --- helpers -------------------------------------------------------------

  /// Stops any active recording without uploading, deletes its file, and
  /// closes the stream with no terminal event.
  Future<void> _abandonRecording() async {
    final StreamController<RecognitionEvent>? controller = _controller;
    final String? recordingPath = _recordingPath;
    _controller = null;
    _recordingPath = null;

    await _levelSub?.cancel();
    _levelSub = null;

    if (controller != null && !controller.isClosed) {
      try {
        await _recorder.cancel();
      } catch (_) {}
      await controller.close();
    }
    await _deleteFile(recordingPath);
  }

  void _emitAndClose(StreamController<RecognitionEvent> controller, RecognitionEvent event) {
    if (controller.isClosed) return;
    controller.add(event);
    unawaited(controller.close());
  }

  RecognitionErrorEvent _failure(String reason) =>
      RecognitionErrorEvent(reason, permanent: reason != CloudVoiceFailure.retryable);

  /// Deletes the pending clip's file (errors ignored) and forgets it.
  Future<void> _deleteClip() async {
    final String? path = _pendingPath;
    _pendingPath = null;
    await _deleteFile(path);
  }

  Future<void> _deleteFile(String? path) async {
    if (path == null) return;
    try {
      final File file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Writes today's quota. [maxClipSeconds] null keeps the stored value, or
  /// the configured one when nothing is stored for today. Never throws: a
  /// storage hiccup must not lose a transcript the user already paid for.
  Future<void> _persistQuota(int secondsLeft, int? maxClipSeconds) async {
    try {
      final String today = await _timeSource.today();
      final VoiceQuota? stored = _store.read();
      final int maxClip = maxClipSeconds ??
          (stored != null && stored.date == today
              ? stored.maxClipSeconds
              : _configRepository.cached()?.voice?.maxClipSeconds ?? 0);
      await _store.write(
        VoiceQuota(date: today, secondsLeft: math.max(0, secondsLeft), maxClipSeconds: maxClip),
      );
    } catch (_) {}
  }

  /// First two letters of a locale id (`en_US`, `ar-EG`), lowercased, as the
  /// relay's `^[a-z]{2}$` language query requires.
  static String _languageOf(String? localeId) {
    if (localeId == null || localeId.length < 2) return _defaultLanguage;
    final String code = localeId.substring(0, 2).toLowerCase();
    return RegExp(r'^[a-z]{2}$').hasMatch(code) ? code : _defaultLanguage;
  }
}
