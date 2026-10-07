# Error catalog — the closed set

**Feature**: 001-proxy-content-contract | **Date**: 2026-08-20

Sixteen codes. **This list is closed.** `worker/src/lib/errors.ts` exports exactly these and nothing else; a test asserts the exported union has sixteen members. No provider error body, status line, or stack trace ever reaches the caller (FR-039, SC-011).

## Envelope

Every non-2xx response from every route, without exception:

```json
{ "error": { "code": "RATE_LIMITED", "message": "…", "retryable": true, "retry_after_ms": 20000 } }
```

`message` is **written by us**, drawn from the table below, and is safe to show a learner as-is. It is never interpolated from an upstream response. `retry_after_ms` is present only when `retryable` is true and a delay is known.

## The sixteen

| Code | HTTP | `retryable` | Raised when | Caller behaviour the contract promises | Spec |
|---|---|---|---|---|---|
| `RATE_LIMITED` | 429 | **true** | Provider returns 429, or its per-minute ceiling is hit | Wait `retry_after_ms` (honour upstream `Retry-After`, else exponential backoff from 2s, cap 30s) and retry the same turn. **This is a wait, never an error state.** | FR-037, SC-011 |
| `INVALID_KEY` | 401 | **false** | Provider returns 401/403 for the learner's key | Prompt to re-enter the key. **Do not discard the conversation.** Explicitly not retryable — retrying cannot help. | FR-038 |
| `QUOTA_EXHAUSTED` | 429 | **false** | Provider signals the daily allowance is spent | Explain plainly that this is the learner's own provider daily limit, that it resets, and that **no charge occurred**. | Edge case, X.2 |
| `UNCLEAR_RETRY` | 502 | **true** | Provider refusal, malformed body, non-JSON, 5xx, or timeout | Retry once. On a second failure the session stays pending and the assessment is queued. For `/v1/judge` this maps to `verdict: "unclear"` client-side. | FR-039 |
| `TURN_CAP_REACHED` | 409 | **false** | D1 turn counter exceeds `config.chat.turn_cap` | Offer to end the session and assess. Not an error condition — a normal ending. | FR-008 |
| `TRIAL_CONSUMED` | 409 | **false** | `install_id` has a `trial_consumed` row whose `completed_at` is set — i.e. a *previous* trial session finished. Never raised for the remaining turns of a session already in flight. | Show the key-entry flow. | FR-032, SC-010 |
| `SESSION_ALREADY_JUDGED` | 409 | **false** | `turn_counter.judged_at` is already set for this `(install_id, problem_id, date)`. Raised by `/v1/judge` on a repeat assessment **and** by `/v1/chat` on any further turn or hint pull — a scored session is closed. | Show the assessment the client already has. Not an error the learner should see — a double-tap guard and an end-of-session guard. Claimed **before** the provider call, so neither a repeat assessment nor a post-verdict turn can spend anything against the learner's allowance. | FR-013a, FR-013b, X.1 |
| `EMPTY_TURN` | 400 | **false** | Learner turn is empty or under 3 non-whitespace characters | Re-record. **Rejected before the provider is called**, so it does not spend the learner's allowance. | Edge case |
| `TRIAL_UNAVAILABLE` | 503 | **false** | Every eligible member of the trial provider pool is out of daily budget or on rate-limit cooldown (`data-model.md` §B8). Raised **only** on `/v1/trial`, and only after every eligible member has been tried. | Show *"the free taster is at capacity today — add your key and start now"* and route **straight into key entry**. This is not a retry and not an apology: the product still works, it just needs a key today. **Never** use `QUOTA_EXHAUSTED` here — its copy says the learner's own allowance is spent, which is false — and never `UNCLEAR_RETRY`, which reads as the product being broken on the one screen that decides whether the install survives. | FR-031c, **SC-010b** |
| `TRIAL_IP_LIMIT` | 429 | **false** | A NEW trial session from a network (keyed hash of `CF-Connecting-IP`) that has already started `trial.ip_daily_session_cap` sessions this UTC day. The app offers key entry, as for `TRIAL_CONSUMED`. |
| `PROBLEM_KILLED` | 409 | **false** | `problem_id` is in `config.killed_problem_ids` | Fall back to another daily problem. | FR-033 |
| `BAD_REQUEST` | 400 | **false** | Zod validation failure, bad/missing `X-Install-Id`, bad HMAC, unknown `problem_id` | A client bug. Message is generic; the specific field is **not** echoed, because echoing request fields is one of the ways a key ends up in a response body. | FR-024 |
| `VOICE_UNAVAILABLE` | 503 | **false** | `POST /v1/voice` only. Voice is switched off in config (no `voice` block, or `enabled: false`), or Groq answered 429 or 401 (its own limit hit, or the operator key is misconfigured). Nothing is charged to the device. | Delete the clip, show the on-device fallback copy, and use on-device `speech_to_text` for the next 10 minutes. Not retryable. | 008 |
| `VOICE_EXHAUSTED` | 429 | **false** | `POST /v1/voice` only. The device has already used its `voice.seconds_per_device` for the current UTC day. | Delete the clip and use on-device `speech_to_text` until UTC midnight. Not retryable. | 008 |
| `VOICE_BUSY` | 503 | **true** | `POST /v1/voice` only. Groq answered 5xx, timed out, or returned a malformed body. Nothing is charged to the device. | Keep the recorded clip and offer **Try again**, which re-sends the same clip. Manual retry only. | 008 |

