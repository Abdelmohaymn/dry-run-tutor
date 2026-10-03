import { SELF, env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { mintInstallId } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function killProblem(problemId: string): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM runtime_config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  cfg.killed_problem_ids = [problemId];
  await env.DB.prepare("UPDATE runtime_config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

describe("POST /v1/chat — pre-provider guards (T048)", () => {
  it("an empty turn returns EMPTY_TURN with zero provider calls", async () => {
    const installId = await mintInstallId();
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "  " }] }),
    });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe("EMPTY_TURN");
    // No fetchMock interceptor registered: afterEach's
    // assertNoPendingInterceptors() proves zero provider calls happened.
  });

  it("a killed problem returns PROBLEM_KILLED with zero provider calls, on the conversational path", async () => {
    await killProblem("vp-0001");
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
        messages: [{ role: "user", text: "I would check every pair" }],
      }),
    });
    expect(res.status).toBe(409);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe("PROBLEM_KILLED");
  });

  it("a killed problem also refuses a hint pull", async () => {
    await killProblem("vp-0001");
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
        messages: [{ role: "user", text: "hint please" }],
        hint_requested: true,
      }),
    });
    expect(res.status).toBe(409);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe("PROBLEM_KILLED");
  });
});
