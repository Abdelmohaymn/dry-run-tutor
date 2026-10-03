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

async function sendTurn(installId: string, text: string) {
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text }] }),
  });
}

// US1 scenarios 9-10, FR-037, FR-038, FR-039, Constitution VIII, SC-011.
describe("POST /v1/chat — provider errors surface as SSE error frames, never spend a turn", () => {
  it("429 surfaces as retryable RATE_LIMITED with backoff", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(429, "rate limited, slow down", { headers: { "retry-after": "20" } });

    const res = await sendTurn(installId, "hello");
    expect(res.status).toBe(200); // SSE stream already started
    const frames = await readChatSSE(res);
    const errorFrame = frames.find((f) => f.event === "error")!;
    const errorData = errorFrame.data as { error: { code: string; retryable: boolean; retry_after_ms: number } };
    expect(errorData.error.code).toBe("RATE_LIMITED");
    expect(errorData.error.retryable).toBe(true);
    expect(errorData.error.retry_after_ms).toBe(20000);
  });

  it("401 surfaces as non-retryable INVALID_KEY without discarding the conversation (turn is refunded, not spent)", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(401, "unauthorized");

    const res = await sendTurn(installId, "hello");
    const frames = await readChatSSE(res);
    const errorData = (frames.find((f) => f.event === "error")!.data) as {
      error: { code: string; retryable: boolean };
    };
    expect(errorData.error.code).toBe("INVALID_KEY");
    expect(errorData.error.retryable).toBe(false);

    // The turn was refunded — a retry with a working key reuses turn 1.
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("a real reply"), { headers: { "content-type": "text/event-stream" } });
    const retry = await sendTurn(installId, "hello again");
    const retryFrames = await readChatSSE(retry);
    const meta = retryFrames.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(1);
  });

  it("a malformed/unparseable provider stream surfaces as UNCLEAR_RETRY", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, "data: {not valid json at all\n\ndata: [DONE]\n\n", {
        headers: { "content-type": "text/event-stream" },
      });

    const res = await sendTurn(installId, "hello");
    const frames = await readChatSSE(res);
    const errorData = (frames.find((f) => f.event === "error")!.data) as { error: { code: string } };
    expect(errorData.error.code).toBe("UNCLEAR_RETRY");
  });

  it("a 5xx status surfaces as UNCLEAR_RETRY", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(503, "service unavailable");

    const res = await sendTurn(installId, "hello");
    const frames = await readChatSSE(res);
    const errorData = (frames.find((f) => f.event === "error")!.data) as { error: { code: string } };
    expect(errorData.error.code).toBe("UNCLEAR_RETRY");
  });

  it("no raw provider text appears in any response", async () => {
    const installId = await mintInstallId();
    const secretUpstreamText = "SECRET_UPSTREAM_DIAGNOSTIC_STACK_TRACE_TEXT";
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(500, secretUpstreamText);

    const res = await sendTurn(installId, "hello");
    const bodyText = await res.text();
    expect(bodyText).not.toContain(secretUpstreamText);
  });

  it("after a 429 on turn 4, the next request is turn 4 again, not turn 5 (turn not spent)", async () => {
    const installId = await mintInstallId();

    for (let n = 1; n <= 3; n++) {
      fetchMock
        .get(GROQ_ORIGIN)
        .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
        .reply(200, groqStreamBody(`reply ${n}`), { headers: { "content-type": "text/event-stream" } });
      const res = await sendTurn(installId, `turn ${n}`);
      await res.text();
    }

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(429, "rate limited");
    const res4a = await sendTurn(installId, "turn 4 attempt A");
    await res4a.text();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("turn 4 for real"), { headers: { "content-type": "text/event-stream" } });
    const res4b = await sendTurn(installId, "turn 4 attempt B");
    const frames4b = await readChatSSE(res4b);
    const meta = frames4b.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(4);
  });
});
