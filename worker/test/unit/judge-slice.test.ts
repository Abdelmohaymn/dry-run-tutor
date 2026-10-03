import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { judgeSlice } from "../../src/lib/ground-truth";
import type { Problem } from "../../../tools/problem-types";

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({
    public: pub,
    private: getPrivate(pub.id)!,
  }));
}

// data-model.md §B6a.
describe("judgeSlice() — the assessment's ground-truth slice", () => {
  it("carries no hints array and no editorial for any seed problem", () => {
    for (const problem of allSeedProblems()) {
      const slice = judgeSlice(problem);
      expect(JSON.stringify(slice)).not.toContain('"hints"');
      expect(JSON.stringify(slice)).not.toContain(problem.private.editorial.slice(0, 40));
      expect((slice as unknown as Record<string, unknown>).editorial).toBeUndefined();
    }
  });

  it("carries why_it_fails and insight text — the judge classifies against both", () => {
    for (const problem of allSeedProblems()) {
      const slice = judgeSlice(problem);
      expect(slice.wrongTurns.length).toBe(problem.private.common_wrong_turns.length);
      for (const w of slice.wrongTurns) {
        expect(typeof w.why_it_fails).toBe("string");
        expect(w.why_it_fails.length).toBeGreaterThan(0);
      }
      expect(slice.insights.length).toBe(problem.private.key_insights.length);
      for (const i of slice.insights) {
        expect(typeof i.text).toBe("string");
        expect(i.text.length).toBeGreaterThan(0);
      }
    }
  });
});