## Mapping upstream to ours

`worker/src/lib/provider-groq.ts` is the place a provider status is read for chat and judge, and `worker/src/lib/stt-groq.ts` is the second, for voice transcription (feature 008). Each returns our code, never theirs. The chat/judge mapping:

```
401, 403                          → INVALID_KEY
400 + body names the API key      → INVALID_KEY      (Gemini's shape for a bad or expired key)
429 + body mentions daily/quota   → QUOTA_EXHAUSTED
429 otherwise                     → RATE_LIMITED     (retry_after_ms from Retry-After if present)
408, 5xx, network error, timeout  → UNCLEAR_RETRY
200 + unparseable / refusal       → UNCLEAR_RETRY
```

The voice mapping in `stt-groq.ts` (operator key, never a learner key):

```
429, 401                          → VOICE_UNAVAILABLE   (Groq's own limit hit, or the operator key is misconfigured; nothing charged)
408, 5xx, network error, timeout  → VOICE_BUSY          (retryable; nothing charged)
200 + malformed body              → VOICE_BUSY
400, 413, 415                     → BAD_REQUEST         (Groq cannot read the audio)
```

**On `/v1/trial` the first three rows do not apply, and this is the point.** There is no learner key on that path, so `INVALID_KEY` is unreachable; and a 429 or a quota signal from a pool member is **not** an outcome, it is a routing decision. `routes/trial.ts` catches `RATE_LIMITED` and `QUOTA_EXHAUSTED` from `provider.ts`, records a cooldown against that pool member, and retries the leg on the next eligible member (`data-model.md` §B8, FR-031c). Only when the candidate list is exhausted does anything reach the caller, and what reaches them is `TRIAL_UNAVAILABLE`. A learner must never see another learner's provider's rate limit.

The provider's response body is read **only** to distinguish daily-quota from per-minute rate limiting on a 429, and a rejected key from any other bad request on a 400. Those two pattern tests are the only points where upstream text is inspected. (`stt-groq.ts` inspects no upstream text at all, only the status.) It is never stored and never forwarded.

## Redaction obligation

Every path that produces an error — including `catch` blocks, `console.error`, and the SSE `error` frame — passes through `redact()` from `worker/src/lib/redact.ts` first. `redact()` scrubs the `X-User-Key` header value, any `Authorization` value, and any string matching `gsk_[A-Za-z0-9]{20,}` or `sk-[A-Za-z0-9]{20,}` from any object before it is serialised.

`test/unit/redact.test.ts` asserts a known key string appears **zero** times across: every error envelope, every log line captured during a full request, every D1 row written during that request, and the SSE error frame (FR-024, SC-006). **This test is written before any relay code exists.**
