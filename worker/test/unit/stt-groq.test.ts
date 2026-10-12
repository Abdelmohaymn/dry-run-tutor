import { fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { AppError } from "../../src/lib/errors";
import {
  AUDIO_TYPES,
  parseAudioType,
  STT_PROMPT_AR,
  STT_PROMPT_EN,
  transcribeWithGroq,
} from "../../src/lib/stt-groq";

const ORIGIN = "https://api.groq.com";
const PATH = "/openai/v1/audio/transcriptions";
const API_KEY = "gsk_placeholder_stt_key";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function expectAppError(promise: Promise<unknown>): Promise<AppError> {
  try {
    await promise;
  } catch (err) {
    expect(err).toBeInstanceOf(AppError);
    return err as AppError;
  }
  throw new Error("expected promise to reject with an AppError");
}

function callGroq(overrides: Partial<Parameters<typeof transcribeWithGroq>[0]> = {}) {
  return transcribeWithGroq({
    apiKey: API_KEY,
    model: "whisper-large-v3-turbo",
    audio: new Uint8Array([1, 2, 3, 4]).buffer,
    contentType: "audio/mp4",
    ...overrides,
  });
}

function intercept() {
  return fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" });
}

describe("transcribeWithGroq success", () => {
  it("200 verbose_json returns the text and Groq's measured duration", async () => {
    intercept().reply(200, { text: "hello world", duration: 12.34, language: "en" });
    const result = await callGroq();
    expect(result).toEqual({ text: "hello world", durationSeconds: 12.34 });
  });

  it("a missing duration returns durationSeconds null", async () => {
    intercept().reply(200, { text: "no duration here" });
    const result = await callGroq();
    expect(result).toEqual({ text: "no duration here", durationSeconds: null });
  });

  it("sends the bearer key and a multipart body", async () => {
    let headers: unknown;
    let body: unknown;
    intercept().reply(200, (opts) => {
      headers = opts.headers;
      body = opts.body;
      return { text: "ok", duration: 1 };
    });
    await callGroq();

    // undici's mock may normalise headers into an object or a flat array.
    const flat: Record<string, string> = {};
    if (Array.isArray(headers)) {
      for (let i = 0; i + 1 < headers.length; i += 2) {
        flat[String(headers[i]).toLowerCase()] = String(headers[i + 1]);
      }
    } else if (headers instanceof Headers) {
      headers.forEach((v, k) => (flat[k.toLowerCase()] = v));
    } else {
      for (const [k, v] of Object.entries((headers ?? {}) as Record<string, unknown>)) {
        flat[k.toLowerCase()] = String(v);
      }
    }
    expect(flat["authorization"]).toBe(`Bearer ${API_KEY}`);
    expect(flat["content-type"]).toMatch(/^multipart\/form-data; boundary=/);

    // The body may be opaque for FormData; only inspect it when it is readable.
    if (body instanceof FormData) {
      expect(body.get("model")).toBe("whisper-large-v3-turbo");
      expect(body.get("response_format")).toBe("verbose_json");
      expect(body.get("temperature")).toBe("0");
      expect(body.get("file")).toBeInstanceOf(File);
      expect(body.has("language")).toBe(false);
    } else if (typeof body === "string") {
      expect(body).toContain('name="model"');
      expect(body).toContain("verbose_json");
      expect(body).toContain('filename="clip.m4a"');
    }
  });
});

// 2026-10-11, docs/tutor-focus-issues.md Issue 3: "dynamic programming" came
// back as "tandem programming" because Whisper got no vocabulary hint.
describe("transcribeWithGroq vocabulary prompt", () => {
  /** The multipart `prompt` part as sent, or null when absent. The mock may hand over FormData or its text. */
  async function sentPrompt(language: string | undefined): Promise<string | null> {
    let body: unknown;
    intercept().reply(200, (opts) => {
      body = opts.body;
      return { text: "ok", duration: 1 };
    });
    await callGroq(language === undefined ? {} : { language });
    if (body instanceof FormData) return (body.get("prompt") as string | null) ?? null;
    expect(typeof body).toBe("string");
    const match = /name="prompt"\r?\n\r?\n([\s\S]*?)\r?\n--/.exec(body as string);
    return match ? match[1] : null;
  }

  it("sends the English vocabulary for language en", async () => {
    expect(await sentPrompt("en")).toBe(STT_PROMPT_EN);
  });

  it("sends the Arabic-framed vocabulary for language ar", async () => {
    expect(await sentPrompt("ar")).toBe(STT_PROMPT_AR);
  });

  it("sends no prompt for another language or none", async () => {
    expect(await sentPrompt("fr")).toBeNull();
    expect(await sentPrompt(undefined)).toBeNull();
  });

  it("keeps both prompts generic and under Whisper's 224-token limit", () => {
    // Roughly four characters a token; far below the limit either way.
    for (const prompt of [STT_PROMPT_EN, STT_PROMPT_AR]) expect(prompt.length).toBeLessThan(600);
    expect(STT_PROMPT_EN).toContain("dynamic programming");
  });
});

describe("transcribeWithGroq error mapping", () => {
  it.each([429, 401])("%i -> VOICE_UNAVAILABLE", async (status) => {
    intercept().reply(status, { error: { message: "secret upstream detail" } });
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("VOICE_UNAVAILABLE");
    expect(err.message).not.toContain("secret upstream detail");
  });

  it.each([500, 503])("%i -> VOICE_BUSY", async (status) => {
    intercept().reply(status, { error: { message: "upstream down" } });
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("VOICE_BUSY");
    expect(err.retryable).toBe(true);
  });

  it("a network error -> VOICE_BUSY", async () => {
    intercept().replyWithError(new Error("connection reset"));
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("VOICE_BUSY");
  });

  it.each([400, 413, 415])("%i -> BAD_REQUEST", async (status) => {
    intercept().reply(status, { error: { message: "cannot read audio" } });
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("BAD_REQUEST");
  });

  it("a malformed JSON body -> VOICE_BUSY", async () => {
    intercept().reply(200, "this is not json {", { headers: { "content-type": "application/json" } });
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("VOICE_BUSY");
  });

  it("a JSON body without text -> VOICE_BUSY", async () => {
    intercept().reply(200, { duration: 3 });
    const err = await expectAppError(callGroq());
    expect(err.code).toBe("VOICE_BUSY");
  });
});

describe("parseAudioType()", () => {
  it("accepts every listed type", () => {
    for (const type of Object.keys(AUDIO_TYPES)) {
      expect(parseAudioType(type)).toBe(type);
    }
  });

  it("drops parameters and lowercases", () => {
    expect(parseAudioType("Audio/MP4; codecs=mp4a.40.2")).toBe("audio/mp4");
    expect(parseAudioType("  audio/ogg ;codecs=opus")).toBe("audio/ogg");
  });

  it("rejects unknown, empty, missing and prototype-key types", () => {
    expect(parseAudioType("application/json")).toBeNull();
    expect(parseAudioType("video/mp4")).toBeNull();
    expect(parseAudioType("")).toBeNull();
    expect(parseAudioType(null)).toBeNull();
    expect(parseAudioType(undefined)).toBeNull();
    expect(parseAudioType("constructor")).toBeNull();
    expect(parseAudioType("__proto__")).toBeNull();
  });
});
