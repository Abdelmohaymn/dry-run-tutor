import 'package:json_annotation/json_annotation.dart';

import 'turn_dto.dart';

part 'chat_dto.g.dart';

/// `POST /v1/chat` (and `/v1/trial` mode=chat) request body.
///
/// `messages` carries only the turns not covered by `summary` (FR-020),
/// capped at 40 by the wire schema — enforcing that cap is the caller's
/// job (`SessionRepositoryImpl`), not this DTO's.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class ChatRequestDto {
  ChatRequestDto({
    required this.problemId,
    required this.messages,
    this.summary,
    this.earlierLearnerTurns,
    this.hintRequested,
    this.solutionRequestCount,
    this.keyCheck,
  });

  factory ChatRequestDto.fromJson(Map<String, dynamic> json) => _$ChatRequestDtoFromJson(json);

  final String problemId;
  final List<TurnDto> messages;
  final String? summary;

  /// The learner's own turns already inside [summary], oldest first. The
  /// relay reads them only to know which words the learner has said and
  /// which insights they have reached; they never reach the provider.
  final List<String>? earlierLearnerTurns;

  /// The learner explicitly asked for a hint. Costs no turn, no provider
  /// call (FR-027).
  final bool? hintRequested;

  /// A hint, not an authority — the server keeps its own count and this
  /// may raise it by at most one per accepted turn (Principle III).
  final int? solutionRequestCount;

  /// Checks a key the learner is saving. The relay makes one tiny
  /// provider call and spends no turn. `/v1/chat` only.
  final bool? keyCheck;

  Map<String, dynamic> toJson() => _$ChatRequestDtoToJson(this);
}

/// The `meta` frame — `openapi.yaml#MetaFrame`. **No defaults.** Every
/// field bar `summary` is required on the wire, and this class mirrors
/// that: a missing field is a parse failure (`json_serializable` throws),
/// surfaced as `MissingMetaFailure` by the caller, never a silently-zeroed
/// counter. FR-019 / research.md R-007.
@JsonSerializable(fieldRename: FieldRename.snake)
class MetaFrameDto {
  MetaFrameDto({
    required this.turnIndex,
    required this.turnsRemaining,
    required this.hintsRevealed,
    required this.hintsRemaining,
    required this.sessionEnded,
    required this.leakBlocked,
    this.summary,
    this.summaryCovers,
  });

  factory MetaFrameDto.fromJson(Map<String, dynamic> json) => _$MetaFrameDtoFromJson(json);

  @JsonKey(required: true, disallowNullValue: true)
  final int turnIndex;
  @JsonKey(required: true, disallowNullValue: true)
  final int turnsRemaining;
  @JsonKey(required: true, disallowNullValue: true)
  final int hintsRevealed;
  @JsonKey(required: true, disallowNullValue: true)
  final int hintsRemaining;

  /// `user` | `cap` | `solution` | `null`. Server-derived only. The one
  /// required field allowed to be `null` on the wire — `null` itself is
  /// meaningful ("not ended yet"), so only the *key's absence* is a
  /// parse failure here.
  @JsonKey(required: true)
  final String? sessionEnded;
  @JsonKey(required: true, disallowNullValue: true)
  final bool leakBlocked;

  /// Present only when this turn condensed history (FR-020).
  final String? summary;

  /// Present exactly when [summary] is: how many of the request's leading
  /// `messages` the new summary covers. The rest must be sent again.
  /// Absent from a relay older than this field.
  final int? summaryCovers;

  Map<String, dynamic> toJson() => _$MetaFrameDtoToJson(this);
}
