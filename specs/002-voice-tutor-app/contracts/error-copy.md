# Contract — error copy

**Feature**: 002-voice-tutor-app | Source: [error-catalog.md](../../001-proxy-content-contract/contracts/error-catalog.md)

**SC-008**: every relay error code produces a distinct, actionable message that names what the
learner can do next; **none produces a generic failure**. **FR-044**: every code in the closed
catalogue is handled with a distinct, actionable message, and no raw failure is surfaced for any of
them.

This table is the assertion. `test/unit/error_copy_test.dart` walks the `RelayError` sealed union and
fails if any variant lacks an ARB key, shares a key with another variant, or resolves to an empty
string. The union has no `default:` branch, so a twelfth code added to the catalogue is a compile
error rather than a generic dialog.

**The `message` field on the wire is written by the relay and is safe to show as-is**, but the app
uses its own ARB strings instead, because they must be translatable (FR-052) and because two of them
need to say more than a server can know — which route to send the learner down next.

---

| Code | ARB key | What the learner is told (intent, not final copy) | Next action the screen offers | Turn cost | Presented as |
|---|---|---|---|---|---|
| `RATE_LIMITED` | `err_rate_limited` | The conversation is catching up — the provider is pacing requests. The wait is shown and counts down. | Automatic retry when the wait elapses; the same turn resumes at the same point | **None** | **Not an error.** FR-045a: catching up. No red, no failure icon, no apology |
| `INVALID_KEY` | `err_invalid_key` | This key was rejected by the provider. | Re-enter the key, **conversation preserved** (FR-005c) | None | A repairable interruption |
| `QUOTA_EXHAUSTED` | `err_quota_exhausted` | *Your own* daily allowance with the provider is spent. It resets. **No charge occurred and none can.** | **A dialog**: wait for the reset, or replace the key | None | The learner's own allowance — FR-008d forbids implying the app is broken |
| `UNCLEAR_RETRY` | `err_unclear_retry` | That did not come back cleanly. | Retry once automatically; on a second failure the session stays pending and the assessment queues | None | A hiccup, retried for them |
| `TURN_CAP_REACHED` | `err_turn_cap_reached` | The conversation has reached its length for today. **Hints are still available.** | End the session and see the assessment (FR-023); pull a hint (FR-028) | n/a | **A normal ending.** Never styled as a failure |
| `TRIAL_CONSUMED` | `err_trial_consumed` | The free taster has been used. | **A dialog that explains first**, then key entry *pushed* from it (FR-007) | n/a | **Not an error, not an outage** |
| `SESSION_ALREADY_JUDGED` *(repeat judge)* | `err_already_judged_repeat` | Nothing — the assessment already held is shown. | Show the assessment | n/a | **Invisible.** A double-tap guard the learner never sees |
| `SESSION_ALREADY_JUDGED` *(turn after verdict)* | `err_session_closed` | This session is closed; the verdict is in. | Review the assessment, or the reveal | n/a | A closed door, plainly (FR-034 scenario 4) |
| `EMPTY_TURN` | `err_empty_turn` | Nothing was heard — that was too short to send. | Re-record, or type | **None** (rejected before the provider) | A prompt, not a failure |
| `TRIAL_UNAVAILABLE` | `err_trial_unavailable` | The free taster is at capacity today — add your key and start now. | **A dialog that explains first**, then key entry *pushed* from it | n/a | **Capacity, never an outage or a fault of theirs** (FR-007 scenario 4) |
| `PROBLEM_KILLED` | `err_problem_killed` | Today's problem has been withdrawn; here is another. | A different problem is presented (FR-040) | n/a | Invisible where possible — a swap, not a message |
| `BAD_REQUEST` | `err_bad_request` | Something on our side is wrong. | Retry; if it persists, update the app | None | Our fault, said plainly. Never echoes a field |
| *(client)* `transport` | `err_offline_queued` | No connection — this is saved and will send itself. | Nothing required; it drains automatically (FR-043) | **None** (never reached the relay) | A retryable bubble in the conversation, never a lost thought (FR-042) |

---

## Twelve keys for eleven codes

`SESSION_ALREADY_JUDGED` is the one code the catalogue raises for two genuinely different situations,
and one message cannot serve both. A learner who double-tapped "end session" needs *nothing* — show
the assessment already in hand and say nothing about it. A learner trying to speak after the verdict
needs "this session is closed", which FR-034 requires not read as a failure. Split by which call
raised it (`JudgedContext.repeatJudge` vs `turnAfterVerdict`, data-model §12).

## The three codes whose copy is a product requirement

These are not tone preferences; each is written into the catalogue or the spec as a rule.

**`TRIAL_UNAVAILABLE` decides whether the install survives.** It appears on the one screen where a
first-time learner forms their opinion of the product. The catalogue is explicit that
`QUOTA_EXHAUSTED` is wrong here (its copy says the learner's own allowance is spent, which is false)
and that `UNCLEAR_RETRY` is wrong here (it reads as the product being broken). The product still
works — it just needs a key today, and the screen says exactly that and moves.

**`RATE_LIMITED` is a wait, not an error state.** `design.md` §9 puts it bluntly: a rate-limit error
that looks like a crash reads as *your app* being broken. Per-minute limits are the binding
constraint late in a conversation, so this will be seen. It renders as the conversation catching up,
with the wait visible (FR-045a), and the retry costs no turn (FR-045).

**`QUOTA_EXHAUSTED` must say whose allowance it is.** FR-008d: the app must say it is *their*
allowance that is spent, must not imply the app is broken, and must not silently move their traffic
to another provider. The "no charge occurred and none can" line is Principle X.2 showing up in copy,
and it is the reassurance the learner is actually looking for.

## Rules that bind every row

- **No raw string from the wire is ever shown.** Not the relay's `message`, not a status line, not an
  exception's `toString()`. The relay already guarantees no provider text escapes; the app does not
  undo that by rendering its own stack traces.
- **No error copy contains a key, a header, a URL, an HTTP status, or a code name.** SC-012 is
  asserted over log output and analytics payloads; error text is held to the same bar.
- **Every message names what happens next**, in the learner's terms. A message that only describes
  the failure fails SC-008 whether or not it is distinct.
- **Nothing here says "correct" or "wrong"** — that ban belongs to verdict copy (FR-030) but it is
  cheaper to hold the whole ARB file to it, and `test/l10n/no_absolutes_test.dart` does.
