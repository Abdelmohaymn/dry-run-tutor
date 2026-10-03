import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function chat(messageCount: number) {
  const messages = Array.from({ length: messageCount }, (_, i) => ({
    role: i % 2 === 0 ? "user" : "tutor",
    text: `turn ${i}`,
  }));
  const installId = await mintInstallId();
  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", messages }),
  });
  const frames = await readChatSSE(res);
  return frames.find((f) => f.event === "meta")!.data as { summary?: string | null; summary_covers?: number };
}

// The app used to mark every replayed turn covered whenever a summary came
// back, though only the overflow was condensed. The newest turns were then
// never sent again (found on device 2026-09-25: a learner's full answer
// vanished from the next request). `summary_covers` says exactly how many.
describe("POST /v1/chat — summary_covers names how many leading messages the new summary covers", () => {
  it("9 replayed turns with 6 kept verbatim: the summary covers the first 3", async () => {
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("the learner explained a plan"));
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What would you check first?"), { headers: { "content-type": "text/event-stream" } });

    const meta = await chat(9);
    expect(meta.summary).toBe("the learner explained a plan");
    expect(meta.summary_covers).toBe(3);
  });

  it("no condensation, no summary_covers", async () => {
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What would you check first?"), { headers: { "content-type": "text/event-stream" } });

    const meta = await chat(3);
    expect(meta).not.toHaveProperty("summary");
    expect(meta).not.toHaveProperty("summary_covers");
  });
});
