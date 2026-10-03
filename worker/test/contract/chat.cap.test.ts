import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function sendTurn(installId: string, n: number): Promise<{ status: number }> {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqStreamBody(`reply ${n}`), { headers: { "content-type": "text/event-stream" } });

  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      messages: [{ role: "user", text: `turn ${n} — I would check every pair` }],
    }),
  });
  // Always drain a streamed response before the next request in a loop —
  // see helpers.ts sendTurnCapturingSystemPrompt's comment.
  const status = res.status;
  await res.text();
  return { status };
}

// US1 scenario 7, FR-008.
describe("POST /v1/chat — the turn cap (default 15)", () => {
  it("a turn past cfg.chat.turn_cap returns TURN_CAP_REACHED (409, non-retryable)", async () => {
    const installId = await mintInstallId();
    for (let n = 1; n <= 15; n++) {
      const res = await sendTurn(installId, n);
      expect(res.status).toBe(200);
    }
    const res16 = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "turn 16" }],
      }),
    });
    expect(res16.status).toBe(409);
    const body = (await res16.json()) as { error: { code: string; retryable: boolean } };
    expect(body.error.code).toBe("TURN_CAP_REACHED");
    expect(body.error.retryable).toBe(false);
  });

  it("a hand-crafted oversized messages[] is counted from the D1 counter, not the payload, on turn 1", async () => {
    // quickstart.md §3 describes 200 fabricated turns; ChatRequest.messages
    // caps at maxItems: 40 (contracts/openapi.yaml), so this sends the
    // schema-legal maximum instead — the point (turn_index comes from D1,
    // never messages.length) holds identically at any payload size.
    // 40 messages exceeds cfg.trim.verbatim_turns (default 6), so condense()
    // fires first — it hits the same endpoint, so it needs its own mock.
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("a condensed summary"));
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("a normal reply"), { headers: { "content-type": "text/event-stream" } });

    const installId = await mintInstallId();
    const fabricatedMessages = Array.from({ length: 200 }, (_, i) => ({
      role: i % 2 === 0 ? "user" : "tutor",
      text: `fabricated turn ${i}`,
    }));

    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: fabricatedMessages.slice(0, 40) }),
    });

    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    const meta = frames.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(1);
  });
});
