import 'package:dry_run/core/network/dto/chat_dto.dart';
import 'package:dry_run/features/chat/data/turn_event_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _meta([Map<String, Object?> extra = const <String, Object?>{}]) => <String, Object?>{
      'turn_index': 3,
      'turns_remaining': 12,
      'hints_revealed': 0,
      'hints_remaining': 6,
      'session_ended': null,
      'leak_blocked': false,
      ...extra,
    };

void main() {
  test('ready_to_finish true reaches the counters', () {
    expect(countersFromMetaDto(MetaFrameDto.fromJson(_meta(<String, Object?>{'ready_to_finish': true}))).readyToFinish, isTrue);
  });

  test('an absent ready_to_finish (no check ran, or an older relay) is false', () {
    expect(countersFromMetaDto(MetaFrameDto.fromJson(_meta())).readyToFinish, isFalse);
  });

  test('finish_offer_dismissed is sent only when true', () {
    expect(ChatRequestDto(problemId: 'vp-0001', messages: const []).toJson(), isNot(contains('finish_offer_dismissed')));
    expect(
      ChatRequestDto(problemId: 'vp-0001', messages: const [], finishOfferDismissed: true).toJson()['finish_offer_dismissed'],
      isTrue,
    );
  });
}
