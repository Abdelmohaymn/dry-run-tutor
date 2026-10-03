import 'package:json_annotation/json_annotation.dart';

part 'error_dto.g.dart';

/// The inner `error` object of `openapi.yaml#Error` — identical whether it
/// arrived as a non-2xx JSON body or as an SSE `error` frame's `data:`
/// payload (research.md R-004). See `relay_error_mapper.dart` for the one
/// function that turns this into a [RelayError].
@JsonSerializable(fieldRename: FieldRename.snake)
class ErrorBodyDto {
  ErrorBodyDto({
    required this.code,
    required this.message,
    required this.retryable,
    this.retryAfterMs,
  });

  factory ErrorBodyDto.fromJson(Map<String, dynamic> json) => _$ErrorBodyDtoFromJson(json);

  /// One of the eleven closed catalogue codes.
  final String code;

  /// Written by the relay, safe to show verbatim — the app uses its own
  /// ARB copy instead (contracts/error-copy.md), but this field is kept
  /// for completeness and for logging (redacted).
  final String message;
  final bool retryable;

  /// Present only when [retryable] is true and a delay is known.
  final int? retryAfterMs;

  Map<String, dynamic> toJson() => _$ErrorBodyDtoToJson(this);
}

/// The full envelope — `openapi.yaml#Error`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ErrorDto {
  ErrorDto({required this.error});

  factory ErrorDto.fromJson(Map<String, dynamic> json) => _$ErrorDtoFromJson(json);

  final ErrorBodyDto error;

  Map<String, dynamic> toJson() => _$ErrorDtoToJson(this);
}
