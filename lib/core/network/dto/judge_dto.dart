import 'package:json_annotation/json_annotation.dart';

import 'turn_dto.dart';

part 'judge_dto.g.dart';

/// `POST /v1/judge` (and `/v1/trial` mode=judge) request body.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class JudgeRequestDto {
  JudgeRequestDto({
    required this.problemId,
    required this.conversation,
    required this.endedBy,
    this.revealAtIndex,
  });

  factory JudgeRequestDto.fromJson(Map<String, dynamic> json) => _$JudgeRequestDtoFromJson(json);

  final String problemId;
  final List<TurnDto> conversation;

  /// `user` | `cap` | `solution`, taken from `meta.session_ended`.
  final String endedBy;

  /// Required when [endedBy] is `solution` (FR-033).
  final int? revealAtIndex;

  Map<String, dynamic> toJson() => _$JudgeRequestDtoToJson(this);
}

/// `openapi.yaml#Assessment.complexity`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ComplexityDto {
  ComplexityDto({
    required this.userClaimedTime,
    required this.userClaimedSpace,
    required this.referenceTime,
    required this.referenceSpace,
    required this.assessment,
  });

  factory ComplexityDto.fromJson(Map<String, dynamic> json) => _$ComplexityDtoFromJson(json);

  final String? userClaimedTime;
  final String? userClaimedSpace;
  final String referenceTime;
  final String referenceSpace;

  /// `correct` | `mismatched` | `not_stated`.
  final String assessment;

  Map<String, dynamic> toJson() => _$ComplexityDtoToJson(this);
}

/// The full `/v1/judge` response — `openapi.yaml#Assessment`. Nothing
/// here is ever constructed client-side (Principle II); this DTO only
/// ever flows in from the wire.
@JsonSerializable(fieldRename: FieldRename.snake)
class AssessmentDto {
  AssessmentDto({
    required this.matchedApproach,
    required this.matchedVerdict,
    required this.insightsHit,
    required this.insightsAssisted,
    required this.insightsMissed,
    required this.wrongTurnsTaken,
    required this.complexity,
    required this.verdict,
    required this.confidence,
    required this.feedback,
    required this.editorial,
  });

  factory AssessmentDto.fromJson(Map<String, dynamic> json) => _$AssessmentDtoFromJson(json);

  /// An authored approach key, or `"none"` — a designed state, not an
  /// error (Principle II).
  final String matchedApproach;

  /// `optimal` | `acceptable` | `suboptimal` | `wrong` | `none`.
  final String matchedVerdict;
  final List<String> insightsHit;

  /// The subset of [insightsHit] the learner reached by accepting an idea
  /// the tutor put into words (PLAN_07 D11). Absent from an older worker's
  /// response, or a stored `rawJson` from before the field existed, which
  /// reads as "nothing was assisted".
  @JsonKey(defaultValue: <String>[])
  final List<String> insightsAssisted;
  final List<String> insightsMissed;
  final List<String> wrongTurnsTaken;
  final ComplexityDto complexity;

  /// Post-override value — `mapVerdict()` won over the model server-side.
  /// The app displays this; it never re-derives it.
  final String verdict;
  final double confidence;
  final String feedback;

  /// Markdown for the reveal. The only path by which private content is
  /// ever released (FR-032).
  final String editorial;

  Map<String, dynamic> toJson() => _$AssessmentDtoToJson(this);
}
