/// What `RecognitionService.listen()` streams (contracts/repositories.md).
/// Sealed so `RecordingScreen`/`DailySessionCubit` switch exhaustively —
/// there is no method here that returns audio and no method that writes a
/// file; that absence is the implementation of Constitution VII and
/// FR-011.
sealed class RecognitionEvent {
  const RecognitionEvent();
}

/// An interim transcript, updated as recognition proceeds.
class PartialTextEvent extends RecognitionEvent {
  const PartialTextEvent(this.text);

  final String text;
}

/// Normalised input amplitude, `0.0`–`1.0` — what the waveform renders
/// (research.md R-002). Never audio: a level is a single float, not a
/// sample buffer.
class LevelEvent extends RecognitionEvent {
  const LevelEvent(this.level);

  final double level;
}

/// The recognizer's own final transcript for this listen session.
class FinalTextEvent extends RecognitionEvent {
  const FinalTextEvent(this.text);

  final String text;
}

/// A recognition-layer failure (device error, permission revoked
/// mid-session, no speech detected). [permanent] mirrors
/// `speech_to_text`'s own distinction: a permanent error means recognition
/// cannot continue until it is resolved outside this listen session.
class RecognitionErrorEvent extends RecognitionEvent {
  const RecognitionErrorEvent(this.reason, {required this.permanent});

  final String reason;
  final bool permanent;

  /// The recogniser has no on-device pack for the language it was asked
  /// for. `_resolveLocaleId` avoids this where it can, but the platform is
  /// the final authority and can still refuse at listen time — and when it
  /// does, this is FR-011a's `languageUnavailable`, which has a screen and a
  /// route to the fix, not a generic "nothing was heard".
  bool get isLanguageUnavailable =>
      reason == 'error_language_unavailable' || reason == 'error_language_not_supported';
}
