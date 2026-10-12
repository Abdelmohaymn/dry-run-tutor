import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { mapVerdict, type JudgeOutput } from "../../src/lib/verdict-map";
import type { Problem } from "../../../tools/problem-types";

const problem: Problem = {
  public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!,
  private: getPrivate("vp-0001")!,
};

const requiredKeys = problem.private.key_insights.filter((i) => i.required).map((i) => i.key);
const allInsightKeys = problem.private.key_insights.map((i) => i.key);
const wrongApproachKey = problem.private.reference_approaches.find((a) => a.verdict === "wrong")!.key;
const someWrongTurnKey = problem.private.common_wrong_turns[0].key;

function out(overrides: Partial<JudgeOutput>): JudgeOutput {
  return {
    matched_approach: "hashmap",
    matched_verdict: "optimal",
    insights_hit: allInsightKeys,
    insights_missed: [],
    wrong_turns_taken: [],
    verdict: "pass",
    ...overrides,
  };
}

// data-model.md §B4 — judge-spec.md §5's table, one case per row.
describe("mapVerdict() — judge-spec.md §5, first match wins", () => {
  it("optimal + all required hit + an edge case raised -> strong_pass", () => {
    const nonRequired = problem.private.key_insights.find((i) => !i.required)!.key;
    const result = mapVerdict(
      out({ matched_verdict: "optimal", insights_hit: [...requiredKeys, nonRequired] }),
      problem,
    );
    expect(result).toBe("strong_pass");
  });

  it("an approach the catalogue does not list, with every required insight reached -> pass", () => {
    // The author's reference list is the approaches they thought of, not
    // the only ones that work. This row does not exist in judge-spec.md
    // §5's table; without it the mapping fell through to "unclear" and
    // told a learner who had solved the problem their own way that the
    // conversation was too garbled to classify.
    expect(
      mapVerdict(
        out({ matched_approach: "none", matched_verdict: "none", insights_hit: allInsightKeys }),
        problem,
      ),
    ).toBe("pass");
  });

  it("an unlisted approach never reaches strong_pass — the catalogue cannot confirm it is optimal", () => {
    const nonRequired = problem.private.key_insights.find((i) => !i.required)!.key;
    expect(
      mapVerdict(
        out({
          matched_approach: "none",
          matched_verdict: "none",
          insights_hit: [...requiredKeys, nonRequired],
        }),
        problem,
      ),
    ).toBe("pass");
  });

  it("an unlisted approach missing a required insight is still borderline, not pass", () => {
    expect(
      mapVerdict(
        out({
          matched_approach: "none",
          matched_verdict: "none",
          insights_hit: requiredKeys.slice(1),
        }),
        problem,
      ),
    ).toBe("borderline");
  });

  it("optimal or acceptable + all required hit, no extra -> pass", () => {
    expect(mapVerdict(out({ matched_verdict: "optimal", insights_hit: requiredKeys }), problem)).toBe("pass");
    expect(mapVerdict(out({ matched_verdict: "acceptable", insights_hit: requiredKeys }), problem)).toBe("pass");
  });

  it("a required insight missed, but no wrong turn -> borderline", () => {
    const missingOne = requiredKeys.slice(1);
    const result = mapVerdict(out({ matched_verdict: "optimal", insights_hit: missingOne }), problem);
    expect(result).toBe("borderline");
  });

  it("matched_verdict suboptimal -> likely_tle", () => {
    expect(mapVerdict(out({ matched_verdict: "suboptimal" }), problem)).toBe("likely_tle");
  });

  it("matched_verdict wrong -> incorrect", () => {
    expect(mapVerdict(out({ matched_verdict: "wrong" }), problem)).toBe("incorrect");
  });

  it("a wrong_turns_taken entry matching a 'wrong'-verdict approach key -> incorrect", () => {
    const result = mapVerdict(
      out({ matched_verdict: "optimal", insights_hit: requiredKeys, wrong_turns_taken: [wrongApproachKey] }),
      problem,
    );
    expect(result).toBe("incorrect");
  });

  it("unclassifiable transcript (none matched, nothing hit) -> unclear", () => {
    expect(mapVerdict(out({ matched_approach: "none", matched_verdict: "none", insights_hit: [] }), problem)).toBe(
      "unclear",
    );
  });

  it("the precedence case: optimal claimed but a required insight missed -> borderline, NOT pass", () => {
    const result = mapVerdict(
      out({ matched_verdict: "optimal", insights_hit: requiredKeys.slice(1), verdict: "pass" }),
      problem,
    );
    expect(result).toBe("borderline");
  });

  it("a wrong_turns_taken entry naming an ordinary (non-approach) wrong-turn key does not by itself force incorrect", () => {
    const result = mapVerdict(
      out({ matched_verdict: "optimal", insights_hit: requiredKeys, wrong_turns_taken: [someWrongTurnKey] }),
      problem,
    );
    expect(result).not.toBe("incorrect");
  });
});

