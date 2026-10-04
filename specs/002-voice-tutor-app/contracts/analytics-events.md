# Contract — analytics events

**Feature**: 002-voice-tutor-app | Source: [event.schema.json](../../001-proxy-content-contract/contracts/event.schema.json)

**The name set is closed at 23 and the app may not add to it.** An unknown name is a 400 from
`/v1/event`, not a silent insert — an open name field is how message content ends up in an analytics
table. Where `design.md` §10 lists an event that has no schema name, its information travels as a
`prop` on the nearest name; §10's list is superseded (`research.md` R-006).

**Props obey the schema, not convenience**: ≤12 keys, scalars only, no nesting, ≤64 characters,
key names matching `^[a-z][a-z0-9_]{0,31}$`. The app validates locally before buffering, so an
invalid event fails loudly in dev rather than arriving as a production 400.

**FR-050 is absolute**: no event ever carries conversation text, key material, or personal
information. The 64-character ceiling is the server's structural defence; `test/security/no_key_leak_test.dart`
is the client's.

---

## The 23 names, and what the app sends with each

| Event | Emitted when | Props |
|---|---|---|
| `app_open` | Every launch | `is_first_launch` |
| `onboarding_started` | Age gate shown | — |
| `onboarding_done` | Age confirmed, first problem reached | — |
| `key_prompt_shown` | The wall is shown — **only after a completed session** (FR-005a) | `trigger` (`trial_spent` \| `trial_unavailable` \| `trial_ip_limit` \| `settings`) |
| `key_entry_started` | Learner opens key entry | `provider` |
| `key_saved` | Probe validation succeeded and the key is in Keystore | `provider` |
| `trial_session_started` | First `/v1/trial` chat call accepted | — |
| `trial_session_completed` | Taster session assessed | `turn_count` |
| `daily_opened` | Today's problem shown | `problem_id`, `is_repeat` |
| `chat_turn_sent` | A turn is accepted by the relay | `turn_index`, **`input_mode`** (`voice` \| `text`), `duration_ms`, `path` (`trial` \| `keyed`) |
| `transcript_edited` | Learner edits the recognised draft before sending | `chars_changed`, `used_chip` |
| `hint_revealed` | A rung is returned | `hint_index`, `hints_remaining` |
| `hint_ladder_exhausted` | The closing line is shown | — |
| `session_ended` | Learner ends the session | `turn_count`, **`ended_by`** (`user` \| `cap` \| `solution`) |
| `assessment_shown` | Verdict rendered | `verdict`, `confidence`, `latency_ms` |
| `assessment_disputed` | Dispute recorded locally (FR-031a) | `verdict` |
| `reveal_shown` | Editorial opened | — |
| `share_card_shared` | Share sheet completed | — |
| `streak_advanced` | A day is credited | `streak_length` |
| `assessment_verdict_overridden` | `mapVerdict()` differed from the model's | `verdict` |
| `tutor_leak_blocked` | `meta.leak_blocked` was true | `turn_index` |
| `config_fetch_failed` | `/v1/config` failed and cache was used (FR-047 scenario 5) | `reason` (`offline` \| `timeout` \| `http` \| `parse`) |
| `offline_queue_drained` | Outbox emptied after reconnect | `items`, `kind` |

---

## Three of these carry the whole product bet

**`chat_turn_sent.input_mode`** is the constitution's own instruction. Principle I's contingency
clause says to watch the voice/text split — it is the falsification test for the thesis that a voice
tutor is a product ChatGPT does not already ship. It is also SC-004's measurement.

**`key_prompt_shown` → `key_entry_started` → `key_saved`** is the BYOK funnel, and SC-010's 30%
target is read off it. `design.md` §9 calls it the largest unknown in the project and the
constitution accepts the onboarding friction *only* on the condition that its cost is measured, not
assumed. Note `key_prompt_shown` carries `trigger`: a wall reached because the taster was spent is a
different funnel from a wall reached because the taster was at capacity, and conflating them would
hide `TRIAL_UNAVAILABLE`'s cost inside the ordinary conversion number.

**`transcript_edited.chars_changed` and `used_chip`** measure SC-003 (80% of turns sent unedited or
near-unedited) and SC-016 (70% of needed corrections made by tapping a chip rather than opening the
keyboard). Together they answer whether the mandatory review step — Principle V, non-negotiable — is
a fair price or a tax. If SC-016 fails, tap-to-fix is not working and the spoken path is slower than
typing, which is the failure mode FR-012a exists to prevent.

## Delivery

- **Buffered in Drift, batched ≤100, drained on connectivity and on app background.** Events emitted
  offline are delivered on reconnect and none are lost (FR-049 US8 scenario 2).
- **A rejected batch changes nothing visible** (FR-051, US8 scenario 3). Log in dev, drop after a
  bounded number of attempts in prod, and never surface it.
- **No third-party SDK and no crash SDK.** Principle X and `design.md` §10: crashes and ANRs come
  from Play Console natively, and adding an analytics SDK would cost exactly the privacy story
  Principles VI and VII exist to build.
