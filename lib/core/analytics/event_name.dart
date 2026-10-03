/// The 23 closed names from `event.schema.json` (contracts/analytics-events.md,
/// research.md R-006). An unknown name is a 400 from `POST /v1/event`, not
/// a silent insert — this enum is what turns that into a compile error
/// instead of a production surprise. `design.md` §10's event list is
/// superseded; where it named something this schema does not, the
/// information travels as a `prop` on the nearest name here instead.
enum EventName {
  appOpen('app_open'),
  onboardingStarted('onboarding_started'),
  onboardingDone('onboarding_done'),
  keyPromptShown('key_prompt_shown'),
  keyEntryStarted('key_entry_started'),
  keySaved('key_saved'),
  trialSessionStarted('trial_session_started'),
  trialSessionCompleted('trial_session_completed'),
  dailyOpened('daily_opened'),
  chatTurnSent('chat_turn_sent'),
  transcriptEdited('transcript_edited'),
  hintRevealed('hint_revealed'),
  hintLadderExhausted('hint_ladder_exhausted'),
  sessionEnded('session_ended'),
  assessmentShown('assessment_shown'),
  assessmentDisputed('assessment_disputed'),
  revealShown('reveal_shown'),
  shareCardShared('share_card_shared'),
  streakAdvanced('streak_advanced'),
  assessmentVerdictOverridden('assessment_verdict_overridden'),
  tutorLeakBlocked('tutor_leak_blocked'),
  configFetchFailed('config_fetch_failed'),
  offlineQueueDrained('offline_queue_drained');

  const EventName(this.wireName);

  /// The exact string `POST /v1/event` expects.
  final String wireName;
}
