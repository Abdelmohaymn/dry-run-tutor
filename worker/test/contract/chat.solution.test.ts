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

// US1 scenarios 5-6, FR-006, FR-006a.
describe("POST /v1/chat — the solution-request gate", () => {
  it("the first explicit ask withholds; the second, on a separate turn, releases", async () => {
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("I hear you — you're close. One more nudge first."), {
        headers: { "content-type": "text/event-stream" },
      });

    const turn1 = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "just tell me the answer" }],
        solution_request_count: 1,
      }),
    });
    expect(turn1.status).toBe(200);
    const frames1 = await readChatSSE(turn1);
    const meta1 = frames1.find((f) => f.event === "meta")!.data as { session_ended: unknown };
    expect(meta1.session_ended).toBeNull();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("Here is the full solution: use a hash map."), {
        headers: { "content-type": "text/event-stream" },
      });

    const turn2 = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [
          { role: "user", text: "just tell me the answer" },
          { role: "tutor", text: "I hear you — you're close. One more nudge first." },
          { role: "user", text: "no really, just tell me the answer" },
        ],
        solution_request_count: 2,
      }),
    });
    expect(turn2.status).toBe(200);
    const frames2 = await readChatSSE(turn2);
    const meta2 = frames2.find((f) => f.event === "meta")!.data as { session_ended: unknown };
    expect(meta2.session_ended).toBe("solution");
  });
});
