import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, mintInstallId, interceptFinalCheckUnusable } from "./helpers";

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

// US2 scenario 2, FR-015.
describe("POST /v1/judge — nothing authored matches", () => {
  it("a conversation matching nothing authored reports matched_approach: 'none' rather than inventing one", async () => {
    const installId = await mintInstallId();
    interceptFinalCheckUnusable();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
            approach_quote: "",
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
            confidence: 0.3,
            feedback: "It is hard to tell what approach you were reaching for here.",
          }),
        ),
      );

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "I am not sure how to start." }],
      ended_by: "user",
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.matched_approach).toBe("none");
  });
});
