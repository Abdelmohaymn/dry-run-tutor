// event.schema.json's name set is closed at 23 (research.md R-006);
// EventName must match it exactly so an unknown name is a compile error
// rather than a 400 discovered in production. The no-text/no-key/no-PII
// assertion itself lives in T030's no_key_leak_test and is not duplicated
// here (FR-050).
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:flutter_test/flutter_test.dart';

const Set<String> _schemaNames = <String>{
  'app_open',
  'onboarding_started',
  'onboarding_done',
  'key_prompt_shown',
  'key_entry_started',
  'key_saved',
  'trial_session_started',
  'trial_session_completed',
  'daily_opened',
  'chat_turn_sent',
  'transcript_edited',
  'hint_revealed',
  'hint_ladder_exhausted',
  'session_ended',
  'assessment_shown',
  'assessment_disputed',
  'reveal_shown',
  'share_card_shared',
  'streak_advanced',
  'assessment_verdict_overridden',
  'tutor_leak_blocked',
  'config_fetch_failed',
  'offline_queue_drained',
  'finish_offer_shown',
  'finish_offer_accepted',
  'finish_offer_dismissed',
};

void main() {
  test('EventName has exactly 26 members', () {
    expect(EventName.values, hasLength(26));
  });

  test('EventName.wireName matches the closed schema set exactly', () {
    final Set<String> wireNames = EventName.values.map((EventName e) => e.wireName).toSet();
    expect(wireNames, _schemaNames);
  });

  test('no two EventName members share a wire name', () {
    final List<String> wireNames = EventName.values.map((EventName e) => e.wireName).toList();
    expect(wireNames.toSet(), hasLength(wireNames.length));
  });

  group('AnalyticsClientImpl.isValidProps', () {
    test('null props are valid — most events carry none', () {
      expect(AnalyticsClientImpl.isValidProps(null), isTrue);
    });

    test('a well-formed props map is valid', () {
      expect(
        AnalyticsClientImpl.isValidProps(const <String, Object>{
          'turn_index': 3,
          'input_mode': 'voice',
          'is_repeat': false,
        }),
        isTrue,
      );
    });

    test('more than 12 keys is rejected', () {
      final Map<String, Object> tooMany = <String, Object>{
        for (int i = 0; i < 13; i++) 'k$i': i,
      };
      expect(AnalyticsClientImpl.isValidProps(tooMany), isFalse);
    });

    test('a string value over 64 characters is rejected', () {
      expect(
        AnalyticsClientImpl.isValidProps(<String, Object>{'reason': 'x' * 65}),
        isFalse,
      );
    });

    test('a nested value (not a scalar) is rejected', () {
      expect(
        AnalyticsClientImpl.isValidProps(<String, Object>{
          'nested': <String, Object>{'a': 1},
        }),
        isFalse,
      );
    });

    test('a key not matching the schema pattern is rejected', () {
      expect(
        AnalyticsClientImpl.isValidProps(const <String, Object>{'Bad-Key': 1}),
        isFalse,
      );
    });

    test('exactly 12 keys at exactly 64 characters is still valid — the boundary itself', () {
      final Map<String, Object> boundary = <String, Object>{
        for (int i = 0; i < 12; i++) 'k$i': 'x' * 64,
      };
      expect(AnalyticsClientImpl.isValidProps(boundary), isTrue);
    });
  });
}
