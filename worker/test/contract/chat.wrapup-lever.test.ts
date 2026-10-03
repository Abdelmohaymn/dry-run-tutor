import { env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { mintInstallId, sendTurnCapturingSystemPrompt, systemPromptOf } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// FR-008a, SC-012. Kept in its own file: mutating runtime_config directly
// via D1 alongside real SSE-streaming responses in the same file has been
// observed to break vitest-pool-workers' isolated-storage bookkeeping.
describe("POST /v1/chat — {{WRAP_UP}} lever change with no redeploy", () => {
  it("lowering chat.wrap_up_at_turn in D1 moves the boundary", async () => {
    const row = await env.DB.prepare("SELECT payload FROM runtime_config WHERE id = 1").first<{
      payload: string;
    }>();
    const cfg = JSON.parse(row!.payload);
    cfg.chat.wrap_up_at_turn = 2;
    await env.DB.prepare("UPDATE runtime_config SET payload = ? WHERE id = 1")
      .bind(JSON.stringify(cfg))
      .run();

    const installId = await mintInstallId();
    const rawBodies: string[] = [];
    await sendTurnCapturingSystemPrompt(installId, 1, rawBodies);
    await sendTurnCapturingSystemPrompt(installId, 2, rawBodies);
    const bodies = rawBodies;

    expect(systemPromptOf(bodies[0])).not.toContain("Begin steering toward a conclusion now");
    expect(systemPromptOf(bodies[1])).toContain("Begin steering toward a conclusion now");
  });
});
