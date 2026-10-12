// PLAN_07 D11: `insights_assisted` is a new wire field. An older worker, or
// a stored `rawJson` from before it existed, omits it, and that must read as
// "nothing was assisted" rather than throw.
import 'package:dry_run/core/network/dto/judge_dto.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _json({List<String>? assisted}) => <String, dynamic>{
      'matched_approach': 'two_pointer_scan',
      'matched_verdict': 'acceptable',
      'insights_hit': <String>['a', 'b'],
      'insights_missed': <String>[],
      'wrong_turns_taken': <String>[],
      'complexity': <String, dynamic>{
        'user_claimed_time': null,
        'user_claimed_space': null,
        'reference_time': 'O(n)',
        'reference_space': 'O(1)',
        'assessment': 'not_stated',
      },
      'verdict': 'pass',
      'confidence': 0.8,
      'feedback': 'Solid.',
      'editorial': 'Use two pointers.',
      'insights_assisted': ?assisted,
    };

void main() {
  group('AssessmentDto.insightsAssisted', () {
    test('parses insights_assisted when the worker sends it', () {
      final AssessmentDto dto = AssessmentDto.fromJson(_json(assisted: <String>['a']));
      expect(dto.insightsAssisted, <String>['a']);
      expect(dto.insightsHit, <String>['a', 'b']);
    });

    test('parses to an empty list when the field is absent', () {
      final AssessmentDto dto = AssessmentDto.fromJson(_json());
      expect(dto.insightsAssisted, isEmpty);
    });
  });
}
