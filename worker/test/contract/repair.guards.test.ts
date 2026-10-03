import { env, SELF, fetchMock } from "cloudflare:test";
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

async function repairUsageRow(installId: string): Promise<{ leak_blocked: number } | null> {
  const bareInstallId = installId.split(".")[0];
  return env.DB.prepare("SELECT * FROM usage WHERE install_id = ?1 AND endpoint = 'repair'")
    .bind(bareInstallId)
    .first<{ leak_blocked: number }>();
}

async function callRepair(installId: string, transcript: string) {
  return SELF.fetch("https://worker.test/v1/repair", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", transcript }),
  });
}

// US3 scenario 5, spec edge cases 1 and 2. The provider answers but a guard
// rejects it: the response still falls back to the raw transcript, but a
// usage row IS written — the learner's key was spent either way (FR-014).
describe("POST /v1/repair — a guard rejection still falls back to the raw transcript, and still records usage", () => {
  it("guard 3 (word overlap): the provider answers the problem instead of correcting the transcript", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const transcript = "I'd use a hash mop to store the compliment of each value";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(
        200,
        groqCompletionBody(
          "The optimal solution iterates once while maintaining a running total and a lookup structure",
        ),
      );

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    const row = await repairUsageRow(installId);
    expect(row).not.toBeNull();
  });

  it("guard 2 (ground truth): the provider returns a never_say term from the private half", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const transcript = "I would keep track of numbers I have already gone past";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("I would use a hash map to look up the complement of each value"));

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    const row = await repairUsageRow(installId);
    expect(row).not.toBeNull();
    expect(row!.leak_blocked).toBe(1);
  });

  it("guard 1 (length ratio): the provider returns text three times the raw's length", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const transcript = "I would use two pointers here to scan through the whole list of values";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody(("I would use two pointers here to scan through the whole list of values ").repeat(6)));

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    const row = await repairUsageRow(installId);
    expect(row).not.toBeNull();
  });
});
