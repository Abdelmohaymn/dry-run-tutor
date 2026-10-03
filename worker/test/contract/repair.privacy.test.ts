import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  mintInstallId,
  setRepairConfig,
} from "./helpers";
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

// FR-009, Principle VI. THIS TEST MUST NEVER BE DELETED (tasks.md Notes).
describe("POST /v1/repair — no private field ever reaches the wire", () => {
  it("the outbound request contains only glossary_terms and the transcript, and no string from the private half", async () => {
    const problem = vp0001();
    const installId = await mintInstallId();
    await setRepairConfig();
    const transcript = "I'd use a hash mop to store the compliment of each value";
    let capturedBody = "";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        capturedBody = opts.body as string;
        return groqCompletionBody("I'd use a hash map to store the complement of each value");
      });

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript }),
    });
    await res.text();

    expect(capturedBody).toContain(transcript);
    for (const term of problem.public.glossary_terms) {
      expect(capturedBody).toContain(term);
    }

    expect(capturedBody).not.toContain(problem.private.editorial);
    for (const approach of problem.private.reference_approaches) {
      expect(capturedBody).not.toContain(approach.name);
      for (const line of approach.sketch) {
        expect(capturedBody).not.toContain(line);
      }
    }
    // Deliberately NOT asserted here: individual `never_say` terms. They are
    // guard 2's blocked-word list, built for the OUTPUT check (§Guards) —
    // several of them (e.g. "complement") are legitimately also glossary
    // terms sent as input, so their presence in the request is correct, not
    // a leak. `insight.text` is the private prose; that must never appear.
    for (const insight of problem.private.key_insights) {
      expect(capturedBody).not.toContain(insight.text);
    }
    for (const wrongTurn of problem.private.common_wrong_turns) {
      expect(capturedBody).not.toContain(wrongTurn.why_it_fails);
    }
  });
});
