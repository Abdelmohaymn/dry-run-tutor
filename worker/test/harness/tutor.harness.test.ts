// Live-provider regression net for the tutor prompt (quickstart.md §7).
// GROQ_API_KEY required — see worker/test/harness/lib/live-client.ts and
// worker/package.json's test:harness script (T088).
import { env } from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { learnerNamedTerms } from "../../src/lib/ground-truth";
import { flatLadder } from "../../src/lib/hint-ladder";
import { detectLeak } from "./lib/leak-detect";
import { applyProviderOverride, requireGroqApiKey, runConversation } from "./lib/live-client";
import type { Problem } from "../../../tools/problem-types";

import tutorVp0001 from "./corpus/tutor/vp-0001.json";
import tutorVp0002 from "./corpus/tutor/vp-0002.json";
import tutorVp0003 from "./corpus/tutor/vp-0003.json";

const CORPUS: Record<string, { problem_id: string; cases: any[] }> = {
  "vp-0001": tutorVp0001,
  "vp-0002": tutorVp0002,
  "vp-0003": tutorVp0003,
};

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({ public: pub, private: getPrivate(pub.id)! }));
}

let apiKey: string;
beforeAll(async () => {
  apiKey = requireGroqApiKey();
  await applyProviderOverride(env.DB);
});

describe("tutor harness — live regression net", () => {
  for (const problem of allSeedProblems()) {
    const pid = problem.public.id;
    const corpus = CORPUS[pid];
    if (!corpus) continue;

    describe(pid, () => {
      it("opening_brute_force: zero solution reveals on turn 1 (SC-001)", async () => {
        const c = corpus.cases.find((x) => x.kind === "opening_brute_force")!;
        const [result] = await runConversation(pid, c.turns, apiKey);
        expect(result.replyText.length, "empty reply — likely a rate-limited call, not a real generation").toBeGreaterThan(0);
        expect(result.sessionEnded).not.toBe("solution");
        const leak = detectLeak(problem, result.replyText);
        expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
      });

      it("direct_pressure: the solution is withheld on the first ask, 100% (SC-002)", async () => {
        const c = corpus.cases.find((x) => x.kind === "direct_pressure")!;
        const [result] = await runConversation(pid, c.turns, apiKey);
        expect(result.replyText.length, "empty reply — likely a rate-limited call, not a real generation").toBeGreaterThan(0);
        expect(result.sessionEnded).not.toBe("solution");
        const leak = detectLeak(problem, result.replyText);
        expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
      });

      it("confident_false_assertion: a counter-question or failing case, not a flat correction (SC-003)", async () => {
        const c = corpus.cases.find((x) => x.kind === "confident_false_assertion")!;
        const [result] = await runConversation(pid, c.turns, apiKey);
        expect(result.replyText.length, "empty reply — likely a rate-limited call, not a real generation").toBeGreaterThan(0);
        // A counter-question reads as a question; a failing case names a
        // concrete input. Either is acceptable — a bare "that's wrong" is not.
        expect(result.replyText).toMatch(/\?/);
        const leak = detectLeak(problem, result.replyText);
        expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
      });

      it("hint_in_chat: says a hint can be asked for, never invents a rung", async () => {
        const c = corpus.cases.find((x) => x.kind === "hint_in_chat")!;
        const [result] = await runConversation(pid, c.turns, apiKey);
        expect(result.replyText.length, "empty reply — likely a rate-limited call, not a real generation").toBeGreaterThan(0);
        const ladder = flatLadder(problem);
        for (const rung of ladder) {
          expect(result.replyText).not.toContain(rung.text);
        }
        const leak = detectLeak(problem, result.replyText);
        expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
      });

      it("concept_question: never leaks, and typically answers in full (FR-004, FR-004a)", async () => {
        const c = corpus.cases.find((x) => x.kind === "concept_question")!;
        const [result] = await runConversation(pid, c.turns, apiKey);
        expect(result.replyText.length, "empty reply — likely a rate-limited call, not a real generation").toBeGreaterThan(0);
        // The hard safety bar: whatever the caller actually sees never
        // leaks — true whether or not the runtime filter had to step in.
        // A rare over-block on live model output (leak_blocked: true, a
        // DIFFERENT never_say term than the one the learner unblocked)
        // is the filter working, not a violation — it swaps in the fixed
        // fallback line, which by construction contains none of the
        // private vocabulary. FR-004a's ideal ("answered in full") is
        // the common case, not asserted as a hard 100% here because a
        // single live generation is not the statistic; SC-001's leak
        // rate is what test:harness's repeated CI runs actually pin.
        const named = learnerNamedTerms(problem, [{ role: "user", text: c.turns[0] }]);
        const leak = detectLeak(problem, result.replyText, named);
        expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
      });
    });
  }
});
