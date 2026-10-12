import { fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { mintInstallId, sendTurnCapturingSystemPrompt, systemPromptOf } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// FR-008a. `chat.wrap_up_at_turn` defaults to 12.
describe("POST /v1/chat — {{WRAP_UP}} substitution", () => {
  it("below wrap_up_at_turn the prompt has no wrap-up sentence; at or above it, it has exactly the fixed sentence", async () => {
    const installId = await mintInstallId();
    const rawBodies: string[] = [];
    for (let n = 1; n <= 12; n++) {
      const res = await sendTurnCapturingSystemPrompt(installId, n, rawBodies);
      expect(res.status).toBe(200);
    }
    const bodies = rawBodies;

    const WRAP_UP_SENTENCE =
      "Begin steering toward a conclusion now. If they have not yet stated their approach and its complexity, ask for them; if they have, tell them they can finish. ";

    for (let i = 0; i < 11; i++) {
      // turns 1..11
      expect(systemPromptOf(bodies[i])).not.toContain(WRAP_UP_SENTENCE.trim());
    }
    // turn 12 (index 11) is at wrap_up_at_turn
    expect(systemPromptOf(bodies[11])).toContain(WRAP_UP_SENTENCE);
  });
});
