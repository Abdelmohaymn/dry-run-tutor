import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  groqStreamBody,
  mintInstallIdFor,
  readChatSSE,
} from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function trial(installId: string, body: Record<string, unknown>) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ problem_id: "vp-0001", ...body }),
  });
}

function mockChat() {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqStreamBody("Let's think this through."), { headers: { "content-type": "text/event-stream" } });
}

function mockJudge() {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(
      200,
      groqCompletionBody(
        JSON.stringify({
          approach_quote: "hash map idea",
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
}

// US1 AS-1: the same phone keeps its spent taster across a reinstall.
describe("a reinstall does not reset the free trial", () => {
  it("the same device_id is refused a second taster after its first was completed", async () => {
    const first = await mintInstallIdFor("feedface00112233");

    mockChat();
    await readChatSSE(await trial(first, { mode: "chat", messages: [{ role: "user", text: "hash map idea" }] }));
    mockJudge();
    const judged = await trial(first, {
      mode: "judge",
      conversation: [{ role: "user", text: "hash map idea" }],
      ended_by: "user",
    });
    expect(judged.status).toBe(200);
    await judged.json();

    // Reinstall: the app registers again with the same Android ID.
    const second = await mintInstallIdFor("feedface00112233");
    expect(second).toBe(first);

    const again = await trial(second, { mode: "chat", messages: [{ role: "user", text: "starting again" }] });
    expect(again.status).toBe(409);
    expect(((await again.json()) as { error: { code: string } }).error.code).toBe("TRIAL_CONSUMED");
  });

  it("a different device_id still gets its own taster", async () => {
    const other = await mintInstallIdFor("0badc0de44556677");
    mockChat();
    const res = await trial(other, { mode: "chat", messages: [{ role: "user", text: "hash map idea" }] });
    expect(res.status).toBe(200);
    await readChatSSE(res);
  });
});
