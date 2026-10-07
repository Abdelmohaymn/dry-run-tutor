// Groq Whisper speech-to-text. This is the ONLY module that reads a Groq
// transcription status or body. The host is compiled in, never taken from
// config, for the same reason as provider.ts: a config row must not be able
// to point the operator key at another host.
//
// Nothing here logs. The upstream body is never returned, never stored and
// never put in an error: a transcript is learner speech, so it only travels
// back to the caller in the `text` field of the success value.
import { z } from "zod";
import { AppError } from "./errors";

const GROQ_STT_URL = "https://api.groq.com/openai/v1/audio/transcriptions";

// A 120 s clip transcribes in a few seconds; a provider that has stopped
// answering must not hold the learner's request for longer than this.
const STT_TIMEOUT_MS = 30_000;

// Accepted request content types -> the file extension Groq uses to sniff
// the format of the multipart `file` part.
export const AUDIO_TYPES: Record<string, string> = {
  "audio/mp4": "m4a",
  "audio/m4a": "m4a",
  "audio/x-m4a": "m4a",
  "audio/ogg": "ogg",
  "audio/opus": "opus",
  "audio/webm": "webm",
  "audio/wav": "wav",
  "audio/mpeg": "mp3",
  "audio/flac": "flac",
};

// Normalises a Content-Type header value (drops parameters, lowercases) and
// returns it only when it is an accepted audio type, otherwise null.
export function parseAudioType(header: string | null | undefined): string | null {
  const type = (header ?? "").split(";")[0].trim().toLowerCase();
  return Object.prototype.hasOwnProperty.call(AUDIO_TYPES, type) ? type : null;
}

const groqResponseSchema = z.object({
  text: z.string(),
  duration: z.number().nonnegative().optional(),
});

export interface TranscribeParams {
  apiKey: string;
  model: string;
  audio: ArrayBuffer;
  contentType: string;
  language?: string;
}

export interface TranscribeResult {
  text: string;
  // Groq's own measured length of the clip. Null when Groq omitted it.
  durationSeconds: number | null;
}

// Groq's limit is hit or the key is bad: a resend would fail too -> the app
// falls back to on-device. Groq cannot read these bytes: resending the same
// clip would fail the same way. Everything else is treated as transient.
function mapStatus(status: number): AppError {
  if (status === 429 || status === 401) return new AppError("VOICE_UNAVAILABLE");
  if (status === 400 || status === 413 || status === 415) return new AppError("BAD_REQUEST");
  return new AppError("VOICE_BUSY");
}

export async function transcribeWithGroq(p: TranscribeParams): Promise<TranscribeResult> {
  const extension = AUDIO_TYPES[p.contentType] ?? "m4a";

  const form = new FormData();
  form.append("file", new File([p.audio], `clip.${extension}`, { type: p.contentType }));
  form.append("model", p.model);
  form.append("response_format", "verbose_json");
  form.append("temperature", "0");
  if (p.language) form.append("language", p.language);

  let res: Response;
  try {
    res = await fetch(GROQ_STT_URL, {
      method: "POST",
      headers: { authorization: `Bearer ${p.apiKey}` },
      body: form,
      signal: AbortSignal.timeout(STT_TIMEOUT_MS),
    });
  } catch {
    // Network error or timeout.
    throw new AppError("VOICE_BUSY");
  }

  if (!res.ok) {
    // Release the connection without reading the body.
    await res.body?.cancel().catch(() => {});
    throw mapStatus(res.status);
  }

  let parsed: z.infer<typeof groqResponseSchema>;
  try {
    parsed = groqResponseSchema.parse(await res.json());
  } catch {
    // Unreadable or unexpected body (the timeout signal also covers the read).
    throw new AppError("VOICE_BUSY");
  }

  return { text: parsed.text, durationSeconds: parsed.duration ?? null };
}
