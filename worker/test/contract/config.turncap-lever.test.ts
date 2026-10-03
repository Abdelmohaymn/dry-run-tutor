import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// US6 scenario 1, SC-012. Kept in its own file — see
// chat.wrapup-lever.test.ts's comment on mutating runtime_config alongside
// real SSE-streaming responses in the same file.
describe("GET /v1/config — chat.turn_cap lever change with no redeploy", () => {
  it("changing chat.turn_cap in D1 changes the served value and the enforced cap", async () => {
    const row = await env.DB.prepare("SELECT payload FROM runtime_config WHERE id = 1").first<{
      payload: string;
    }>();
    const cfg = JSON.parse(row!.payload);
    cfg.chat.turn_cap = 2;
    await env.DB.prepare("UPDATE runtime_config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();

    const served = (await (await SELF.fetch("https://worker.test/v1/config")).json()) as any;
    expect(served.chat.turn_cap).toBe(2);

    const installId = await mintInstallId();
    for (let n = 1; n <= 2; n++) {
      fetchMock
        .get(GROQ_ORIGIN)
        .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
        .reply(200, groqStreamBody(`reply ${n}`), { headers: { "content-type": "text/event-stream" } });
      const res = await SELF.fetch("https://worker.test/v1/chat", {
        method: "POST",
        headers: {
          "X-Install-Id": installId,
          "X-User-Key": "gsk_test_learner_key",
          "content-type": "application/json",
        },
        body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: `turn ${n}` }] }),
      });
      await res.text();
    }

    const third = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "turn 3" }] }),
    });
    expect(third.status).toBe(409);
    const body = (await third.json()) as any;
    expect(body.error.code).toBe("TURN_CAP_REACHED");
  });
});
