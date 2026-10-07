import 'package:json_annotation/json_annotation.dart';

part 'stt_dto.g.dart';

/// `POST /v1/stt` 200 response. Only the transcript and the device's
/// remaining budget; the Worker never echoes audio or the Groq payload.
@JsonSerializable(fieldRename: FieldRename.snake)
class SttResponseDto {
  SttResponseDto({
    required this.text,
    required this.secondsLeft,
    required this.maxClipSeconds,
  });

  factory SttResponseDto.fromJson(Map<String, dynamic> json) => _$SttResponseDtoFromJson(json);

  /// The transcript. Never persisted by the Worker (D1 holds counters only).
  final String text;

  /// Seconds this device still has today (UTC day), after this clip was charged.
  final int secondsLeft;

  /// Longest clip the recorder may capture, as the Worker currently enforces it.
  final int maxClipSeconds;

  Map<String, dynamic> toJson() => _$SttResponseDtoToJson(this);
}

/// Why the Worker declined to transcribe a clip, mapped from its error code.
/// What the app does next for each value is in the plan's retry table
/// (PLAN_01_VOICE_GROQ_STT.md, "Why the server refuses a clip").
enum SttRefusal {
  /// `VOICE_EXHAUSTED` (429): the device's seconds for today are already
  /// used (e.g. a stale local count after a reinstall). Clip is deleted;
  /// the user is told to say it again and speech recognition falls back to
  /// on-device until UTC midnight.
  exhausted,

  /// `VOICE_UNAVAILABLE` (503): Groq's own limit (429) or a misconfigured
  /// key (401), or voice is switched off in config. Nothing is charged, the
  /// clip is deleted, and the app pauses cloud for 10 minutes so the next
  /// mic tap goes on-device.
  unavailable,

  /// `VOICE_BUSY` (503, `retryable: true`): Groq 5xx, timeout or malformed
  /// body. Nothing is charged and the clip is **kept**, so "Try again"
  /// re-uploads it without making the user speak again. Any other refusal
  /// on that retry follows its own row.
  busy,
}

/// Thrown by `RelayClient.stt()` when the Worker refuses a clip with one of
/// the voice error codes. Other failures (offline, timeout, `BAD_REQUEST`)
/// keep their existing exception types: a transport failure also keeps the
/// clip for "Try again"; `BAD_REQUEST` deletes it and stays on cloud if
/// seconds remain.
class SttRefusedException implements Exception {
  const SttRefusedException(this.refusal);

  final SttRefusal refusal;

  @override
  String toString() => 'SttRefusedException(${refusal.name})';
}
