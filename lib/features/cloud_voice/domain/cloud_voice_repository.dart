import '../../voice/domain/recognition_event.dart';

/// Records a short clip and turns it into text through our own relay
/// (`POST /v1/stt`), which forwards it to the speech provider.
///
/// Audio goes only to our relay, never to any other host. The recorded clip
/// is deleted on success, on a non-retryable answer, on [discardPending], and
/// on [cancel]. It is kept only after a retryable failure, so the user can
/// tap "Try again" without speaking again; it never survives an app restart
/// ([sweepOrphanClips] removes any leftover).
///
/// Pure Dart: no file, recorder, or HTTP types appear in this interface.
/// Implementations live under `lib/features/cloud_voice/data/`.
abstract interface class CloudVoiceRepository {
  /// How long the next clip may run, or `null` to use on-device recognition
  /// (voice off, no seconds left, offline, or in the post-unavailable
  /// cooldown). Never throws.
  Future<Duration?> nextClipLimit();

  /// Starts recording, capped at [limit]. Emits [LevelEvent]s while
  /// recording. After [stop], emits exactly one [FinalTextEvent] or one
  /// [RecognitionErrorEvent] whose reason is a `CloudVoiceFailure`, then
  /// closes. `retryable` is emitted with `permanent: false`; every other
  /// reason with `permanent: true`.
  Stream<RecognitionEvent> record({required Duration limit});

  /// Stops recording and uploads the clip.
  Future<void> stop();

  /// True only after a `retryable` outcome, while the clip is kept.
  bool get hasPendingClip;

  /// Re-sends the kept clip's bytes. Returns a [FinalTextEvent] or a
  /// [RecognitionErrorEvent] under the same reason rules as [record].
  /// Throws [StateError] when there is no pending clip.
  Future<RecognitionEvent> retryUpload();

  /// Deletes the kept clip. No-op when there is none.
  Future<void> discardPending();

  /// Stops recording if active and deletes any recording or pending clip.
  /// Nothing is uploaded, and the stream closes with no terminal event.
  Future<void> cancel();

  /// Deletes every leftover `stt_*.m4a` in the temp directory that is not the
  /// current pending clip. Called once at startup.
  Future<void> sweepOrphanClips();
}
