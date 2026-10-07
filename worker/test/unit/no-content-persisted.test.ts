import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "../contract/helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const TABLES = ["config", "devices", "device_day", "provider_day", "notify_signup"];

async function dumpAllTables(): Promise<string> {
  const dumps = await Promise.all(
    TABLES.map(async (t) => JSON.stringify((await env.DB.prepare(`SELECT * FROM ${t}`).all()).results)),
  );
  return dumps.join("\n");
}

// FR-026, SC-006 support. Sweeps every D1 table after a full session.
describe("no D1 table ever holds a learner key, a message, a summary, or a reply", () => {
  it("after a full chat + hint + judge + daily session, none of the secret markers are anywhere in D1", async () => {
    const SECRET_KEY = "gsk_the_learners_actual_secret_key_value";
    const LEARNER_TEXT = "MARKER_LEARNER_SAID_THIS_EXACT_PHRASE";
    const TUTOR_REPLY = "MARKER_TUTOR_REPLIED_WITH_THIS_EXACT_PHRASE";
    const JUDGE_FEEDBACK = "MARKER_JUDGE_FEEDBACK_EXACT_PHRASE";

    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody(TUTOR_REPLY), { headers: { "content-type": "text/event-stream" } });
    const chatRes = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": SECRET_KEY, "content-type": "application/json" },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: LEARNER_TEXT }] }),
    });
    await readChatSSE(chatRes);

    const hintRes = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": SECRET_KEY, "content-type": "application/json" },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: LEARNER_TEXT }],
        hint_requested: true,
      }),
    });
    await readChatSSE(hintRes);

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
            matched_approach: "hashmap",
            matched_verdict: "optimal",
            insights_hit: [],
            insights_missed: [],
            wrong_turns_taken: [],
            complexity: {
              user_claimed_time: null,
              user_claimed_space: null,
              reference_time: "O(n)",
              reference_space: "O(n)",
              assessment: "not_stated",
            },
            verdict: "unclear",
            confidence: 0.5,
            feedback: JUDGE_FEEDBACK,
          }),
        ),
      );
    const judgeRes = await SELF.fetch("https://worker.test/v1/judge", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": SECRET_KEY, "content-type": "application/json" },
      body: JSON.stringify({
        problem_id: "vp-0001",
        conversation: [{ role: "user", text: LEARNER_TEXT }],
        ended_by: "user",
      }),
    });
    await judgeRes.json();

    await SELF.fetch(`https://worker.test/v1/daily?date=${new Date().toISOString().slice(0, 10)}`, {
      headers: { "X-Install-Id": installId },
    });

    const blob = await dumpAllTables();
    expect(blob).not.toContain(SECRET_KEY);
    expect(blob).not.toContain(LEARNER_TEXT);
    expect(blob).not.toContain(TUTOR_REPLY);
    expect(blob).not.toContain(JUDGE_FEEDBACK);
  });

  it("a /v1/stt call leaves neither the transcript nor the audio in any D1 table", async () => {
    const TRANSCRIPT = "MARKER_STT_TRANSCRIPT_EXACT_PHRASE";
    const AUDIO_MARKER = "MARKER_STT_AUDIO_BYTES_EXACT_PHRASE";

    const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
    const cfg = JSON.parse(row!.payload);
    cfg.voice = { enabled: true, seconds_per_device: 300, max_clip_seconds: 120 };
    await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();

    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: "/openai/v1/audio/transcriptions", method: "POST" })
      .reply(200, JSON.stringify({ text: TRANSCRIPT, duration: 30 }), {
        headers: { "content-type": "application/json" },
      });
    const res = await SELF.fetch("https://worker.test/v1/stt?language=en", {
      method: "POST",
      headers: { "X-Install-Id": installId, "content-type": "audio/mp4" },
      body: new TextEncoder().encode(AUDIO_MARKER),
    });
    expect(res.status).toBe(200);
    expect(((await res.json()) as { text: string }).text).toBe(TRANSCRIPT);

    // The call did charge the device (so the devices row was written), yet
    // nothing in any table carries the content.
    const blob = await dumpAllTables();
    expect(blob).not.toContain(TRANSCRIPT);
    expect(blob).not.toContain(AUDIO_MARKER);
    expect(blob).not.toContain("MARKER_STT");
  });
});
