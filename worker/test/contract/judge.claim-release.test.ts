import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, interceptEvidenceCheck, mintInstallId, interceptFinalCheckUnusable } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function sendJudge(installId: string) {
  return SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      conversation: [{ role: "user", text: "I would use a hash map keyed by value." }],
      ended_by: "user",
    }),
  });
}

const VALID_ASSESSMENT = JSON.stringify({
  approach_quote: "I would use a hash map keyed by value",
  matched_approach: "hashmap",
  matched_verdict: "optimal",
  insights_hit: [{ quote: "I would use a hash map keyed by value", key: "complement_lookup" }],
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
});

function mockProviderStatus(status: number, body: object = { error: { message: "upstream said no" } }) {
  interceptFinalCheckUnusable();
  fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(status, body);
}

function mockProviderOk() {
  interceptFinalCheckUnusable();
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqCompletionBody(VALID_ASSESSMENT));
  interceptEvidenceCheck();
}

// Constitution VIII, FR-013a. claimJudge() runs BEFORE the provider call so a
// second judge cannot run while the first is in flight — but the claim must be
// handed back when no assessment comes back at all. Without the release, a
// transient upstream fault answers "retryable: true" and then every retry
// returns SESSION_ALREADY_JUDGED: a dead end, no assessment, ever.
describe("POST /v1/judge — a failed assessment is not spent", () => {
  it("a provider fault is retryable IN FACT, not just in the envelope", async () => {
    const installId = await mintInstallId();

    mockProviderStatus(503);
    const failed = await sendJudge(installId);
    expect(failed.status).toBe(502);
    const failedBody = (await failed.json()) as any;
    expect(failedBody.error.retryable).toBe(true);

    mockProviderOk();
    const retried = await sendJudge(installId);
    expect(retried.status).toBe(200);
    expect((await retried.json()) as any).toHaveProperty("editorial");
  });

  it("an unparseable provider body also hands the claim back", async () => {
    const installId = await mintInstallId();

    interceptFinalCheckUnusable();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("this is not JSON at all"));
    const failed = await sendJudge(installId);
    expect(failed.status).toBe(502);

    mockProviderOk();
    expect((await sendJudge(installId)).status).toBe(200);
  });

  it("the claim still blocks a SECOND assessment once one has been delivered", async () => {
    const installId = await mintInstallId();

    mockProviderOk();
    expect((await sendJudge(installId)).status).toBe(200);

    // No interceptor: a provider call here fails the test.
    const second = await sendJudge(installId);
    expect(second.status).toBe(409);
    expect(((await second.json()) as any).error.code).toBe("SESSION_ALREADY_JUDGED");
  });
});
