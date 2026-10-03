import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, mintInstallId, readChatSSE } from "./helpers";

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

async function sendChatTurn(installId: string) {
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "one more turn" }] }),
  });
}

async function sendHintPull(installId: string) {
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      messages: [{ role: "user", text: "hint please" }],
      hint_requested: true,
    }),
  });
}

// FR-013b: a judged session is closed to both a further conversational turn
// and a further hint pull, with zero provider calls on either.
describe("POST /v1/chat — closed after /v1/judge", () => {
  it("a further conversational turn and a further hint pull each return SESSION_ALREADY_JUDGED", async () => {
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          JSON.stringify({
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
    const judged = await sendJudge(installId);
    expect(judged.status).toBe(200);
    await judged.json();

    // No provider interceptors registered below — either path calling the
    // provider fails the test via assertNoPendingInterceptors/disableNetConnect.
    // assertNotJudged() runs before streamSSE() starts on this path, so this
    // is a plain JSON error response, not an SSE frame (contrast the hint
    // path below, where the same check runs inside the stream).
    const turnRes = await sendChatTurn(installId);
    expect(turnRes.status).toBe(409);
    const turnBody = (await turnRes.json()) as any;
    expect(turnBody.error.code).toBe("SESSION_ALREADY_JUDGED");

    const hintRes = await sendHintPull(installId);
    expect(hintRes.status).toBe(200); // SSE stream already started
    const hintFrames = await readChatSSE(hintRes);
    const hintError = hintFrames.find((f) => f.event === "error")!;
    expect((hintError.data as any).error.code).toBe("SESSION_ALREADY_JUDGED");
  });
});
