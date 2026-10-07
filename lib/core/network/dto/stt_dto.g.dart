// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SttResponseDto _$SttResponseDtoFromJson(Map<String, dynamic> json) =>
    SttResponseDto(
      text: json['text'] as String,
      secondsLeft: (json['seconds_left'] as num).toInt(),
      maxClipSeconds: (json['max_clip_seconds'] as num).toInt(),
    );

Map<String, dynamic> _$SttResponseDtoToJson(SttResponseDto instance) =>
    <String, dynamic>{
      'text': instance.text,
      'seconds_left': instance.secondsLeft,
      'max_clip_seconds': instance.maxClipSeconds,
    };
