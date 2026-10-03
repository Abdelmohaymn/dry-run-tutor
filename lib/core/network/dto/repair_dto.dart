import 'package:json_annotation/json_annotation.dart';

part 'repair_dto.g.dart';

/// `POST /v1/repair` request body. Exactly two fields (contracts/repair-endpoint.md).
@JsonSerializable(fieldRename: FieldRename.snake)
class RepairRequestDto {
  RepairRequestDto({required this.problemId, required this.transcript});

  factory RepairRequestDto.fromJson(Map<String, dynamic> json) => _$RepairRequestDtoFromJson(json);

  final String problemId;
  final String transcript;

  Map<String, dynamic> toJson() => _$RepairRequestDtoToJson(this);
}

/// `POST /v1/repair` response body.
@JsonSerializable(fieldRename: FieldRename.snake)
class RepairResponseDto {
  RepairResponseDto({required this.repaired, required this.changed});

  factory RepairResponseDto.fromJson(Map<String, dynamic> json) => _$RepairResponseDtoFromJson(json);

  final String repaired;
  final bool changed;

  Map<String, dynamic> toJson() => _$RepairResponseDtoToJson(this);
}
