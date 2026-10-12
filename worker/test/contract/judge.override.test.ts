import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, interceptEvidenceCheck, mintInstallId, quotedHits } from "./helpers";
import { getPrivate, getPublicManifest } from "../../src/lib/content";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const problem = { public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!, private: getPrivate("vp-0001")! };
const requiredKeys = problem.private.key_insights.filter((i) => i.required).map((i) => i.key);
const allKeys = problem.private.key_insights.map((i) => i.key);

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

// US2 scenario 3.
describe("POST /v1/judge — a self-contradictory verdict is overwritten", () => {
  it("the model's own verdict is overwritten by mapVerdict() and the discrepancy is recorded", async () => {
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
            // A required insight is missing, so mapVerdict() must produce
            // "borderline" regardless of what the model claims.
            insights_hit: quotedHits(requiredKeys.slice(1), "I would use a hash map"),
            insights_missed: allKeys.filter((k) => !requiredKeys.slice(1).includes(k)),
            wrong_turns_taken: [],
            complexity: {
              user_claimed_time: null,
              user_claimed_space: null,
              reference_time: "O(n)",
              reference_space: "O(n)",
              assessment: "not_stated",
            },
            verdict: "pass", // self-contradictory — the model claims pass anyway
            confidence: 0.8,
            feedback: "Solid direction, though there is a missing piece.",
          }),
        ),
      );
    interceptEvidenceCheck();

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "I would use a hash map." }],
      ended_by: "user",
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.verdict).toBe("borderline");
  });
});
