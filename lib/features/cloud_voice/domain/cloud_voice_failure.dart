/// `RecognitionErrorEvent.reason` values emitted by the cloud-voice path.
/// All share the `cloud_voice_` prefix so the cubit can tell them apart from
/// the on-device recogniser's own reasons with [isCloud].
abstract final class CloudVoiceFailure {
  /// Covers `VOICE_BUSY` and every transport failure (offline, dropped
  /// upload, timeout). The clip is kept; emitted with `permanent: false`.
  static const retryable = 'cloud_voice_retryable';

  /// Voice is off, or Groq refused the key or its own limit was hit
  /// (`VOICE_UNAVAILABLE`). The app falls back to on-device recognition.
  static const unavailable = 'cloud_voice_unavailable';

  /// The device's daily seconds are used up (`VOICE_EXHAUSTED`).
  static const exhausted = 'cloud_voice_exhausted';

  /// The relay could not use the clip (`BAD_REQUEST`) or an unexpected error
  /// occurred. The user is asked to say it again.
  static const rejected = 'cloud_voice_rejected';

  /// Microphone permission is missing or was revoked.
  static const permission = 'cloud_voice_permission';

  static bool isCloud(String reason) => reason.startsWith('cloud_voice_');
}
