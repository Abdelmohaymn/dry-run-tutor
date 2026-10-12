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
      const insightEnum: string[] = schema.properties.insights_hit.items.properties.key.enum;
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

  // docs/judge-evidence-issues.md D1/D2: strict decoding emits fields in
  // schema order, so the evidence has to come before the label it supports.
  it("asks for the learner's words before the approach label (approach_quote first)", () => {
    for (const problem of allSeedProblems()) {
      const schema = buildJudgeSchema(problem) as any;
      expect(schema.properties.approach_quote).toEqual({ type: "string" });
      expect(schema.required).toContain("approach_quote");
      for (const keys of [Object.keys(schema.properties), schema.required as string[]]) {
        expect(keys.indexOf("approach_quote")).toBeGreaterThanOrEqual(0);
        expect(keys.indexOf("approach_quote")).toBeLessThan(keys.indexOf("matched_approach"));
      }
    }
  });

  it("makes every insights_hit entry a { quote, key } object, quote first, key still the authored enum", () => {
    for (const problem of allSeedProblems()) {
      const schema = buildJudgeSchema(problem) as any;
      const items = schema.properties.insights_hit.items;
      expect(schema.properties.insights_hit.type).toBe("array");
      expect(items.type).toBe("object");
      expect(items.additionalProperties).toBe(false);
      expect(items.required).toEqual(["quote", "key"]);
      expect(Object.keys(items.properties)).toEqual(["quote", "key"]);
      expect(items.properties.quote).toEqual({ type: "string" });
      expect(items.properties.key.enum).toEqual(problem.private.key_insights.map((i) => i.key));
    }
  });

  it("leaves insights_missed a plain list of authored insight keys", () => {
    for (const problem of allSeedProblems()) {
      const schema = buildJudgeSchema(problem) as any;
      expect(schema.properties.insights_missed).toEqual({
        type: "array",
        items: { type: "string", enum: problem.private.key_insights.map((i) => i.key) },
      });
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
