import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function post(path: string, installId: string, body: unknown) {
  return SELF.fetch(`https://worker.test${path}`, {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify(body),
  });
}

const keyCheck = { problem_id: "vp-0001", messages: [{ role: "user", text: "checking this key" }], key_check: true };

// Saving a key used to spend a real tutor turn on today's problem (found on
// device 2026-09-25: the learner started their first keyed turn at 4).
describe("POST /v1/chat key_check — validates a key without spending a turn", () => {
  it("a working key gets meta + done, no token frames, and the turn counter does not move", async () => {
    const installId = await mintInstallId();
    let sentBody = "";
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        sentBody = opts.body as string;
        return groqStreamBody("OK");
      }, { headers: { "content-type": "text/event-stream" } });

    const frames = await readChatSSE(await post("/v1/chat", installId, keyCheck));
    expect(frames.map((f) => f.event)).toEqual(["meta", "done"]);
    expect((frames[0].data as { turn_index: number }).turn_index).toBe(0);
    expect(sentBody).not.toContain("coding tutor"); // not the tutor prompt, no ground truth

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What are you searching for?"), { headers: { "content-type": "text/event-stream" } });
    const next = await readChatSSE(
      await post("/v1/chat", installId, { problem_id: "vp-0001", messages: [{ role: "user", text: "first real turn" }] }),
    );
    expect((next.find((f) => f.event === "meta")!.data as { turn_index: number }).turn_index).toBe(1);
  });

  it("a rejected key surfaces as an INVALID_KEY error frame", async () => {
    const installId = await mintInstallId();
    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(401, "unauthorized");

    const frames = await readChatSSE(await post("/v1/chat", installId, keyCheck));
    const error = frames.find((f) => f.event === "error")!.data as { error: { code: string } };
    expect(error.error.code).toBe("INVALID_KEY");
  });

  it("the trial path does not accept key_check", async () => {
    const installId = await mintInstallId();
    const res = await post("/v1/trial", installId, { ...keyCheck, mode: "chat" });
    expect(res.status).toBe(400);
  });
});
