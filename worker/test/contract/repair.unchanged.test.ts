import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
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

// US1 scenario 2, US2 scenario 3: no near-miss in the transcript, the
// provider returns it verbatim, and the response says nothing changed.
describe("POST /v1/repair — nothing to correct", () => {
  it("returns changed: false and repaired identical to the transcript, byte for byte", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const transcript = "I would iterate once and keep a running total as I go through the array";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody(transcript));

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { repaired: string; changed: boolean };
    expect(body.changed).toBe(false);
    expect(body.repaired).toBe(transcript);
  });
});
