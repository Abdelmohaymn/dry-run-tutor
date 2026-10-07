// POST /v1/stt?language=en — server-side speech-to-text (feature 008).
// The body is the raw audio clip. The Worker forwards it to Groq Whisper on
// the operator key and charges the device's daily voice seconds from Groq's
// own measured duration. Step order matters: nothing reaches Groq unless voice
// is on, the device has seconds left, and the request is well formed.
//
// Privacy: neither the audio nor the transcript is logged, stored or put in an
// error. The transcript only travels back in the `text` field of the 200.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { getRuntimeConfig, voiceConfig } from "../lib/runtime-config";
import { chargeVoiceSeconds, getVoiceSecondsUsed, voiceSecondsLeft } from "../lib/voice-quota";
import { parseAudioType, transcribeWithGroq } from "../lib/stt-groq";
import { nowIso, utcDate } from "../lib/time";

export const sttRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

const MAX_STT_BYTES = 4 * 1024 * 1024;

// Slack over `max_clip_seconds` for recorder stop latency before a clip is
// treated as over-length.
const CLIP_ALLOWANCE_SECONDS = 5;

const LANGUAGE_PATTERN = /^[a-z]{2}$/;

sttRoute.post("/", async (c) => {
  // 1. Voice must be on.
  const cfg = await getRuntimeConfig(c.env.DB);
  const voice = voiceConfig(cfg);
  if (!voice) throw new AppError("VOICE_UNAVAILABLE");

  // 2-3. Seconds left today, checked before the body is read.
  const today = utcDate();
  const deviceHash = c.get("installId");
  const cap = voice.seconds_per_device;
  const used = await getVoiceSecondsUsed(c.env.DB, deviceHash, today);
  if (voiceSecondsLeft(cap, used) <= 0) throw new AppError("VOICE_EXHAUSTED");

  // 4. Validate content type, language and size.
  const contentType = parseAudioType(c.req.header("content-type"));
  if (contentType === null) throw new AppError("BAD_REQUEST");

  const language = c.req.query("language");
  if (language !== undefined && !LANGUAGE_PATTERN.test(language)) {
    throw new AppError("BAD_REQUEST");
  }

  const declared = c.req.header("content-length");
  if (declared !== undefined) {
    const declaredBytes = Number(declared);
    if (!Number.isFinite(declaredBytes) || declaredBytes < 1 || declaredBytes > MAX_STT_BYTES) {
      throw new AppError("BAD_REQUEST");
    }
  }
  const audio = await c.req.arrayBuffer();
  if (audio.byteLength < 1 || audio.byteLength > MAX_STT_BYTES) {
    throw new AppError("BAD_REQUEST");
  }

  // 5. Transcribe. Groq failures throw VOICE_UNAVAILABLE / VOICE_BUSY /
  // BAD_REQUEST and charge nothing.
  const { text, durationSeconds } = await transcribeWithGroq({
    apiKey: c.env.STT_KEY_GROQ,
    model: voice.model,
    audio,
    contentType,
    language,
  });

  // 6-7. Charge Groq's measured length (the full clip limit when Groq omitted
  // it), then refuse a clip that overran the limit.
  const billable = Math.ceil(durationSeconds ?? voice.max_clip_seconds);
  const newUsed = await chargeVoiceSeconds(c.env.DB, deviceHash, today, billable, cap, nowIso());
  if (durationSeconds !== null && durationSeconds > voice.max_clip_seconds + CLIP_ALLOWANCE_SECONDS) {
    throw new AppError("BAD_REQUEST");
  }

  // 8.
  return c.json(
    {
      text,
      seconds_left: voiceSecondsLeft(cap, newUsed),
      max_clip_seconds: voice.max_clip_seconds,
    },
    200,
    { "cache-control": "private, no-store" },
  );
});
