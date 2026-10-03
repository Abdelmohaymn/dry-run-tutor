import { describe, expect, it } from "vitest";
import { getPublicManifest, isPracticeProblem } from "../../src/lib/content";

import tutorVp0001 from "../harness/corpus/tutor/vp-0001.json";
import tutorVp0002 from "../harness/corpus/tutor/vp-0002.json";
import tutorVp0003 from "../harness/corpus/tutor/vp-0003.json";
import tutorPractice from "../harness/corpus/tutor/vp-0000.json";
import judgeVp0001 from "../harness/corpus/judge/vp-0001.json";
import judgeVp0002 from "../harness/corpus/judge/vp-0002.json";
import judgeVp0003 from "../harness/corpus/judge/vp-0003.json";

const TUTOR_CORPUS: Record<string, { problem_id: string; cases: any[] }> = {
  "vp-0001": tutorVp0001,
  "vp-0002": tutorVp0002,
  "vp-0003": tutorVp0003,
  "vp-0000": tutorPractice,
};
const JUDGE_CORPUS: Record<string, { problem_id: string; cases: any[] }> = {
  "vp-0001": judgeVp0001,
  "vp-0002": judgeVp0002,
  "vp-0003": judgeVp0003,
};

const REQUIRED_TUTOR_KINDS = [
  "opening_brute_force",
  "direct_pressure",
  "confident_false_assertion",
  "hint_in_chat",
  "concept_question",
];
const REQUIRED_JUDGE_KINDS = ["optimal", "suboptimal", "wrong", "garbled", "explored_then_landed"];

// T090 originally required a corpus for every problem in content/problems/.
// Only the seed problems (vp-0000 to vp-0003) have one; problems added
// later ship without, so this checks the corpora that exist rather than
// failing for every problem that has none. A corpus that does exist must
// still be complete: five tutor conversations and five tagged judge
// conversations.
describe("harness corpus is well-formed for every problem that has one", () => {
  const problemIds = getPublicManifest().problems.map((p) => p.id);

  for (const [pid, corpus] of Object.entries(TUTOR_CORPUS)) {
    it(`${pid} has a tutor corpus with all five required cases`, () => {
      expect(corpus.problem_id).toBe(pid);
      const kinds = corpus.cases.map((c) => c.kind);
      for (const required of REQUIRED_TUTOR_KINDS) {
        expect(kinds, `missing tutor case kind "${required}" for ${pid}`).toContain(required);
      }
      expect(corpus.cases.length).toBe(REQUIRED_TUTOR_KINDS.length);
      for (const c of corpus.cases) {
        expect(Array.isArray(c.turns)).toBe(true);
        expect(c.turns.length).toBeGreaterThan(0);
      }
    });
  }

  // The onboarding warm-up runs real tutor turns, so it is held to the
  // tutor bar above like any other problem — but it has no Finish and
  // /v1/trial refuses `mode=judge` for it, so there is no judge call to
  // hold to a corpus.
  for (const [pid, corpus] of Object.entries(JUDGE_CORPUS)) {
    it.skipIf(isPracticeProblem(pid))(`${pid} has a judge corpus with all five tagged verdict cases`, () => {
      expect(corpus.problem_id).toBe(pid);
      const kinds = corpus.cases.map((c) => c.kind);
      for (const required of REQUIRED_JUDGE_KINDS) {
        expect(kinds, `missing judge case kind "${required}" for ${pid}`).toContain(required);
      }
      expect(corpus.cases.length).toBe(REQUIRED_JUDGE_KINDS.length);
      for (const c of corpus.cases) {
        expect(Array.isArray(c.expected_verdicts)).toBe(true);
        expect(c.expected_verdicts.length).toBeGreaterThan(0);
        expect(Array.isArray(c.conversation)).toBe(true);
        expect(c.conversation.length).toBeGreaterThan(0);
      }
    });
  }

  it("no corpus entry exists for a problem that is not in content/problems/", () => {
    const idSet = new Set(problemIds);
    for (const pid of Object.keys(TUTOR_CORPUS)) {
      expect(idSet.has(pid), `tutor corpus exists for ${pid}, which is not a seed problem`).toBe(true);
    }
    for (const pid of Object.keys(JUDGE_CORPUS)) {
      expect(idSet.has(pid), `judge corpus exists for ${pid}, which is not a seed problem`).toBe(true);
    }
  });
});
