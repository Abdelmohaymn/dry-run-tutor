import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, beforeEach, describe, expect, it, vi, type MockInstance } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, mintInstallId, setRepairConfig } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// The worker runs in this isolate, so a spy on the global fetch sees every
// outbound provider call. The sanity case below proves the spy can see one.
let outbound: MockInstance<typeof fetch>;
beforeEach(() => {
  outbound = vi.spyOn(globalThis, "fetch");
});
afterEach(() => {
  outbound.mockRestore();
});

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
// escaped) — nothing was spent.
describe("POST /v1/repair — skip levers spend nothing", () => {
  it("repair.enabled: false returns the raw transcript with no provider call", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ enabled: false });
    const transcript = "I would iterate once and keep a running total as I go";

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(outbound).not.toHaveBeenCalled();
  });

  it("a transcript below min_chars returns the raw transcript with no provider call", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ min_chars: 100 });
    const transcript = "too short";

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(outbound).not.toHaveBeenCalled();
  });

  it("a transcript above max_input_chars returns the raw transcript with no provider call", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ max_input_chars: 50 });
    const transcript = "x".repeat(60);

    const res = await callRepair(installId, transcript);

    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ repaired: transcript, changed: false });
    expect(outbound).not.toHaveBeenCalled();
  });
});

describe("POST /v1/repair — the outbound-call spy sees a real provider call", () => {
  it("an eligible transcript reaches the provider exactly once", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("I would iterate once and keep a running total as I go"));

    const res = await callRepair(installId, "I would iterate once and keep a running total as I go");

    expect(res.status).toBe(200);
    expect(outbound).toHaveBeenCalledTimes(1);
  });
});
