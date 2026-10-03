import 'package:json_annotation/json_annotation.dart';

part 'event_dto.g.dart';

/// `event.schema.json#/properties/events/items`. `props` obeys the
/// schema's own limits (≤12 keys, scalars only, ≤64 chars, key names
/// matching `^[a-z][a-z0-9_]{0,31}$`) — `AnalyticsClient` validates
/// against those before an event is ever buffered, so by the time one
/// reaches this DTO it is already known-good.
@JsonSerializable(fieldRename: FieldRename.snake, includeIfNull: false)
class EventDto {
  EventDto({required this.name, required this.clientTs, this.props});

  factory EventDto.fromJson(Map<String, dynamic> json) => _$EventDtoFromJson(json);

  /// One of the 23 closed names.
  final String name;

  /// ISO-8601.
  final String clientTs;
  final Map<String, Object>? props;

  Map<String, dynamic> toJson() => _$EventDtoToJson(this);
}

/// `POST /v1/event` request body — up to 100 events per batch.
@JsonSerializable(fieldRename: FieldRename.snake)
class EventBatchDto {
  EventBatchDto({required this.events});

  factory EventBatchDto.fromJson(Map<String, dynamic> json) => _$EventBatchDtoFromJson(json);

  final List<EventDto> events;

  Map<String, dynamic> toJson() => _$EventBatchDtoToJson(this);
}
