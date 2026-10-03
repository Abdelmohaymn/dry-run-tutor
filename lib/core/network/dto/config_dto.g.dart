// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatConfigDto _$ChatConfigDtoFromJson(Map<String, dynamic> json) =>
    ChatConfigDto(
      turnCap: (json['turn_cap'] as num).toInt(),
      wrapUpAtTurn: (json['wrap_up_at_turn'] as num).toInt(),
      minTurnChars: (json['min_turn_chars'] as num).toInt(),
    );

Map<String, dynamic> _$ChatConfigDtoToJson(ChatConfigDto instance) =>
    <String, dynamic>{
      'turn_cap': instance.turnCap,
      'wrap_up_at_turn': instance.wrapUpAtTurn,
      'min_turn_chars': instance.minTurnChars,
    };

TrialConfigDto _$TrialConfigDtoFromJson(Map<String, dynamic> json) =>
    TrialConfigDto(turnCap: (json['turn_cap'] as num).toInt());

Map<String, dynamic> _$TrialConfigDtoToJson(TrialConfigDto instance) =>
    <String, dynamic>{'turn_cap': instance.turnCap};

RepairConfigDto _$RepairConfigDtoFromJson(Map<String, dynamic> json) =>
    RepairConfigDto(
      enabled: json['enabled'] as bool,
      minChars: (json['min_chars'] as num).toInt(),
      timeoutMs: (json['timeout_ms'] as num).toInt(),
    );

Map<String, dynamic> _$RepairConfigDtoToJson(RepairConfigDto instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'min_chars': instance.minChars,
      'timeout_ms': instance.timeoutMs,
    };

RotationConfigDto _$RotationConfigDtoFromJson(Map<String, dynamic> json) =>
    RotationConfigDto(
      startProblemId: json['start_problem_id'] as String,
      anchorDate: json['anchor_date'] as String,
    );

Map<String, dynamic> _$RotationConfigDtoToJson(RotationConfigDto instance) =>
    <String, dynamic>{
      'start_problem_id': instance.startProblemId,
      'anchor_date': instance.anchorDate,
    };

ConfigDto _$ConfigDtoFromJson(Map<String, dynamic> json) => ConfigDto(
  minSupportedVersion: json['min_supported_version'] as String,
  killedProblemIds: (json['killed_problem_ids'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  contentManifestUrl: json['content_manifest_url'] as String,
  chat: ChatConfigDto.fromJson(json['chat'] as Map<String, dynamic>),
  trial: TrialConfigDto.fromJson(json['trial'] as Map<String, dynamic>),
  updateUrl: json['update_url'] as String?,
  keyedProviders: (json['keyed_providers'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  repair: json['repair'] == null
      ? null
      : RepairConfigDto.fromJson(json['repair'] as Map<String, dynamic>),
  rotation: json['rotation'] == null
      ? null
      : RotationConfigDto.fromJson(json['rotation'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ConfigDtoToJson(ConfigDto instance) => <String, dynamic>{
  'min_supported_version': instance.minSupportedVersion,
  'update_url': instance.updateUrl,
  'killed_problem_ids': instance.killedProblemIds,
  'content_manifest_url': instance.contentManifestUrl,
  'chat': instance.chat.toJson(),
  'trial': instance.trial.toJson(),
  'keyed_providers': instance.keyedProviders,
  'repair': instance.repair?.toJson(),
  'rotation': instance.rotation?.toJson(),
};
