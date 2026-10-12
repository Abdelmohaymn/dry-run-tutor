// Live-provider regression net for the tutor prompt (quickstart.md §7).
// GROQ_API_KEY required — see worker/test/harness/lib/live-client.ts and
// worker/package.json's test:harness script (T088).
import { env } from "cloudflare:test";
import { beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { learnerNamedTerms } from "../../src/lib/ground-truth";
import { flatLadder } from "../../src/lib/hint-ladder";
import { detectLeak } from "./lib/leak-detect";
import { applyProviderOverride, mintInstallId, requireGroqApiKey, runConversation, sendChatTurn } from "./lib/live-client";
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

      // Review regressions (specs/review-tutor-judge-findings.md §5): one
      // reply to a fixed history. The regex checks are a deterministic first
      // gate for re-asking and handing the approach over; each case's `why`
      // says what a failure looks like.
      for (const c of corpus.cases.filter((x) => x.kind === "regression")) {
        it(`regression ${c.id}: ${c.why}`, async () => {
          const named = learnerNamedTerms(problem, c.history);
          let result = await sendChatTurn(await mintInstallId(), pid, c.history, apiKey);
          if (result.replyText.length === 0) {
            await new Promise((r) => setTimeout(r, Math.min(result.errorRetryAfterMs ?? 4000, 45_000)));
            result = await sendChatTurn(await mintInstallId(), pid, c.history, apiKey);
          }
          const reply = result.replyText;
          expect(reply.length, "empty reply").toBeGreaterThan(0);
          // The learner stated the idea; the canned fallback is not a reply to it.
          // Only proves the same-turn unblock when the target has
          // finish_offer.enabled: true (PLAN_04).
          if (c.must_not_leak_block) {
            expect(result.leakBlocked, "fallback sent: filter blocked the draft and rewrite").toBe(false);
          }
          const leak = detectLeak(problem, reply, named);
          expect(leak.leaked, JSON.stringify(leak.reasons)).toBe(false);
          for (const term of c.must_not_contain ?? []) expect(reply.toLowerCase()).not.toContain(term);
          if (c.must_not_match) expect(reply).not.toMatch(new RegExp(c.must_not_match, "i"));
          if (c.must_match) expect(reply).toMatch(new RegExp(c.must_match, "i"));
          // The learner asked something: the reply opens by answering it, not by asking back.
          if (c.first_sentence_answers) {
            const first = reply.trim().split(/(?<=[.?!؟])\s+/)[0];
            expect(first, "first sentence is a question, not an answer").not.toMatch(/[?؟]$/);
          }
          if (c.min_sentences) expect(reply.split(/[.?!؟]+\s/).filter((x: string) => x.trim()).length).toBeGreaterThanOrEqual(c.min_sentences);
        });
      }

      for (const c of corpus.cases.filter((x) => x.kind === "second_solution_request")) {
        it(`${c.id}: the second ask releases the full solution (FR-006, review F5)`, async () => {
          const installId = await mintInstallId();
          const first = await sendChatTurn(installId, pid, [{ role: "user", text: c.turns[0] }], apiKey, 1);
          expect(first.sessionEnded).not.toBe("solution");
          const second = await sendChatTurn(
            installId,
            pid,
            [
              { role: "user", text: c.turns[0] },
              { role: "tutor", text: first.replyText },
              { role: "user", text: c.turns[1] },
            ],
            apiKey,
            2,
          );
          expect(second.sessionEnded).toBe("solution");
          // A released solution is long; a withheld one is a two-line nudge.
          expect(second.replyText.length, second.replyText).toBeGreaterThan(300);
        });
      }
    });
  }
});
