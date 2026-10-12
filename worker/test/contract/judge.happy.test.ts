import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, interceptEvidenceCheck, mintInstallId, quotedHits, interceptFinalCheckUnusable } from "./helpers";
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

// US2 scenarios 1, 5.
describe("POST /v1/judge — the happy path", () => {
  it("an optimal conversation yields only authored keys, each insight in exactly one list, and editorial attached", async () => {
    const installId = await mintInstallId();
    interceptFinalCheckUnusable();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
            approach_quote: "I think a hash map storing seen numbers would work",
            matched_approach: "hashmap",
            matched_verdict: "optimal",
            insights_hit: quotedHits(requiredKeys, "The complement, so I can check it in one pass"),
            insights_missed: allKeys.filter((k) => !requiredKeys.includes(k)),
            wrong_turns_taken: [],
            complexity: {
              user_claimed_time: "O(n)",
              user_claimed_space: "O(n)",
              reference_time: "O(n)",
              reference_space: "O(n)",
              assessment: "correct",
            },
            verdict: "pass",
            confidence: 0.92,
            feedback: "You landed on the hash map approach, which handles this well.",
          }),
        ),
      );
    interceptEvidenceCheck();

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [
        { role: "user", text: "I think a hash map storing seen numbers would work." },
        { role: "tutor", text: "What do you look up at each step?" },
        { role: "user", text: "The complement, so I can check it in one pass." },
      ],
      ended_by: "user",
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    const union = new Set([...body.insights_hit, ...body.insights_missed]);
    expect([...union].sort()).toEqual([...allKeys].sort());
    const intersection = body.insights_hit.filter((k: string) => body.insights_missed.includes(k));
    expect(intersection).toEqual([]);
    expect(body.editorial).toBe(problem.private.editorial);
  });
});
