import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// US1 scenarios 1-3. OpenAPI cannot type SSE frames structurally, so this
// test is the only thing that does.
describe("POST /v1/chat — SSE frame order and MetaFrame shape", () => {
  it("frames arrive token(s)..., one meta, done — and meta validates against MetaFrame", async () => {
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What are you actually searching for at each step?"), {
        headers: { "content-type": "text/event-stream" },
      });

    const installId = await mintInstallId();
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "I could check every pair with two nested loops" }],
      }),
    });

    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);

    expect(frames.length).toBeGreaterThanOrEqual(2);
    expect(frames[frames.length - 1].event).toBe("done");
    expect(frames[frames.length - 1].data).toEqual({});

    const metaFrames = frames.filter((f) => f.event === "meta");
    expect(metaFrames).toHaveLength(1);
    const tokenFrames = frames.filter((f) => f.event === "token");
    expect(tokenFrames.length).toBeGreaterThanOrEqual(1);

    // Every frame before `meta` is a token frame; every frame after it is `done`.
    const metaIndex = frames.findIndex((f) => f.event === "meta");
    for (let i = 0; i < metaIndex; i++) expect(frames[i].event).toBe("token");
    for (let i = metaIndex + 1; i < frames.length; i++) expect(frames[i].event).toBe("done");

    const meta = metaFrames[0].data as Record<string, unknown>;
    const allowedKeys = new Set([
      "turn_index",
      "turns_remaining",
      "hints_revealed",
      "hints_remaining",
      "summary",
      "summary_covers",
      "session_ended",
      "leak_blocked",
      "ready_to_finish",
    ]);
    for (const k of Object.keys(meta)) {
      expect(allowedKeys.has(k), `unexpected MetaFrame key '${k}'`).toBe(true);
    }
    for (const required of ["turn_index", "turns_remaining", "hints_revealed", "hints_remaining", "session_ended", "leak_blocked"]) {
      expect(meta, `MetaFrame missing required key '${required}'`).toHaveProperty(required);
    }
    expect(typeof meta.turn_index).toBe("number");
    expect(typeof meta.turns_remaining).toBe("number");
    expect(typeof meta.hints_revealed).toBe("number");
    expect(typeof meta.hints_remaining).toBe("number");
    expect([null, "user", "cap", "solution"]).toContain(meta.session_ended);
    expect(typeof meta.leak_blocked).toBe("boolean");
  });
});
