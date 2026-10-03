// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'turn_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TurnDto _$TurnDtoFromJson(Map<String, dynamic> json) =>
    TurnDto(role: json['role'] as String, text: json['text'] as String);

Map<String, dynamic> _$TurnDtoToJson(TurnDto instance) => <String, dynamic>{
  'role': instance.role,
  'text': instance.text,
};
