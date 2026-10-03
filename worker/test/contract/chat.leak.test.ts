import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { LEAK_BLOCKED_FALLBACK } from "../../src/prompts/tutor";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId, readChatSSE, systemPromptOf } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

/** Queues one provider reply per entry; a number is an HTTP error status. */
function queueReplies(replies: Array<string | number>, sentBodies: string[]) {
  for (const reply of replies) {
    const interceptor = fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" });
    if (typeof reply === "number") {
      interceptor.reply(reply, (opts) => {
        sentBodies.push(opts.body as string);
        return "upstream error";
      });
    } else {
      interceptor.reply(
        200,
        (opts) => {
          sentBodies.push(opts.body as string);
          return groqStreamBody(reply);
        },
        { headers: { "content-type": "text/event-stream" } },
      );
    }
  }
}

async function chat(replies: Array<string | number>) {
  const sentBodies: string[] = [];
  queueReplies(replies, sentBodies);
  const installId = await mintInstallId();
  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      messages: [{ role: "user", text: "I could check every pair with two nested loops" }],
    }),
  });
  expect(res.status).toBe(200);
  const frames = await readChatSSE(res);
  const text = frames
    .filter((f) => f.event === "token")
    .map((f) => (f.data as { text: string }).text)
    .join("");
  const meta = frames.find((f) => f.event === "meta")!.data as { leak_blocked: boolean };
  return { text, meta, sentBodies };
}

describe("POST /v1/chat — a blocked draft is rewritten once before anything is sent", () => {
  it("a clean draft goes out as written, with one provider call", async () => {
    const { text, meta, sentBodies } = await chat(["Good start. What does that cost you?"]);
    expect(text).toBe("Good start. What does that cost you?");
    expect(meta.leak_blocked).toBe(false);
    expect(sentBodies).toHaveLength(1);
  });

  it("a blocked draft is rewritten with the word named as off-limits, and the rewrite is what the learner sees", async () => {
    const { text, meta, sentBodies } = await chat([
      "Good start. A hash map would help here.",
      "Good start. What could you remember about numbers you've already passed?",
    ]);
    expect(text).toBe("Good start. What could you remember about numbers you've already passed?");
    expect(meta.leak_blocked).toBe(false);
    expect(sentBodies).toHaveLength(2);
    expect(systemPromptOf(sentBodies[0])).not.toContain("FOR THIS REPLY ONLY");
    expect(systemPromptOf(sentBodies[1])).toContain('"hash map"');
    expect(text).not.toContain("hash map");
  });

  it("a blocked rewrite falls back to the first draft's clean sentences, with nothing glued on", async () => {
    const { text, meta } = await chat(["Good start. What does that cost you? A hash map would help.", "Try a hash map."]);
    expect(text).toBe("Good start. What does that cost you?");
    expect(text).not.toContain(LEAK_BLOCKED_FALLBACK);
    expect(meta.leak_blocked).toBe(false);
  });

  it("a blocked rewrite of a draft blocked at its first sentence becomes the fallback, flagged leak_blocked", async () => {
    const { text, meta } = await chat(["A hash map would help here. Try it.", "Use a hash map."]);
    expect(text).toBe(LEAK_BLOCKED_FALLBACK);
    expect(meta.leak_blocked).toBe(true);
  });

  it("a rewrite call that fails does not fail the turn", async () => {
    const { text, meta } = await chat(["A hash map would help here.", 500]);
    expect(text).toBe(LEAK_BLOCKED_FALLBACK);
    expect(meta.leak_blocked).toBe(true);
  });
});