// Review F3 / F8, 2026-10-07.
describe("mapVerdict() — per-approach requires and zero-evidence rows", () => {
  it("an acceptable approach explained in full maps to pass, though the optimal approach's required insight is absent", () => {
    // vp-0001 sort_two_pointer requires only index_storage.
    expect(
      mapVerdict(out({ matched_approach: "sort_two_pointer", matched_verdict: "acceptable", insights_hit: ["index_storage"] }), problem),
    ).toBe("pass");
  });

  it("an acceptable approach missing its own requirement is still borderline", () => {
    expect(
      mapVerdict(out({ matched_approach: "sort_two_pointer", matched_verdict: "acceptable", insights_hit: ["single_pass"] }), problem),
    ).toBe("borderline");
  });

  it("an approach without requires falls back to the problem's required insights", () => {
    expect(
      mapVerdict(out({ matched_approach: "hashmap", matched_verdict: "optimal", insights_hit: ["index_storage"] }), problem),
    ).toBe("borderline");
  });

  it("a matched approach with no insight stated keeps the model's own unclear", () => {
    expect(
      mapVerdict(out({ matched_approach: "brute_force", matched_verdict: "suboptimal", insights_hit: [], verdict: "unclear" }), problem),
    ).toBe("unclear");
  });

  it("no approach matched, no insight, and the model says incorrect -> incorrect, not unclear", () => {
    expect(
      mapVerdict(out({ matched_approach: "none", matched_verdict: "none", insights_hit: [], verdict: "incorrect" }), problem),
    ).toBe("incorrect");
  });

  it("no approach matched and the model says incorrect -> incorrect even with an insight hit", () => {
    // postprocessJudge no longer lets an unlisted approach carry "wrong", so
    // the model's own verdict is the only signal left (judge-evidence D10).
    expect(
      mapVerdict(out({ matched_approach: "none", matched_verdict: "none", insights_hit: ["index_storage"], verdict: "incorrect" }), problem),
    ).toBe("incorrect");
  });
});

// 2026-10-12, PLAN_07 D10: a nudge counts toward a pass, never toward top marks.
describe("mapVerdict() — insights reached with the tutor's help", () => {
  const nonRequired = problem.private.key_insights.find((i) => !i.required)!.key;
  const hit = [...requiredKeys, nonRequired];

  it("optimal, every required insight own, an edge case -> strong_pass", () => {
    expect(mapVerdict(out({ matched_verdict: "optimal", insights_hit: hit, insights_assisted: [] }), problem)).toBe("strong_pass");
  });

  it("the same with one required insight assisted -> pass, not strong_pass", () => {
    expect(
      mapVerdict(out({ matched_verdict: "optimal", insights_hit: hit, insights_assisted: [requiredKeys[0]] }), problem),
    ).toBe("pass");
  });

  it("an assisted edge-case insight does not stop strong_pass: only the required ones matter", () => {
    expect(
      mapVerdict(out({ matched_verdict: "optimal", insights_hit: hit, insights_assisted: [nonRequired] }), problem),
    ).toBe("strong_pass");
  });

  it("an assisted required insight still counts toward pass", () => {
    expect(
      mapVerdict(out({ matched_verdict: "optimal", insights_hit: requiredKeys, insights_assisted: requiredKeys }), problem),
    ).toBe("pass");
  });
});
