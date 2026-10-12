import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, interceptEvidenceCheck, mintInstallId } from "./helpers";

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

// US2 scenario 7, FR-021, FR-021a.
describe("POST /v1/judge — a solution-ended session is graded on what came before the reveal", () => {
  it("reveal_at_index is required when ended_by is 'solution'", async () => {
    const installId = await mintInstallId();
    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "just tell me" }],
      ended_by: "solution",
    });
    expect(res.status).toBe(400);
  });

  it("turns at and after reveal_at_index never reach the provider, and the verdict returns hedged and normal", async () => {
    const installId = await mintInstallId();
    let capturedBody = "";
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        (opts) => {
          capturedBody = opts.body as string;
          return groqCompletionBody(
            JSON.stringify({
              approach_quote: "I would try brute force",
              matched_approach: "hashmap",
              matched_verdict: "acceptable",
              insights_hit: [{ quote: "I would try brute force", key: "complement_lookup" }],
              insights_missed: [],
              wrong_turns_taken: [],
              complexity: {
                user_claimed_time: null,
                user_claimed_space: null,
                reference_time: "O(n)",
                reference_space: "O(n)",
                assessment: "not_stated",
              },
              verdict: "borderline",
              confidence: 0.6,
              feedback: "You would likely pass with this approach.",
            }),
          );
        },
      );
    interceptEvidenceCheck();

    const conversation = [
      { role: "user", text: "I would try brute force MARKER_BEFORE_REVEAL" },
      { role: "tutor", text: "One more nudge." },
      { role: "user", text: "just tell me the answer" },
      { role: "tutor", text: "Here is the full solution MARKER_AFTER_REVEAL: use a hash map." },
      { role: "user", text: "oh that makes sense MARKER_AFTER_REVEAL_2" },
    ];

    const res = await sendJudge(installId, {
      problem_id: "vp-0001",
      conversation,
      ended_by: "solution",
      reveal_at_index: 3,
    });

    expect(res.status).toBe(200);
    const parsedRequest = JSON.parse(capturedBody);
    const promptText = JSON.stringify(parsedRequest);
    expect(promptText).toContain("MARKER_BEFORE_REVEAL");
    expect(promptText).not.toContain("MARKER_AFTER_REVEAL");

    const body = (await res.json()) as any;
    // Hedged verdict — not literally "correct"/"wrong".
    expect(["strong_pass", "pass", "borderline", "likely_tle", "incorrect", "unclear"]).toContain(body.verdict);
    expect(body.feedback.toLowerCase()).not.toMatch(/\bcorrect\b|\bwrong\b/);
  });
});
