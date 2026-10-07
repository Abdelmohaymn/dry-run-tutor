# `POST /v1/stt` — wire contract

**Status**: authored 2026-10-07. **Plan**: [../../../tasks/plans/PLAN_01_VOICE_GROQ_STT.md](../../../tasks/plans/PLAN_01_VOICE_GROQ_STT.md) ·
**Design**: `docs/voice-groq-stt-design.md`

Delta against `specs/001-proxy-content-contract/contracts/`. The Worker forwards one
recorded clip to Groq Whisper on a shared operator key (`STT_KEY_GROQ`) and enforces a
per-device, per-UTC-day cap in D1 using Groq's own measured `duration`. This contract
adds three error codes (the catalogue grows from 13 to 16) and an optional `voice`
config block. Ships dormant: a config row without a `voice` block means voice is off.

Behaviour approved by the owner 2026-10-07 (decisions D1–D4). This feature requires the
Constitution amendment drafted in Phase 0; do not merge or deploy before the owner has
read it.

---

## Request / response

| Item | Value |
|---|---|
| Auth | `X-Install-Id` (`installAuth`), same as `/v1/daily` |
| Request body | Raw audio bytes (not multipart). `Content-Type` must be one of: `audio/mp4`, `audio/m4a`, `audio/x-m4a` (sent to Groq as `clip.m4a`), `audio/ogg`, `audio/opus`, `audio/webm`, `audio/wav`, `audio/mpeg`, `audio/flac` |
| Query | `language` (optional), matching `^[a-z]{2}$` (ISO-639-1). Anything else returns `BAD_REQUEST` |
| Size | Must be 1 to `MAX_STT_BYTES` = 4 MiB. Check `Content-Length` first if present, then the actual byte length |
| 200 | `{ "text": string, "seconds_left": int >= 0, "max_clip_seconds": int }`, with `cache-control: private, no-store` |
| `VOICE_UNAVAILABLE` | HTTP 503, `retryable: false`. Voice is off or absent, or Groq refused the key (429 rate limit, 401). Nothing is charged. The app falls back to on-device (D4) |
| `VOICE_BUSY` | HTTP 503, `retryable: true`. Groq had a transient failure (5xx, timeout, malformed body). Nothing is charged. The app keeps the clip and offers Try again (D2) |
| `VOICE_EXHAUSTED` | HTTP 429, `retryable: false`. `seconds_left <= 0` before the call. Groq is not called |
| `BAD_REQUEST` | Missing or invalid install id, bad content type, bad size or language, Groq could not read the audio (400/413/415, not charged), or a clip longer than `max_clip_seconds + 5` (charged) |

Every error uses the existing envelope
(`{ "error": { "code", "message", "retryable" } }`). The three `VOICE_*` codes are new
and are added to `error-catalog.md` and `worker/src/lib/errors.ts`. Transcript text and
audio are never written to D1, logs, or error bodies.

---

## Server-side behaviour, in order

1. `installAuth` -> 401 if unknown. `cfg = getRuntimeConfig`; `voice` off or absent ->
   `VOICE_UNAVAILABLE` (no Groq call).
2. `used = voice-quota.getVoiceSecondsUsed(db, device_hash, utcDate())`.
3. `left <= 0` -> `VOICE_EXHAUSTED` (no Groq call, before the body is read).
4. Validate content type + language + size (<= `MAX_STT_BYTES`) -> `BAD_REQUEST`.
5. `stt-groq.transcribeWithGroq(STT_KEY_GROQ, model, audio, verbose_json)` ->
   `POST https://api.groq.com/openai/v1/audio/transcriptions` (multipart):
   - Groq 429 / 401 -> `VOICE_UNAVAILABLE` (nothing charged)
   - Groq 400 / 413 / 415 -> `BAD_REQUEST` (nothing charged)
   - Groq 5xx / timeout / malformed body -> `VOICE_BUSY`, retryable (nothing charged)
6. `duration > max_clip_seconds + 5` -> charge, then `BAD_REQUEST`.
7. `newUsed = chargeVoiceSeconds(..., ceil(duration), cap)` (atomic, `MIN(cap, ...)`).
   Billable = `Math.ceil(duration)`; if Groq omits `duration`, charge `max_clip_seconds`.
