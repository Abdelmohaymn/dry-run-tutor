import 'package:json_annotation/json_annotation.dart';

part 'turn_dto.g.dart';

/// One turn of a replayed conversation — `openapi.yaml#Turn`. `role` is
/// the app's own wire vocabulary (`user` | `tutor`), never the provider's.
@JsonSerializable(fieldRename: FieldRename.snake)
class TurnDto {
  TurnDto({required this.role, required this.text});

  factory TurnDto.fromJson(Map<String, dynamic> json) => _$TurnDtoFromJson(json);

  final String role;
  final String text;

  Map<String, dynamic> toJson() => _$TurnDtoToJson(this);
}
