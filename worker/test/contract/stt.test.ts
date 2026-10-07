import { env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_ORIGIN,
  GROQ_STT_PATH,
  groqTranscriptionBody,
  mintInstallId,
  postStt,
  setVoiceConfig,
} from "./helpers";

// Feature 008: POST /v1/stt. With net connect disabled, a request that reaches
// Groq without a registered interceptor fails (-> VOICE_BUSY 503), so the
// refusal statuses below prove "no Groq call". An interceptor that is
// registered but never consumed fails assertNoPendingInterceptors().
beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const AUDIO = new Uint8Array([1, 2, 3, 4, 5, 6, 7, 8]);

function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

function yesterdayUtc(): string {
  return new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

/** The install id is `<device_hash>.<sig>`; the devices row is keyed by the hash. */
function deviceHashOf(installId: string): string {
  return installId.split(".")[0];
}

async function voiceRow(installId: string) {
  return env.DB.prepare("SELECT voice_date, voice_seconds FROM devices WHERE device_hash = ?")
    .bind(deviceHashOf(installId))
    .first<{ voice_date: string | null; voice_seconds: number }>();
}

async function setUsage(installId: string, date: string, seconds: number): Promise<void> {
  await env.DB.prepare("UPDATE devices SET voice_date = ?, voice_seconds = ? WHERE device_hash = ?")
    .bind(date, seconds, deviceHashOf(installId))
    .run();
}

function groqOk(text: string, duration: number): void {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_STT_PATH, method: "POST" })
    .reply(200, groqTranscriptionBody(text, duration));
}

function groqStatus(status: number): void {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_STT_PATH, method: "POST" })
    .reply(status, { error: { message: "upstream detail that must never leak" } });
}

async function errorOf(res: Response) {
  return ((await res.json()) as { error: { code: string; retryable: boolean } }).error;
}

describe("POST /v1/stt — voice off", () => {
  it("(a) voice block absent -> 503 VOICE_UNAVAILABLE, no Groq call", async () => {
    const installId = await mintInstallId();

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(503);
    const error = await errorOf(res);
    expect(error.code).toBe("VOICE_UNAVAILABLE");
    expect(error.retryable).toBe(false);
  });

  it("(b) enabled: false -> 503 VOICE_UNAVAILABLE, no Groq call", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig({ enabled: false });

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(503);
    expect((await errorOf(res)).code).toBe("VOICE_UNAVAILABLE");
  });
});

describe("POST /v1/stt — identity", () => {
  it("(c) missing X-Install-Id -> 400 BAD_REQUEST", async () => {
    await setVoiceConfig();

    const res = await postStt(null, AUDIO);

    expect(res.status).toBe(400);
    expect((await errorOf(res)).code).toBe("BAD_REQUEST");
  });
});

describe("POST /v1/stt — transcription and the daily allowance", () => {
  it("(d) happy path: a 30 s clip returns the text and 270 seconds left", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    groqOk("hello from the clip", 30);

    const res = await postStt(installId, AUDIO, { language: "en" });

    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("private, no-store");
    expect(await res.json()).toEqual({
      text: "hello from the clip",
      seconds_left: 270,
      max_clip_seconds: 120,
    });
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 30 });
  });

  it("(e)+(f) 120 -> 180 left, 120 -> 60 left, 60 -> 0 left; then VOICE_EXHAUSTED without a Groq call", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();

    groqOk("first", 120);
    const first = await postStt(installId, AUDIO);
    expect(first.status).toBe(200);
    expect(((await first.json()) as { seconds_left: number }).seconds_left).toBe(180);

    groqOk("second", 120);
    const second = await postStt(installId, AUDIO);
    expect(second.status).toBe(200);
    expect(((await second.json()) as { seconds_left: number }).seconds_left).toBe(60);

    groqOk("third", 60);
    const third = await postStt(installId, AUDIO);
    expect(third.status).toBe(200);
    expect(((await third.json()) as { seconds_left: number }).seconds_left).toBe(0);

    // (f) No interceptor is registered: a Groq call would surface as VOICE_BUSY.
    const fourth = await postStt(installId, AUDIO);
    expect(fourth.status).toBe(429);
    const error = await errorOf(fourth);
    expect(error.code).toBe("VOICE_EXHAUSTED");
    expect(error.retryable).toBe(false);
    expect((await voiceRow(installId))!.voice_seconds).toBe(300);
  });

  it("(g) overrun: 250 used, a 70 s clip still returns text, seconds_left 0, D1 holds 320", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    await setUsage(installId, todayUtc(), 250);
    groqOk("the last words", 70);

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      text: "the last words",
      seconds_left: 0,
      max_clip_seconds: 120,
    });
    expect((await voiceRow(installId))!.voice_seconds).toBe(320);
  });

  it("(h) rollover: yesterday's 300 used seconds do not count today", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    await setUsage(installId, yesterdayUtc(), 300);
    groqOk("a new day", 20);

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(200);
    expect(((await res.json()) as { seconds_left: number }).seconds_left).toBe(280);
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 20 });
  });

  it("(n) lowering seconds_per_device applies to the very next request", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    groqOk("one", 50);
    const first = await postStt(installId, AUDIO);
    expect(((await first.json()) as { seconds_left: number }).seconds_left).toBe(250);

    await setVoiceConfig({ seconds_per_device: 60 });
    groqOk("two", 5);
    const second = await postStt(installId, AUDIO);

    expect(second.status).toBe(200);
    // 55 used of a cap of 60.
    expect(((await second.json()) as { seconds_left: number }).seconds_left).toBe(5);

    // Used (55) + a further 10 s passes the lowered cap: the clip is served and charged.
    groqOk("three", 10);
    const third = await postStt(installId, AUDIO);
    expect(((await third.json()) as { seconds_left: number }).seconds_left).toBe(0);

    const fourth = await postStt(installId, AUDIO);
    expect(fourth.status).toBe(429);
    expect((await errorOf(fourth)).code).toBe("VOICE_EXHAUSTED");
  });
});

