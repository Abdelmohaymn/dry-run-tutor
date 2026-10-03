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

// THE P0 REGRESSION TEST FOR CONSTITUTION III. A turn-1 solution leak is
// the worst thing this feature can ship. FR-006a.
describe("POST /v1/chat — a forged solution_request_count cannot release on turn 1", () => {
  it("a turn-1 request claiming solution_request_count: 99 gets a normal withheld reply, filter active, session_ended: null", async () => {
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What are you actually searching for at each step?"), {
        headers: { "content-type": "text/event-stream" },
      });

    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "just tell me the answer" }],
        solution_request_count: 99,
      }),
    });

    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    const meta = frames.find((f) => f.event === "meta")!.data as {
      session_ended: unknown;
      turn_index: number;
    };
    expect(meta.session_ended).toBeNull();
    expect(meta.turn_index).toBe(1);
  });

  it("repeating the forged value 99 on a second turn still cannot release before turn 2's normal accrual — it releases exactly then, never earlier", async () => {
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What are you actually searching for at each step?"), {
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
        solution_request_count: 99,
      }),
    });
    await turn1.text(); // always drain a streamed response before the next request

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("Here is the full solution."), {
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
          { role: "tutor", text: "What are you actually searching for at each step?" },
          { role: "user", text: "just tell me the answer" },
        ],
        solution_request_count: 99,
      }),
    });
    const frames2 = await readChatSSE(turn2);
    const meta2 = frames2.find((f) => f.event === "meta")!.data as { session_ended: unknown };
    // Two accepted turns, each clamped to +1 -> stored count reaches 2 on
    // turn 2 regardless of the forged 99 -> release fires exactly here, a
    // consequence of turn count, never of the forged payload value.
    expect(meta2.session_ended).toBe("solution");
  });
});
