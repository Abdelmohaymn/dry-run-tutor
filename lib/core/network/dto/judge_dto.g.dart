// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'judge_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

JudgeRequestDto _$JudgeRequestDtoFromJson(Map<String, dynamic> json) =>
    JudgeRequestDto(
      problemId: json['problem_id'] as String,
      conversation: (json['conversation'] as List<dynamic>)
          .map((e) => TurnDto.fromJson(e as Map<String, dynamic>))
          .toList(),
      endedBy: json['ended_by'] as String,
      revealAtIndex: (json['reveal_at_index'] as num?)?.toInt(),
    );

Map<String, dynamic> _$JudgeRequestDtoToJson(JudgeRequestDto instance) =>
    <String, dynamic>{
      'problem_id': instance.problemId,
      'conversation': instance.conversation.map((e) => e.toJson()).toList(),
      'ended_by': instance.endedBy,
      'reveal_at_index': ?instance.revealAtIndex,
    };

ComplexityDto _$ComplexityDtoFromJson(Map<String, dynamic> json) =>
    ComplexityDto(
      userClaimedTime: json['user_claimed_time'] as String?,
      userClaimedSpace: json['user_claimed_space'] as String?,
      referenceTime: json['reference_time'] as String,
      referenceSpace: json['reference_space'] as String,
      assessment: json['assessment'] as String,
    );

Map<String, dynamic> _$ComplexityDtoToJson(ComplexityDto instance) =>
    <String, dynamic>{
      'user_claimed_time': instance.userClaimedTime,
      'user_claimed_space': instance.userClaimedSpace,
      'reference_time': instance.referenceTime,
      'reference_space': instance.referenceSpace,
      'assessment': instance.assessment,
    };

AssessmentDto _$AssessmentDtoFromJson(Map<String, dynamic> json) =>
    AssessmentDto(
      matchedApproach: json['matched_approach'] as String,
      matchedVerdict: json['matched_verdict'] as String,
      insightsHit: (json['insights_hit'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      insightsMissed: (json['insights_missed'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      wrongTurnsTaken: (json['wrong_turns_taken'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      complexity: ComplexityDto.fromJson(
        json['complexity'] as Map<String, dynamic>,
      ),
      verdict: json['verdict'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      feedback: json['feedback'] as String,
      editorial: json['editorial'] as String,
    );

Map<String, dynamic> _$AssessmentDtoToJson(AssessmentDto instance) =>
    <String, dynamic>{
      'matched_approach': instance.matchedApproach,
      'matched_verdict': instance.matchedVerdict,
      'insights_hit': instance.insightsHit,
      'insights_missed': instance.insightsMissed,
      'wrong_turns_taken': instance.wrongTurnsTaken,
      'complexity': instance.complexity.toJson(),
      'verdict': instance.verdict,
      'confidence': instance.confidence,
      'feedback': instance.feedback,
      'editorial': instance.editorial,
    };
