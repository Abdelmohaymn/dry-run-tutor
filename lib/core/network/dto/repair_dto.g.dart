// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repair_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RepairRequestDto _$RepairRequestDtoFromJson(Map<String, dynamic> json) =>
    RepairRequestDto(
      problemId: json['problem_id'] as String,
      transcript: json['transcript'] as String,
    );

Map<String, dynamic> _$RepairRequestDtoToJson(RepairRequestDto instance) =>
    <String, dynamic>{
      'problem_id': instance.problemId,
      'transcript': instance.transcript,
    };

RepairResponseDto _$RepairResponseDtoFromJson(Map<String, dynamic> json) =>
    RepairResponseDto(
      repaired: json['repaired'] as String,
      changed: json['changed'] as bool,
    );

Map<String, dynamic> _$RepairResponseDtoToJson(RepairResponseDto instance) =>
    <String, dynamic>{
      'repaired': instance.repaired,
      'changed': instance.changed,
    };
