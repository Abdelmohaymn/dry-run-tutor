// contracts/judge-output.schema.json instantiated with THIS problem's
// authored keys as enums — the substitution that makes naming an unauthored
// approach or insight structurally impossible rather than merely discouraged
// (FR-014, SC-004).
import type { Problem } from "../../../tools/problem-types";

export function buildJudgeSchema(problem: Problem): Record<string, unknown> {
  const approachKeys = [...problem.private.reference_approaches.map((a) => a.key), "none"];
  const insightKeys = problem.private.key_insights.map((i) => i.key);
  const wrongTurnKeys = problem.private.common_wrong_turns.map((w) => w.key);

  return {
    type: "object",
    additionalProperties: false,
    required: [
      "matched_approach",
      "matched_verdict",
      "insights_hit",
      "insights_missed",
      "wrong_turns_taken",
      "complexity",
      "verdict",
      "confidence",
      "feedback",
    ],
    properties: {
      matched_approach: { type: "string", enum: approachKeys },
      matched_verdict: { type: "string", enum: ["optimal", "acceptable", "suboptimal", "wrong", "none"] },
      insights_hit: { type: "array", items: { type: "string", enum: insightKeys } },
      insights_missed: { type: "array", items: { type: "string", enum: insightKeys } },
      wrong_turns_taken: { type: "array", items: { type: "string", enum: wrongTurnKeys } },
      complexity: {
        type: "object",
        additionalProperties: false,
        required: ["user_claimed_time", "user_claimed_space", "reference_time", "reference_space", "assessment"],
        properties: {
          user_claimed_time: { type: ["string", "null"] },
          user_claimed_space: { type: ["string", "null"] },
          reference_time: { type: "string" },
          reference_space: { type: "string" },
          assessment: { type: "string", enum: ["correct", "mismatched", "not_stated"] },
        },
      },
      verdict: {
        type: "string",
        enum: ["strong_pass", "pass", "borderline", "likely_tle", "incorrect", "unclear"],
      },
      confidence: { type: "number" },
      feedback: { type: "string" },
    },
  };
}
