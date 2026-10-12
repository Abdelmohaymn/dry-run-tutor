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

async function sendJudge(installId: string) {
  return SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "I would use a hash map." }],
      ended_by: "user",
    }),
  });
}

// US2 scenario 9, FR-013a.
describe("POST /v1/judge — assessed exactly once", () => {
  it("a second judge call for the same session returns SESSION_ALREADY_JUDGED and makes zero provider calls", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
            approach_quote: "I would use a hash map",
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
            feedback: "Some feedback here.",
          }),
        ),
      );

    const first = await sendJudge(installId);
    expect(first.status).toBe(200);
    await first.json();

    // No second interceptor registered — a provider call here fails the test.
    const second = await sendJudge(installId);
    expect(second.status).toBe(409);
    const body = (await second.json()) as any;
    expect(body.error.code).toBe("SESSION_ALREADY_JUDGED");
    expect(body.error.retryable).toBe(false);
  });
});
