// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EventDto _$EventDtoFromJson(Map<String, dynamic> json) => EventDto(
  name: json['name'] as String,
  clientTs: json['client_ts'] as String,
  props: (json['props'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as Object),
  ),
);

Map<String, dynamic> _$EventDtoToJson(EventDto instance) => <String, dynamic>{
  'name': instance.name,
  'client_ts': instance.clientTs,
  'props': ?instance.props,
};

EventBatchDto _$EventBatchDtoFromJson(Map<String, dynamic> json) =>
    EventBatchDto(
      events: (json['events'] as List<dynamic>)
          .map((e) => EventDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$EventBatchDtoToJson(EventBatchDto instance) =>
    <String, dynamic>{
      'events': instance.events.map((e) => e.toJson()).toList(),
    };
