import 'package:json_annotation/json_annotation.dart';

part 'problem_dto.g.dart';

/// One entry of `PublicHalf.examples`. Optional in the manifest — a
/// problem authored before examples existed simply carries none.
@JsonSerializable(fieldRename: FieldRename.snake, disallowUnrecognizedKeys: true)
class ProblemExampleDto {
  ProblemExampleDto({required this.input, required this.output, this.explanation});

  factory ProblemExampleDto.fromJson(Map<String, dynamic> json) =>
      _$ProblemExampleDtoFromJson(json);

  final String input;
  final String output;
  final String? explanation;

  Map<String, dynamic> toJson() => _$ProblemExampleDtoToJson(this);
}

/// `problem.schema.json#/$defs/PublicHalf` — field for field, and nothing
/// else. `disallowUnrecognizedKeys: true` makes an unknown key (i.e. a
/// private field that leaked into the public manifest) a parse failure
/// rather than a silently-stored extra column — the second lock on the
/// door the server-side manifest build already asserts shut.
@JsonSerializable(fieldRename: FieldRename.snake, disallowUnrecognizedKeys: true)
class PublicHalfDto {
  PublicHalfDto({
    required this.schemaVersion,
    required this.id,
    this.date,
    required this.title,
    required this.ramp,
    this.difficulty,
    required this.tags,
    required this.source,
    required this.statement,
    required this.constraints,
    this.examples,
    required this.estSpeakSeconds,
    this.collections,
    required this.glossaryTerms,
    this.hintCount,
  });

  factory PublicHalfDto.fromJson(Map<String, dynamic> json) => _$PublicHalfDtoFromJson(json);

  final int schemaVersion;
  final String id;
  final String? date;
  final String title;

  /// `easy` | `medium` | `hard`.
  final String ramp;
  final int? difficulty;
  final List<String> tags;
  final String source;
  final String statement;
  final List<String> constraints;

  /// Optional: `examples` is not a required field of `PublicHalf`.
  final List<ProblemExampleDto>? examples;
  final int estSpeakSeconds;
  final List<String>? collections;

  /// Public in schema v2 specifically so transcript review can offer
  /// tap-to-fix chips (FR-012a).
  final List<String> glossaryTerms;

  /// Build-injected, never authored. Nullable here only because an
  /// authoring-time file may omit it before the content build computes
  /// it; the manifest the app actually fetches always carries it.
  final int? hintCount;

  Map<String, dynamic> toJson() => _$PublicHalfDtoToJson(this);
}

/// `GET /v1/content/manifest.json` response.
@JsonSerializable(fieldRename: FieldRename.snake)
class ManifestDto {
  ManifestDto({
    required this.schemaVersion,
    required this.generated,
    required this.problems,
  });

  factory ManifestDto.fromJson(Map<String, dynamic> json) => _$ManifestDtoFromJson(json);

  final int schemaVersion;
  final String generated;
  final List<PublicHalfDto> problems;

  Map<String, dynamic> toJson() => _$ManifestDtoToJson(this);
}
