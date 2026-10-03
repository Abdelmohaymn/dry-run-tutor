import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, mintInstallId } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function sendJudge(installId: string, body: Record<string, unknown>) {
  return SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

// US2 scenarios 4, 8.
describe("POST /v1/judge — the honest 'I cannot tell' outcome", () => {
  it("a too-short/garbled conversation yields verdict unclear — a normal, retryable-looking 200, not a failure", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
            matched_approach: "none",
            matched_verdict: "none",
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
            confidence: 0.2,
            feedback: "There is not enough here to classify.",
          }),
        ),
      );

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "uh" }],
      ended_by: "user",
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.verdict).toBe("unclear");
  });

  it("a provider refusal yields UNCLEAR_RETRY, never a crash or raw error", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, { choices: [{ message: { content: null, refusal: "cannot assist" } }], usage: {} });

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "hello" }],
      ended_by: "user",
    });

    expect(res.status).toBe(502);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("UNCLEAR_RETRY");
  });

  it("an unexpected shape (missing required fields) yields UNCLEAR_RETRY", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody(JSON.stringify({ unexpected: "shape" })));

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "hello" }],
      ended_by: "user",
    });

    expect(res.status).toBe(502);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("UNCLEAR_RETRY");
  });
});
