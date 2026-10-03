// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'problem_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProblemExampleDto _$ProblemExampleDtoFromJson(Map<String, dynamic> json) {
  $checkKeys(json, allowedKeys: const ['input', 'output', 'explanation']);
  return ProblemExampleDto(
    input: json['input'] as String,
    output: json['output'] as String,
    explanation: json['explanation'] as String?,
  );
}

Map<String, dynamic> _$ProblemExampleDtoToJson(ProblemExampleDto instance) =>
    <String, dynamic>{
      'input': instance.input,
      'output': instance.output,
      'explanation': instance.explanation,
    };

PublicHalfDto _$PublicHalfDtoFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    allowedKeys: const [
      'schema_version',
      'id',
      'date',
      'title',
      'ramp',
      'difficulty',
      'tags',
      'source',
      'statement',
      'constraints',
      'examples',
      'est_speak_seconds',
      'collections',
      'glossary_terms',
      'hint_count',
    ],
  );
  return PublicHalfDto(
    schemaVersion: (json['schema_version'] as num).toInt(),
    id: json['id'] as String,
    date: json['date'] as String?,
    title: json['title'] as String,
    ramp: json['ramp'] as String,
    difficulty: (json['difficulty'] as num?)?.toInt(),
    tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
    source: json['source'] as String,
    statement: json['statement'] as String,
    constraints: (json['constraints'] as List<dynamic>)
        .map((e) => e as String)
        .toList(),
    examples: (json['examples'] as List<dynamic>?)
        ?.map((e) => ProblemExampleDto.fromJson(e as Map<String, dynamic>))
        .toList(),
    estSpeakSeconds: (json['est_speak_seconds'] as num).toInt(),
    collections: (json['collections'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    glossaryTerms: (json['glossary_terms'] as List<dynamic>)
        .map((e) => e as String)
        .toList(),
    hintCount: (json['hint_count'] as num?)?.toInt(),
  );
}

Map<String, dynamic> _$PublicHalfDtoToJson(PublicHalfDto instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'id': instance.id,
      'date': instance.date,
      'title': instance.title,
      'ramp': instance.ramp,
      'difficulty': instance.difficulty,
      'tags': instance.tags,
      'source': instance.source,
      'statement': instance.statement,
      'constraints': instance.constraints,
      'examples': instance.examples?.map((e) => e.toJson()).toList(),
      'est_speak_seconds': instance.estSpeakSeconds,
      'collections': instance.collections,
      'glossary_terms': instance.glossaryTerms,
      'hint_count': instance.hintCount,
    };

ManifestDto _$ManifestDtoFromJson(Map<String, dynamic> json) => ManifestDto(
  schemaVersion: (json['schema_version'] as num).toInt(),
  generated: json['generated'] as String,
  problems: (json['problems'] as List<dynamic>)
      .map((e) => PublicHalfDto.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$ManifestDtoToJson(ManifestDto instance) =>
    <String, dynamic>{
      'schema_version': instance.schemaVersion,
      'generated': instance.generated,
      'problems': instance.problems.map((e) => e.toJson()).toList(),
    };
