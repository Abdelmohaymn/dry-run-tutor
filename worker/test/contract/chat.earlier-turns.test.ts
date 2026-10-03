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

async function chat(body: Record<string, unknown>, replies: string[]) {
  const sent: string[] = [];
  for (const reply of replies) {
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        (opts) => {
          sent.push(opts.body as string);
          return groqStreamBody(reply);
        },
        { headers: { "content-type": "text/event-stream" } },
      );
  }
  const installId = await mintInstallId();
  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", ...body }),
  });
  expect(res.status).toBe(200);
  const frames = await readChatSSE(res);
  const text = frames
    .filter((f) => f.event === "token")
    .map((f) => (f.data as { text: string }).text)
    .join("");
  return { text, sent };
}

// After a summary, the learner's older turns are no longer in `messages`.
// A word they said back then was blocked again, and the tutor's replies
// using it were rewritten or replaced (found 2026-09-25).
describe("POST /v1/chat — earlier_learner_turns count as said, but never reach the provider", () => {
  const current = { messages: [{ role: "user", text: "what should I store for each number" }] };
  const reply = "A hash map from each value to where you saw it.";

  it("a word said only in an earlier turn is not blocked", async () => {
    const { text, sent } = await chat({ ...current, earlier_learner_turns: ["I would use a hashmap"] }, [reply]);
    expect(text).toBe(reply);
    expect(sent).toHaveLength(1);
    expect(sent[0]).not.toContain("I would use a hashmap");
  });

  it("without it, the same reply is blocked and rewritten", async () => {
    const { text, sent } = await chat(current, [reply, "What would you want to remember about each number?"]);
    expect(sent).toHaveLength(2);
    expect(text).toBe("What would you want to remember about each number?");
  });
});
