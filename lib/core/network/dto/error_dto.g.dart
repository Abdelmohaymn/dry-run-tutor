// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'error_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ErrorBodyDto _$ErrorBodyDtoFromJson(Map<String, dynamic> json) => ErrorBodyDto(
  code: json['code'] as String,
  message: json['message'] as String,
  retryable: json['retryable'] as bool,
  retryAfterMs: (json['retry_after_ms'] as num?)?.toInt(),
);

Map<String, dynamic> _$ErrorBodyDtoToJson(ErrorBodyDto instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'retryable': instance.retryable,
      'retry_after_ms': instance.retryAfterMs,
    };

ErrorDto _$ErrorDtoFromJson(Map<String, dynamic> json) => ErrorDto(
  error: ErrorBodyDto.fromJson(json['error'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ErrorDtoToJson(ErrorDto instance) => <String, dynamic>{
  'error': instance.error.toJson(),
};
