import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { mintInstallId, setRepairConfig } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function usageCountFor(installId: string): Promise<number> {
  const bareInstallId = installId.split(".")[0];
  const row = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM usage WHERE install_id = ?1 AND endpoint = 'repair'",
  )
    .bind(bareInstallId)
    .first<{ n: number }>();
  return row!.n;
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

// US3 scenario 3, FR-010, FR-011. In each case: no outbound provider call
// (no interceptor is registered, and fetchMock.disableNetConnect() plus
// assertNoPendingInterceptors() in afterEach would fail the test if one
// escaped) and no usage row — nothing was spent.
describe("POST /v1/repair — skip levers spend nothing", () => {
  it("repair.enabled: false returns the raw transcript with no provider call and no usage row", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ enabled: false });
    const transcript = "I would iterate once and keep a running total as I go";

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(await usageCountFor(installId)).toBe(0);
  });

  it("a transcript below min_chars returns the raw transcript with no provider call and no usage row", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ min_chars: 100 });
    const transcript = "too short";

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(await usageCountFor(installId)).toBe(0);
  });

  it("a transcript above max_input_chars returns the raw transcript with no provider call and no usage row", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ max_input_chars: 50 });
    const transcript = "x".repeat(60);

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(await usageCountFor(installId)).toBe(0);
  });
});
