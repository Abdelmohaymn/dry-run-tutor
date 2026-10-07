import 'dart:async';

import 'package:dry_run/features/cloud_voice/domain/cloud_voice_failure.dart';
import 'package:dry_run/features/cloud_voice/domain/cloud_voice_repository.dart';
import 'package:dry_run/features/voice/domain/recognition_event.dart';

/// A plain, scriptable [CloudVoiceRepository] — no recorder, no file, no
/// relay. Tests drive the recording stream by calling [emit] and
/// [closeStream], and script the other answers through the public fields.
class FakeCloudVoiceRepository implements CloudVoiceRepository {
  /// What [nextClipLimit] answers. `null` means the on-device path.
  Duration? clipLimitToReturn;

  /// What [retryUpload] answers. A queue is used so a test can script a
  /// first and a second retry differently; the last entry repeats.
  final List<RecognitionEvent> retryResults = <RecognitionEvent>[];

  @override
  bool hasPendingClip = false;

  StreamController<RecognitionEvent>? _controller;

  int nextClipLimitCalls = 0;
  final List<Duration> recordLimits = <Duration>[];
  int stopCalls = 0;
  int cancelCalls = 0;
  int discardPendingCalls = 0;
  int retryUploadCalls = 0;

  @override
  Future<Duration?> nextClipLimit() async {
    nextClipLimitCalls++;
    return clipLimitToReturn;
  }

  @override
  Stream<RecognitionEvent> record({required Duration limit}) {
    recordLimits.add(limit);
    _controller = StreamController<RecognitionEvent>();
    return _controller!.stream;
  }

  /// Pushes [event] into the stream the cubit is listening to.
  void emit(RecognitionEvent event) => _controller!.add(event);

  /// Emits a retryable failure the way the real repository does, and holds
  /// the clip.
  void emitRetryable() {
    hasPendingClip = true;
    emit(const RecognitionErrorEvent(CloudVoiceFailure.retryable, permanent: false));
  }

  /// Emits a non-retryable cloud failure ([reason] is a `CloudVoiceFailure`).
  void emitFailure(String reason) =>
      emit(RecognitionErrorEvent(reason, permanent: true));

  Future<void> closeStream() async => _controller?.close();

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<RecognitionEvent> retryUpload() async {
    retryUploadCalls++;
    if (retryResults.isEmpty) {
      throw StateError('FakeCloudVoiceRepository: no retryUpload result scripted');
    }
    final int index = retryUploadCalls <= retryResults.length ? retryUploadCalls - 1 : retryResults.length - 1;
    final RecognitionEvent result = retryResults[index];
    hasPendingClip = result is RecognitionErrorEvent && result.reason == CloudVoiceFailure.retryable;
    return result;
  }

  @override
  Future<void> discardPending() async {
    discardPendingCalls++;
    hasPendingClip = false;
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    hasPendingClip = false;
  }

  @override
  Future<void> sweepOrphanClips() async {}
}
