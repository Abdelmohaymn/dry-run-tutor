import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  groqStreamBody,
  mintInstallId,
  setRepairConfig,
} from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function turnsFor(installId: string): Promise<number> {
  const bareInstallId = installId.split(".")[0];
  const row = await env.DB.prepare(
    "SELECT turns FROM device_day WHERE device_hash = ?1 AND problem_id = ?2",
  )
    .bind(bareInstallId, "vp-0001")
    .first<{ turns: number }>();
  return row?.turns ?? 0;
}

async function sendChatTurn(installId: string, n: number): Promise<{ status: number }> {
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
  const status = res.status;
  await res.text();
  return { status };
}

// FR-007, SC-007. THIS TEST MUST NEVER BE DELETED (tasks.md Notes).
describe("POST /v1/repair — reserves no turn, ever", () => {
  it("the device_day counter is identical before and after a successful repair call", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const before = await turnsFor(installId);

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("I would use two pointers here to scan through the whole list of values"));

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: "I would use too pointers here to scan through the whole list of values" }),
    });
    expect(res.status).toBe(200);

    const after = await turnsFor(installId);
    expect(after).toBe(before);
  });

  it("repair still answers 200 once the install is already at its turn cap — never TURN_CAP_REACHED", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    for (let n = 1; n <= 15; n++) {
      const { status } = await sendChatTurn(installId, n);
      expect(status).toBe(200);
    }
    expect(await turnsFor(installId)).toBe(15);

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("I would use two pointers here to scan through the whole list of values"));

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: "I would use too pointers here to scan through the whole list of values" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { repaired: string; changed: boolean };
    expect(body.changed).toBe(true);
    expect(await turnsFor(installId)).toBe(15);
  });
});