describe("POST /v1/stt — Groq failures charge nothing", () => {
  it("(i) Groq 429 -> 503 VOICE_UNAVAILABLE (not retryable), D1 unchanged", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    await setUsage(installId, todayUtc(), 40);
    groqStatus(429);

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(503);
    const error = await errorOf(res);
    expect(error.code).toBe("VOICE_UNAVAILABLE");
    expect(error.retryable).toBe(false);
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 40 });
  });

  it("(i2) Groq 500 -> 503 VOICE_BUSY (retryable), D1 unchanged; the same bytes sent again are charged once", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    await setUsage(installId, todayUtc(), 40);
    groqStatus(500);

    const failed = await postStt(installId, AUDIO);

    expect(failed.status).toBe(503);
    const error = await errorOf(failed);
    expect(error.code).toBe("VOICE_BUSY");
    expect(error.retryable).toBe(true);
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 40 });

    groqOk("the retried clip", 25);
    const retried = await postStt(installId, AUDIO);

    expect(retried.status).toBe(200);
    expect(await retried.json()).toEqual({
      text: "the retried clip",
      seconds_left: 235,
      max_clip_seconds: 120,
    });
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 65 });
  });

  it("(j) a clip over max_clip_seconds is charged in full and its text is still returned", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    groqOk("far too long", 130);

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({
      text: "far too long",
      seconds_left: 170,
      max_clip_seconds: 120,
    });
    expect(await voiceRow(installId)).toEqual({ voice_date: todayUtc(), voice_seconds: 130 });
  });

  it("(j2) a hold in flight counts against the next request", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();
    // 190 used + one 120 s hold already taken by a request still at Groq.
    await setUsage(installId, todayUtc(), 310);

    const res = await postStt(installId, AUDIO);

    expect(res.status).toBe(429);
    expect((await errorOf(res)).code).toBe("VOICE_EXHAUSTED");
  });
});

describe("POST /v1/stt — request validation (no Groq call)", () => {
  it("(k) wrong content type -> 400 BAD_REQUEST", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();

    const res = await postStt(installId, AUDIO, { contentType: "application/json" });

    expect(res.status).toBe(400);
    expect((await errorOf(res)).code).toBe("BAD_REQUEST");
    expect(await voiceRow(installId)).toEqual({ voice_date: null, voice_seconds: 0 });
  });

  it("(l) a body over 4 MiB -> 400 BAD_REQUEST", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();

    const res = await postStt(installId, new Uint8Array(4 * 1024 * 1024 + 1));

    expect(res.status).toBe(400);
    expect((await errorOf(res)).code).toBe("BAD_REQUEST");
    expect(await voiceRow(installId)).toEqual({ voice_date: null, voice_seconds: 0 });
  });

  it("(m) language=english (not ISO-639-1) -> 400 BAD_REQUEST", async () => {
    const installId = await mintInstallId();
    await setVoiceConfig();

    const res = await postStt(installId, AUDIO, { language: "english" });

    expect(res.status).toBe(400);
    expect((await errorOf(res)).code).toBe("BAD_REQUEST");
    expect(await voiceRow(installId)).toEqual({ voice_date: null, voice_seconds: 0 });
  });
});
