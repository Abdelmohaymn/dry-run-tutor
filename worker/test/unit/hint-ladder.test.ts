import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { LADDER_EXHAUSTED, flatLadder, nextHint } from "../../src/lib/hint-ladder";
import { normalise, wholeWordMatch } from "../../src/lib/text-match";
import type { Problem } from "../../../tools/problem-types";

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({ public: pub, private: getPrivate(pub.id)! }));
}

describe("flatLadder()", () => {
  it("is 3 x len(key_insights) rungs, in authored order, for every seed problem", () => {
    for (const problem of allSeedProblems()) {
      const ladder = flatLadder(problem);
      expect(ladder).toHaveLength(3 * problem.private.key_insights.length);

      let cursor = 0;
      for (const insight of problem.private.key_insights) {
        for (const rung of insight.hints) {
          expect(ladder[cursor]).toEqual({ insightKey: insight.key, text: rung });
          cursor += 1;
        }
      }
    }
  });

  it("no rung contains a never_say term of its own insight", () => {
    for (const problem of allSeedProblems()) {
      for (const insight of problem.private.key_insights) {
        for (const rung of insight.hints) {
          const normalisedRung = normalise(rung);
          for (const term of insight.never_say) {
            expect(
              wholeWordMatch(normalisedRung, normalise(term)),
              `rung "${rung}" of insight "${insight.key}" leaks its own never_say term "${term}"`,
            ).toBe(false);
          }
        }
      }
    }
  });
});

describe("nextHint()", () => {
  it("rung n is byte-identical to the authored string, in authored order", () => {
    const problem = allSeedProblems()[0];
    const ladder = flatLadder(problem);
    for (let i = 1; i <= ladder.length; i++) {
      expect(nextHint(problem, i)).toEqual(ladder[i - 1]);
    }
  });

  it("one past the end returns LADDER_EXHAUSTED and never the editorial", () => {
    const problem = allSeedProblems()[0];
    const ladder = flatLadder(problem);
    const result = nextHint(problem, ladder.length + 1);
    expect(result).toBe(LADDER_EXHAUSTED);
    expect(JSON.stringify(result)).not.toContain(problem.private.editorial.slice(0, 20));
  });
});
