// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatRequestDto _$ChatRequestDtoFromJson(Map<String, dynamic> json) =>
    ChatRequestDto(
      problemId: json['problem_id'] as String,
      messages: (json['messages'] as List<dynamic>)
          .map((e) => TurnDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: json['summary'] as String?,
      earlierLearnerTurns: (json['earlier_learner_turns'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hintRequested: json['hint_requested'] as bool?,
      solutionRequestCount: (json['solution_request_count'] as num?)?.toInt(),
      keyCheck: json['key_check'] as bool?,
      finishOfferDismissed: json['finish_offer_dismissed'] as bool?,
    );

Map<String, dynamic> _$ChatRequestDtoToJson(ChatRequestDto instance) =>
    <String, dynamic>{
      'problem_id': instance.problemId,
      'messages': instance.messages.map((e) => e.toJson()).toList(),
      'summary': ?instance.summary,
      'earlier_learner_turns': ?instance.earlierLearnerTurns,
      'hint_requested': ?instance.hintRequested,
      'solution_request_count': ?instance.solutionRequestCount,
      'key_check': ?instance.keyCheck,
      'finish_offer_dismissed': ?instance.finishOfferDismissed,
    };

MetaFrameDto _$MetaFrameDtoFromJson(Map<String, dynamic> json) {
  $checkKeys(
    json,
    requiredKeys: const [
      'turn_index',
      'turns_remaining',
      'hints_revealed',
      'hints_remaining',
      'session_ended',
      'leak_blocked',
    ],
    disallowNullValues: const [
      'turn_index',
      'turns_remaining',
      'hints_revealed',
      'hints_remaining',
      'leak_blocked',
    ],
  );
  return MetaFrameDto(
    turnIndex: (json['turn_index'] as num).toInt(),
    turnsRemaining: (json['turns_remaining'] as num).toInt(),
    hintsRevealed: (json['hints_revealed'] as num).toInt(),
    hintsRemaining: (json['hints_remaining'] as num).toInt(),
    sessionEnded: json['session_ended'] as String?,
    leakBlocked: json['leak_blocked'] as bool,
    summary: json['summary'] as String?,
    summaryCovers: (json['summary_covers'] as num?)?.toInt(),
    readyToFinish: json['ready_to_finish'] as bool?,
  );
}

Map<String, dynamic> _$MetaFrameDtoToJson(MetaFrameDto instance) =>
    <String, dynamic>{
      'turn_index': instance.turnIndex,
      'turns_remaining': instance.turnsRemaining,
      'hints_revealed': instance.hintsRevealed,
      'hints_remaining': instance.hintsRemaining,
      'session_ended': instance.sessionEnded,
      'leak_blocked': instance.leakBlocked,
      'summary': instance.summary,
      'summary_covers': instance.summaryCovers,
      'ready_to_finish': instance.readyToFinish,
    };
