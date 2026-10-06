import 'package:json_annotation/json_annotation.dart';

part 'install_dto.g.dart';

/// `POST /v1/install` request. Sent exactly once, at first launch.
@JsonSerializable(fieldRename: FieldRename.snake)
class InstallRequestDto {
  InstallRequestDto({required this.platform, required this.deviceId});

  factory InstallRequestDto.fromJson(Map<String, dynamic> json) =>
      _$InstallRequestDtoFromJson(json);

  final String platform;
  final String deviceId;

  Map<String, dynamic> toJson() => _$InstallRequestDtoToJson(this);
}

/// `POST /v1/install` response — the signed identity sent as
/// `X-Install-Id` on every later authenticated call.
@JsonSerializable(fieldRename: FieldRename.snake)
class InstallResponseDto {
  InstallResponseDto({required this.installId});

  factory InstallResponseDto.fromJson(Map<String, dynamic> json) =>
      _$InstallResponseDtoFromJson(json);

  final String installId;

  Map<String, dynamic> toJson() => _$InstallResponseDtoToJson(this);
}
