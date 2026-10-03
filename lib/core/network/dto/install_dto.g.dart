// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'install_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

InstallRequestDto _$InstallRequestDtoFromJson(Map<String, dynamic> json) =>
    InstallRequestDto(installUuid: json['install_uuid'] as String);

Map<String, dynamic> _$InstallRequestDtoToJson(InstallRequestDto instance) =>
    <String, dynamic>{'install_uuid': instance.installUuid};

InstallResponseDto _$InstallResponseDtoFromJson(Map<String, dynamic> json) =>
    InstallResponseDto(installId: json['install_id'] as String);

Map<String, dynamic> _$InstallResponseDtoToJson(InstallResponseDto instance) =>
    <String, dynamic>{'install_id': instance.installId};
