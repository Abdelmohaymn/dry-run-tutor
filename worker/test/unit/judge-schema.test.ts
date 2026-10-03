import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { buildJudgeSchema } from "../../src/lib/judge-schema";
import type { Problem } from "../../../tools/problem-types";

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({
    public: pub,
    private: getPrivate(pub.id)!,
  }));
}

// FR-014, SC-004: naming an unauthored key must be structurally impossible.
describe("buildJudgeSchema()", () => {
  it("admits only this problem's authored approach and insight keys, plus 'none' for approach", () => {
    for (const problem of allSeedProblems()) {
      const schema = buildJudgeSchema(problem) as any;
      const approachEnum: string[] = schema.properties.matched_approach.enum;
      const insightEnum: string[] = schema.properties.insights_hit.items.enum;
      const wrongTurnEnum: string[] = schema.properties.wrong_turns_taken.items.enum;

      expect(approachEnum).toEqual(
        expect.arrayContaining(problem.private.reference_approaches.map((a) => a.key)),
      );
      expect(approachEnum).toContain("none");
      expect(approachEnum.length).toBe(problem.private.reference_approaches.length + 1);

      expect(insightEnum.sort()).toEqual(problem.private.key_insights.map((i) => i.key).sort());
      expect(wrongTurnEnum.sort()).toEqual(problem.private.common_wrong_turns.map((w) => w.key).sort());

      // An unauthored key is structurally rejected, not merely discouraged.
      expect(approachEnum).not.toContain("an_unauthored_approach_key");
      expect(insightEnum).not.toContain("an_unauthored_insight_key");
    }
  });

  it("marks the whole schema additionalProperties: false, strict decoding", () => {
    for (const problem of allSeedProblems()) {
      const schema = buildJudgeSchema(problem) as any;
      expect(schema.additionalProperties).toBe(false);
      expect(schema.properties.complexity.additionalProperties).toBe(false);
    }
  });
});
