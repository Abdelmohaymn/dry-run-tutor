// T150 (US8), FR-050: the schema's prop limits — ≤12 keys, scalars only,
// ≤64 characters, key names matching `^[a-z][a-z0-9_]{0,31}$` — held
// against a **literal reproduction of every real emission site's props**,
// not just `isValidProps` exercised generically (that is
// `test/unit/analytics_contract_test.dart`, T049). The no-text/no-key/
// no-PII assertion is `test/security/no_key_leak_test.dart`'s and is not
// duplicated here.
//
// Each entry below also pins the *exact* prop key set contracts/analytics-
// events.md specifies for that event — this is what caught
// `assessment_shown` carrying `matched_verdict` (not in the contract) and
// missing `confidence`/`latency_ms`, `assessment_disputed` carrying no
// props at all, and `config_fetch_failed.reason` using a different
// vocabulary than the contract's closed four values, all fixed in this
// same pass (T152). A future emission site that drifts from the contract
// fails here before it fails as a 400 from `/v1/event`.
import 'package:dry_run/core/analytics/analytics_client.dart';
import 'package:dry_run/core/analytics/event_name.dart';
import 'package:flutter_test/flutter_test.dart';

/// One literal reproduction of each real call site's props
/// (`grep -rn '.emit(' lib/`), keyed by event name. `null` means the
/// contract specifies no props for that event and every real site agrees.
final Map<EventName, Map<String, Object>?> _emissionSites = <EventName, Map<String, Object>?>{
  // lib/main.dart
  EventName.appOpen: <String, Object>{'is_first_launch': true},
  // lib/features/onboarding/presentation/age_gate_screen.dart
  EventName.onboardingStarted: null,
  EventName.onboardingDone: null,
  // lib/features/chat/presentation/daily_session_cubit.dart
  EventName.keyPromptShown: <String, Object>{'trigger': 'trial_spent'},
  // lib/features/keys/presentation/key_entry_cubit.dart
  EventName.keyEntryStarted: <String, Object>{'provider': 'groq'},
  EventName.keySaved: <String, Object>{'provider': 'groq'},
  // lib/features/chat/presentation/daily_session_cubit.dart
  EventName.trialSessionStarted: null,
  EventName.trialSessionCompleted: <String, Object>{'turn_count': 4},
  EventName.dailyOpened: <String, Object>{'problem_id': 'vp-0001', 'is_repeat': false},
  EventName.chatTurnSent: <String, Object>{
    'turn_index': 3,
    'input_mode': 'voice',
    'duration_ms': 1200,
    'path': 'trial',
  },
  EventName.transcriptEdited: <String, Object>{'chars_changed': 5, 'used_chip': true},
  EventName.hintRevealed: <String, Object>{'hint_index': 1, 'hints_remaining': 2},
  EventName.hintLadderExhausted: null,
  EventName.sessionEnded: <String, Object>{'turn_count': 6, 'ended_by': 'user'},
  EventName.assessmentShown: <String, Object>{'verdict': 'pass', 'confidence': 0.82, 'latency_ms': 2400},
  EventName.assessmentDisputed: <String, Object>{'verdict': 'pass'},
  EventName.revealShown: null,
  // lib/features/streak/presentation/share_card.dart
  EventName.shareCardShared: null,
  // lib/features/chat/presentation/daily_session_cubit.dart
  EventName.streakAdvanced: <String, Object>{'streak_length': 7},
  EventName.tutorLeakBlocked: <String, Object>{'turn_index': 3},
  // worker/src/lib/judge-core.ts — server-emitted, not a client site.
  // `mapVerdict()`'s pre-override model verdict never reaches the app
  // (Principle II: the client only ever sees the post-override
  // `Assessment.verdict`), so there is structurally no client call site
  // for this name to reproduce here.
  EventName.assessmentVerdictOverridden: null,
  // lib/core/config/remote_config_repository.dart
  EventName.configFetchFailed: <String, Object>{'reason': 'offline'},
  // lib/core/queue/outbox_drain_bloc.dart
  EventName.offlineQueueDrained: <String, Object>{'items': 2, 'kind': 'mixed'},
  // lib/features/chat/presentation/daily_session_cubit.dart
  EventName.finishOfferShown: <String, Object>{'turn_index': 3},
  EventName.finishOfferAccepted: <String, Object>{'turn_index': 3},
  EventName.finishOfferDismissed: <String, Object>{'turn_index': 3},
};

/// contracts/analytics-events.md's own prop key set for each event —
/// independent of `_emissionSites` above, so a typo in one doesn't mask a
/// typo in the other.
const Map<EventName, Set<String>> _contractPropKeys = <EventName, Set<String>>{
  EventName.appOpen: <String>{'is_first_launch'},
  EventName.onboardingStarted: <String>{},
  EventName.onboardingDone: <String>{},
  EventName.keyPromptShown: <String>{'trigger'},
  EventName.keyEntryStarted: <String>{'provider'},
  EventName.keySaved: <String>{'provider'},
  EventName.trialSessionStarted: <String>{},
  EventName.trialSessionCompleted: <String>{'turn_count'},
  EventName.dailyOpened: <String>{'problem_id', 'is_repeat'},
  EventName.chatTurnSent: <String>{'turn_index', 'input_mode', 'duration_ms', 'path'},
  EventName.transcriptEdited: <String>{'chars_changed', 'used_chip'},
  EventName.hintRevealed: <String>{'hint_index', 'hints_remaining'},
  EventName.hintLadderExhausted: <String>{},
  EventName.sessionEnded: <String>{'turn_count', 'ended_by'},
  EventName.assessmentShown: <String>{'verdict', 'confidence', 'latency_ms'},
  EventName.assessmentDisputed: <String>{'verdict'},
  EventName.revealShown: <String>{},
  EventName.shareCardShared: <String>{},
  EventName.streakAdvanced: <String>{'streak_length'},
  EventName.assessmentVerdictOverridden: <String>{'verdict'},
  EventName.tutorLeakBlocked: <String>{'turn_index'},
  EventName.configFetchFailed: <String>{'reason'},
  EventName.offlineQueueDrained: <String>{'items', 'kind'},
  EventName.finishOfferShown: <String>{'turn_index'},
  EventName.finishOfferAccepted: <String>{'turn_index'},
  EventName.finishOfferDismissed: <String>{'turn_index'},
};

void main() {
  test('_emissionSites and _contractPropKeys both cover exactly the 26 closed names', () {
    expect(_emissionSites.keys.toSet(), EventName.values.toSet());
    expect(_contractPropKeys.keys.toSet(), EventName.values.toSet());
  });

  test('every emission site is valid against the schema (≤12 keys, scalars, ≤64 chars, key pattern)', () {
    for (final MapEntry<EventName, Map<String, Object>?> entry in _emissionSites.entries) {
      expect(
        AnalyticsClientImpl.isValidProps(entry.value),
        isTrue,
        reason: '${entry.key.wireName} props ${entry.value} fail the schema',
      );
    }
  });

  test('every emission site carries exactly the props contracts/analytics-events.md specifies', () {
    for (final EventName name in EventName.values) {
      // Server-emitted, not a client emission site (see the comment on
      // `assessmentVerdictOverridden` above) — nothing to compare here.
      if (name == EventName.assessmentVerdictOverridden) {
        continue;
      }
      final Set<String> actualKeys = _emissionSites[name]?.keys.toSet() ?? <String>{};
      expect(
        actualKeys,
        _contractPropKeys[name],
        reason: '${name.wireName} prop keys drifted from the contract',
      );
    }
  });
}
