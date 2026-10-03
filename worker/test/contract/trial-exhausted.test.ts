import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { mintInstallId } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// SC-010b: with every pool member over daily_token_budget, a NEW trial
// returns 503 TRIAL_UNAVAILABLE, and NEVER UNCLEAR_RETRY or
// QUOTA_EXHAUSTED — QUOTA_EXHAUSTED's copy tells the learner THEIR OWN
// allowance is spent, which on this path is false.
describe("POST /v1/trial — graceful exhaustion", () => {
  it("with the only pool member over its daily_token_budget, a new trial returns 503 TRIAL_UNAVAILABLE", async () => {
    const installId = await mintInstallId();
    const date = new Date().toISOString().slice(0, 10);

    // Push "groq" (the sole seeded, enabled member) over its
    // daily_token_budget (180000) so selectMember("chat", ...) returns null.
    await env.DB.prepare(
      "INSERT INTO trial_budget (date, provider_id, tokens_spent) VALUES (?1, 'groq', 999999)",
    )
      .bind(date)
      .run();

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": installId, "content-type": "application/json" },
      body: JSON.stringify({
        mode: "chat",
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "hello" }],
      }),
    });

    expect(res.status).toBe(503);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("TRIAL_UNAVAILABLE");
    expect(body.error.code).not.toBe("QUOTA_EXHAUSTED");
    expect(body.error.code).not.toBe("UNCLEAR_RETRY");
    expect(body.error.retryable).toBe(false);
  });
});
