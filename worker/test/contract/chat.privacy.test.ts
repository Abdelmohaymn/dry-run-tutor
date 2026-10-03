import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId } from "./helpers";
import type { Problem } from "../../../tools/problem-types";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function vp0001(): Problem {
  const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
  return { public: pub, private: getPrivate("vp-0001")! };
}

// FR-002, FR-007, FR-003d, SC-002b.
describe("POST /v1/chat — no private field ever reaches the wire, at any turn", () => {
  it("no response body contains editorial, why_it_fails, an authored insight.text, or system-prompt text", async () => {
    const problem = vp0001();
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What are you actually searching for at each step?"), {
        headers: { "content-type": "text/event-stream" },
      });

    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "I could check every pair with two nested loops" }],
      }),
    });
    const bodyText = await res.text();

    expect(bodyText).not.toContain(problem.private.editorial);
    for (const wrongTurn of problem.private.common_wrong_turns) {
      expect(bodyText).not.toContain(wrongTurn.why_it_fails);
    }
    for (const insight of problem.private.key_insights) {
      expect(bodyText).not.toContain(insight.text);
    }
    expect(bodyText).not.toContain("You are a coding tutor talking with a developer");
    expect(bodyText).not.toContain("GROUND TRUTH FOR THIS PROBLEM");
  });

  it("no prompt sent upstream on a conversational turn contains a hint rung or an insight text, at every turn index 1..15", async () => {
    const problem = vp0001();
    const installId = await mintInstallId();
    const capturedSystemPrompts: string[] = [];

    // Each request sends only its single new message (not a replayed
    // history), so messages.length never exceeds cfg.trim.verbatim_turns
    // and condense() never fires — this test is about privacy across turn
    // indices, not about condensation (covered separately).
    for (let n = 1; n <= 15; n++) {
      fetchMock
        .get(GROQ_ORIGIN)
        .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
        .reply(
          200,
          (opts) => {
            const parsed = JSON.parse(opts.body as string);
            capturedSystemPrompts.push(parsed.messages[0].content);
            return groqStreamBody(`reply ${n}`);
          },
          { headers: { "content-type": "text/event-stream" } },
        );
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

    expect(capturedSystemPrompts).toHaveLength(15);
    for (const prompt of capturedSystemPrompts) {
      for (const insight of problem.private.key_insights) {
        expect(prompt).not.toContain(insight.text);
        for (const hint of insight.hints) {
          expect(prompt).not.toContain(hint);
        }
      }
      expect(prompt).not.toContain(problem.private.editorial);
    }
  });
});
