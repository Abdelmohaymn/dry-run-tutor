// Live-provider regression net for the judge prompt (quickstart.md §7).
// GROQ_API_KEY required — see worker/test/harness/lib/live-client.ts.
import { env } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { applyProviderOverride, requestAssessment, requireGroqApiKey } from "./lib/live-client";
import type { Problem } from "../../../tools/problem-types";

import judgeVp0000 from "./corpus/judge/vp-0000.json";
import judgeVp0001 from "./corpus/judge/vp-0001.json";
import judgeVp0002 from "./corpus/judge/vp-0002.json";
import judgeVp0003 from "./corpus/judge/vp-0003.json";

const CORPUS: Record<string, { problem_id: string; cases: any[] }> = {
  "vp-0000": judgeVp0000,
  "vp-0001": judgeVp0001,
  "vp-0002": judgeVp0002,
  "vp-0003": judgeVp0003,
};

// contracts/judge-system-prompt.md §Server-side post-processing step 4 —
// the two hedge-check patterns, verbatim. A harness pass on a hedged reply
// like "on the right track" must NOT be flagged; only an actual assertion
// of correctness/incorrectness should be.
const COPULA_ADJACENT =
  /\b(is|isn'?t|was|wasn'?t|are|aren'?t|that'?s|this is|it'?s|you'?re|we'?re|were|be|been|being)\s+(not\s+|quite\s+|entirely\s+|really\s+|totally\s+){0,2}(correct|incorrect|wrong|right|perfect)\b/;
const STANDALONE_SENTENCE = /(^|[.!?]\s+)(correct|incorrect|wrong|right|perfect)\s*[.!?]/;

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({ public: pub, private: getPrivate(pub.id)! }));
}

let apiKey: string;
beforeAll(async () => {
  apiKey = requireGroqApiKey();
  await applyProviderOverride(env.DB);
});

// Spacing between judge calls — a free-tier key rate-limits fast under a
// rapid-fire suite of ~6,200-token assessment calls back to back.
afterEach(async () => {
  await new Promise((r) => setTimeout(r, 1000));
});

describe("judge harness — live regression net (SC-004, SC-005)", () => {
  const landed: { problem: string; case: string; pass: boolean }[] = [];

  for (const problem of allSeedProblems()) {
    const pid = problem.public.id;
    const corpus = CORPUS[pid];
    if (!corpus) continue;

    const approachKeys = new Set(problem.private.reference_approaches.map((a) => a.key).concat("none"));
    const insightKeys = new Set(problem.private.key_insights.map((i) => i.key));

    describe(pid, () => {
      for (const c of corpus.cases) {
        it(`${c.kind}: expected verdict is one of [${c.expected_verdicts.join(", ")}]`, async () => {
          let assessment = await requestAssessment(pid, c.conversation, apiKey);
          if (assessment.error) {
            // A free-tier key rate-limits under a rapid-fire suite; retry
            // once past the server's own retry_after_ms rather than let a
            // transient RATE_LIMITED register as a false verdict mismatch.
            await new Promise((r) => setTimeout(r, (assessment.error as any)?.retry_after_ms ?? 5000));
            assessment = await requestAssessment(pid, c.conversation, apiKey);
          }
          expect(assessment.error, `judge call failed: ${JSON.stringify(assessment.error)}`).toBeUndefined();

          const ok = c.expected_verdicts.includes(assessment.verdict);
          landed.push({ problem: pid, case: c.kind, pass: ok });

          // SC-004: no unauthored approach or insight is ever named.
          expect(approachKeys.has(assessment.matched_approach as string)).toBe(true);
          for (const key of (assessment.insights_hit as string[]) ?? []) {
            expect(insightKeys.has(key)).toBe(true);
          }
          for (const key of (assessment.insights_missed as string[]) ?? []) {
            expect(insightKeys.has(key)).toBe(true);
          }

          // Review F2: a hollow assessment (feedback "" or "..") is what
          // structured calls with Nemotron's thinking on produced 12% of the
          // time. Set HARNESS_STRUCTURED_EXTRA_BODY to match production.
          expect((assessment.feedback as string).replace(/[.\s]/g, "").length, "hollow feedback").toBeGreaterThan(0);
          if (c.expected_verdicts.includes("pass")) {
            expect((assessment.insights_hit as string[]).length, "pass expected but no insight credited").toBeGreaterThan(0);
          }

          // FR-021b, Constitution IV: no unhedged verdict word in feedback.
          const lowered = (assessment.feedback as string).toLowerCase();
          expect(COPULA_ADJACENT.test(lowered)).toBe(false);
          expect(STANDALONE_SENTENCE.test(lowered)).toBe(false);

          expect(ok, `expected one of [${c.expected_verdicts.join(", ")}], got "${assessment.verdict}"`).toBe(true);
        });
      }
    });
  }
});