8. `200 { text, seconds_left: cap - newUsed, max_clip_seconds }`.

---

## Why the server refuses a clip, and what the app does (D2 + D4)

| Cause | Worker answer | Clip | What the user sees | Next mic tap |
|---|---|---|---|---|
| Phone offline or upload dropped / timed out | (no response) -> `TransportFailure` | **Kept** | "That didn't go through. Your recording is saved — tap Try again." **[Try again] [Discard]** | — (retry re-uploads) |
| Groq 5xx, Groq timeout, Groq malformed body | `VOICE_BUSY` 503, `retryable: true`, nothing charged | **Kept** | Same as above | — (retry re-uploads) |
| Groq 429 (Groq's own limit hit) or Groq 401 (key misconfigured) | `VOICE_UNAVAILABLE` 503, nothing charged | Deleted | "Sorry, we couldn't transcribe that one. Please tap the mic and say it again — your phone's speech recognition will take it from here." | On-device for 10 min |
| Voice switched off in config | `VOICE_UNAVAILABLE` 503 | Deleted | Same as the row above | On-device for 10 min; the next launch reads the new config and stays on-device |
| Device's 300 s already used (stale local count, e.g. reinstall) | `VOICE_EXHAUSTED` 429 | Deleted | Same as the row above | On-device until UTC midnight |
| Clip longer than `max_clip_seconds + 5` (should not happen; the recorder stops at the limit), or Groq can't read the audio (Groq 400/413/415) | `BAD_REQUEST` 400 | Deleted | "Sorry, we couldn't transcribe that one. Please tap the mic and say it again." | Cloud if seconds remain |

A retry that comes back with a non-retryable answer follows that answer's row (clip
deleted, fallback). Retries are manual only: no automatic re-send, and the app's Dio has
no retry interceptor.

---

## Config: the `voice` block

Optional block in the `config` row (`runtime_config`). **Absent means voice is off**;
migration 0007 does not add it. Zod `.strict()`, so an unknown key fails parsing.

```json
"voice": {
  "enabled": true,
  "seconds_per_device": 300,
  "max_clip_seconds": 120,
  "model": "whisper-large-v3-turbo"
}
```

| Field | Type | Meaning |
|---|---|---|
| `enabled` | boolean, required | `false` behaves like an absent block: `VOICE_UNAVAILABLE`, no Groq call |
| `seconds_per_device` | int 0..3600, required | Per-device allowance per UTC day, in Groq-measured seconds |
| `max_clip_seconds` | int 5..600, required | Longest single clip. The app counts down to `min(max_clip_seconds, seconds_left)` and auto-stops |
| `model` | string, optional, default `whisper-large-v3-turbo` | **Server-read only.** Stripped from `GET /v1/config` before serving; the app never sees it |

`voiceConfig(cfg)` returns `null` when the block is absent or `enabled === false`.
`GET /v1/config` is public and cached (`max-age=300`), so it cannot carry a per-device
`seconds_left`; the app persists the last `/v1/stt` response per UTC day instead.

Merge into `specs/001-proxy-content-contract/contracts/config.schema.json`: a `voice`
property with `additionalProperties: false`, required
`["enabled","seconds_per_device","max_clip_seconds"]`, and an optional `model` whose
description says it is server-read only and stripped from `GET /v1/config`.

---

## Migration `0007_voice_seconds.sql`

Cap-enforcing only; `voice_date` NULL or != today means 0 used; no cron.

```sql
ALTER TABLE devices ADD COLUMN voice_date    TEXT;
ALTER TABLE devices ADD COLUMN voice_seconds INTEGER NOT NULL DEFAULT 0;
```

The charge is one atomic upsert,
`MIN(cap, (voice_date = today ? voice_seconds : 0) + billable)` with
`RETURNING voice_seconds`: date rollover with no cron, never past the cap, safe under
concurrency. D1 holds no transcript text or audio.

---

## Secret

`STT_KEY_GROQ` (Worker secret, `wrangler secret put`). Separate from `TRIAL_KEY_GROQ`
so the operator-key scoping test keeps its meaning. The operator key serves every
device, including learners with their own key (D1). Never committed; `.dev.vars` holds a
placeholder only.
