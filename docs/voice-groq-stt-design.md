# Voice input via Groq Whisper: design notes

Status: agreed design, not built yet (2026-10-07).

## Goal

Better voice transcription using a shared Groq key, capped per device per day.
When the cap or Groq's own limit is hit, the app falls back to the current
on-device `speech_to_text`.

## Decisions

| Decision | Value |
|---|---|
| Where the Groq key lives | Worker secret only. Never in the app (public repo, APK can be unpacked). |
| Per-device limit | 300 seconds per UTC day, resets at midnight UTC |
| Per-recording limit | 120 seconds |
| Who controls the limits | Remote config (D1 `config` row), no app release needed |
| Fallback | On-device `speech_to_text` |
| Column name | `voice_seconds` (matches `practice_turns` style) |

## Remote config

```json
"voice": {
  "enabled": true,
  "seconds_per_device": 300,
  "max_clip_seconds": 120
}
```

- Add to `worker/src/lib/runtime-config.ts` (Zod) and `contracts/config.schema.json`.
- Optional block: a config without `voice` means voice is off.
- The Worker reads config on every request, so changes apply to the next recording.

## Storage (D1)

Migration `0007`: two columns on `devices`.

```sql
ALTER TABLE devices ADD COLUMN voice_date    TEXT;
ALTER TABLE devices ADD COLUMN voice_seconds INTEGER NOT NULL DEFAULT 0;
```

If `voice_date` is not today (UTC), treat `voice_seconds` as 0. No cron job.

## The cap is a limit, not a reservation

Nothing is set aside per device. Unused seconds are never spent. All devices
draw from the same Groq key, bounded by:

1. Their own 300 seconds/day.
2. Groq's key-wide limits (free tier: roughly 2 h of audio per hour and 8 h per
   day for Whisper; confirm in the Groq console).

## Worker: `POST /v1/stt`

1. Read config. If `voice.enabled` is false, return `voice_unavailable`.
2. Load the device's usage for today.
3. If `seconds_left <= 0`, return `voice_exhausted` **without calling Groq**.
4. Forward the audio to Groq Whisper with `response_format=verbose_json`.
5. Take `duration` from Groq's response (server-measured, the app cannot lie).
6. Reject if `duration > max_clip_seconds + small allowance`.
7. Charge `min(duration, seconds_left)` to `voice_seconds`. Never go past the cap.
8. Return `{ text, seconds_left, max_clip_seconds }`.
9. Groq `429` → return `voice_unavailable`.

Overrun bound: a clip that starts under the cap but runs past it is still
transcribed and returned. Worst case is one clip (≤ 120 s) per device per day.
That costs less than losing words the user already spoke.

## App

- Replace on-device live transcription with recording (e.g. the `record`
  package) when Groq voice is available.
- Recorder limit = `min(max_clip_seconds, seconds_left)`. Show a countdown.
- At the limit, recording stops and is sent. Mid-sentence cut is accepted.
- Update `seconds_left` and `max_clip_seconds` from every `/v1/stt` response.
  The cached `/v1/config` refreshes only once per launch, so this keeps the
  UI correct without a relaunch.

### Engine choice happens before recording

`speech_to_text` only transcribes live from the mic; it cannot transcribe a
recorded file. So the app picks the engine **when the mic is tapped**:

- `seconds_left > 0` and voice available → record and send to Groq.
- Otherwise → on-device `speech_to_text`.

If the backend refuses a clip already recorded (`voice_unavailable` on a Groq
429), show an error; the user repeats it and the next tap uses on-device.

## Example: 120 + 120 + 120

1. Clip 1: 120 s → 180 s left.
2. Clip 2: 120 s → 60 s left.
3. Clip 3: recorder limit is `min(120, 60) = 60`, stops at 60 s → 0 left.
4. Next tap: on-device `speech_to_text`.

## Example: user uses 2 minutes and ends the session

Sessions do not matter. The remaining 3 minutes stay usable for the rest of
that UTC day, in any session. At midnight UTC the device gets a fresh 300 s.

## Costs and caveats

- Groq bills a minimum of 10 s per request; many short clips cost more than
  the seconds counted.
- Per-day caps mean cost grows with daily active users.
- 120 s of compressed audio (m4a/opus) is about 1 MB, well under Groq's 25 MB limit.

## Estimate

About 1 day total:

- Worker: about 4 h (migration, config schema, `/v1/stt`, tests).
- App: about 4 h (recorder, engine switch, countdown, response handling).
