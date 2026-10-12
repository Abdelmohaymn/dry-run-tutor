import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { isSelfContradictory, postprocessJudge } from "../../src/lib/judge-postprocess";
import { AppError } from "../../src/lib/errors";
import type { Problem } from "../../../tools/problem-types";

const problem: Problem = {
  public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!,
  private: getPrivate("vp-0001")!,
};

const allInsightKeys = problem.private.key_insights.map((i) => i.key);
const requiredKeys = problem.private.key_insights.filter((i) => i.required).map((i) => i.key);

const QUOTE = "I would keep a map from each value to its index";

/** Raw judge `insights_hit` entries; plain keys in a test are given the same quote. */
const quoted = (hits: unknown) =>
  (hits as (string | { quote: string; key: string })[]).map((h) => (typeof h === "string" ? { quote: QUOTE, key: h } : h));

function rawOutput(overrides: Record<string, unknown> = {}) {
  const raw = {
    approach_quote: QUOTE,
    matched_approach: "hashmap",
    matched_verdict: "optimal",
    insights_hit: requiredKeys,
    insights_missed: allInsightKeys.filter((k) => !requiredKeys.includes(k)),
    wrong_turns_taken: [],
    complexity: {
      user_claimed_time: null,
      user_claimed_space: null,
      reference_time: "O(n)",
      reference_space: "O(n)",
      assessment: "not_stated",
    },
    verdict: "pass",
    confidence: 0.9,
    feedback: "You landed on the hash map approach, which handles this well.",
    ...overrides,
  };
  return { ...raw, insights_hit: quoted(raw.insights_hit) };
}

describe("postprocessJudge() — contracts/judge-system-prompt.md §Server-side post-processing", () => {
  it("step 1: malformed/non-object input raises UNCLEAR_RETRY", () => {
    expect(() => postprocessJudge({ not: "the right shape" }, problem)).toThrow(AppError);
    expect(() => postprocessJudge(null, problem)).toThrow(AppError);
  });

  it("step 2: insights_hit ∪ insights_missed equals every authored key, and the two are disjoint", () => {
    const { assessment } = postprocessJudge(
      rawOutput({ insights_hit: [allInsightKeys[0]], insights_missed: [] }),
      problem,
    );
    const union = new Set([...assessment.insights_hit, ...assessment.insights_missed]);
    expect([...union].sort()).toEqual([...allInsightKeys].sort());
    const intersection = assessment.insights_hit.filter((k) => assessment.insights_missed.includes(k));
    expect(intersection).toEqual([]);
  });

  it("step 2: a named reference approach takes its authored verdict, whatever the model labelled it", () => {
    const result = postprocessJudge(rawOutput({ matched_verdict: "suboptimal", verdict: "likely_tle" }), problem);
    expect(result.assessment.matched_verdict).toBe("optimal");
    expect(result.assessment.verdict).not.toBe("likely_tle");
  });

  it("step 2: matched_approach 'none' carries no tier, whatever the model's matched_verdict says", () => {
    // 2026-10-11: the model answered none + acceptable and the app showed
    // "matched a solid, accepted approach" next to "Approach: None".
    const result = postprocessJudge(
      rawOutput({ matched_approach: "none", matched_verdict: "acceptable", insights_hit: [] }),
      problem,
    );
    expect(result.assessment.matched_verdict).toBe("none");
  });

  it("step 2: an unauthored key in either list is dropped", () => {
    const { assessment } = postprocessJudge(
      rawOutput({ insights_hit: [...requiredKeys, "not_a_real_key"], insights_missed: [] }),
      problem,
    );
    expect(assessment.insights_hit).not.toContain("not_a_real_key");
    expect(assessment.insights_missed).not.toContain("not_a_real_key");
  });

  it("step 3: mapVerdict() overrides a self-contradictory model verdict", () => {
    const { assessment, verdictOverridden, from, to } = postprocessJudge(
      rawOutput({ matched_verdict: "optimal", insights_hit: requiredKeys.slice(1), verdict: "pass" }),
      problem,
    );
    expect(verdictOverridden).toBe(true);
    expect(assessment.verdict).toBe("borderline");
    expect(from).toBe("pass");
    expect(to).toBe("borderline");
  });

  it("step 3: no override recorded when the model's verdict already matches the mapped value", () => {
    const { verdictOverridden } = postprocessJudge(rawOutput({ verdict: "pass" }), problem);
    expect(verdictOverridden).toBe(false);
  });

  it("step 4: unhedged verdict words are replaced wholesale with the fallback", () => {
    const cases = [
      "That's correct, you nailed it.",
      "No, you're wrong about the complexity.",
      "This is not right for large inputs.",
      "Correct.",
    ];
    for (const feedback of cases) {
      const { assessment } = postprocessJudge(rawOutput({ feedback }), problem);
      expect(assessment.feedback).toContain("have a look at the walkthrough");
    }
  });

  it("step 4: hedged, legitimate phrasing passes through untouched", () => {
    const cases = [
      "You're on the right track with the hash map idea.",
      "The right data structure here would be a hash map.",
      "A perfect hash would be overkill, but your instinct was sound.",
    ];
    for (const feedback of cases) {
      const { assessment } = postprocessJudge(rawOutput({ feedback }), problem);
      expect(assessment.feedback).toBe(feedback);
    }
  });

  it("step 5: a four-sentence feedback is cut to two sentences", () => {
    const feedback = "First sentence here. Second sentence here. Third sentence here. Fourth sentence here.";
    const { assessment } = postprocessJudge(rawOutput({ feedback }), problem);
    expect(assessment.feedback).toBe("First sentence here. Second sentence here.");
  });

  it("step 5: a 400-char two-sentence feedback is cut to 320 chars on a word boundary", () => {
    const clause = "word ".repeat(70).trim();
    const feedback = `${clause}. ${clause}.`;
    expect(feedback.length).toBeGreaterThan(320);
    const { assessment } = postprocessJudge(rawOutput({ feedback }), problem);
    expect(assessment.feedback.length).toBeLessThanOrEqual(320);
    expect(assessment.feedback.endsWith(" ")).toBe(false);
  });

  it("step 6: editorial is attached and was never part of the raw model output", () => {
    const { assessment } = postprocessJudge(rawOutput(), problem);
    expect(assessment.editorial).toBe(problem.private.editorial);
  });
});

describe("isSelfContradictory()", () => {
  const assess = (o: Record<string, unknown>) => postprocessJudge(rawOutput(o), problem).assessment;

  it("flags the optimal approach with no insight recognised", () => {
    expect(isSelfContradictory(assess({ insights_hit: [], insights_missed: [] }), problem)).toBe(true);
  });

  it("flags every required insight with the brute-force approach", () => {
    expect(isSelfContradictory(assess({ matched_approach: "brute_force" }), problem)).toBe(true);
  });

  it("accepts a consistent assessment, and any assessment with no reference approach", () => {
    expect(isSelfContradictory(assess({}), problem)).toBe(false);
    expect(isSelfContradictory(assess({ matched_approach: "none", matched_verdict: "none", insights_hit: [] }), problem)).toBe(false);
  });
});

// Review F3 follow-up, 2026-10-07.
describe("postprocessJudge() — an unsure model is not lifted to a pass", () => {
  it("confidence below 0.6 keeps the model's own non-passing verdict", () => {
    const { assessment } = postprocessJudge(rawOutput({ verdict: "borderline", confidence: 0.5 }), problem);
    expect(assessment.verdict).toBe("borderline");
  });

  it("a confident model is still overridden by the map", () => {
    const { assessment } = postprocessJudge(rawOutput({ verdict: "borderline", confidence: 0.85 }), problem);
    expect(assessment.verdict).toBe("pass");
  });

  it("an unsure model can still be mapped DOWN", () => {
    const { assessment } = postprocessJudge(
      rawOutput({ matched_approach: "brute_force", verdict: "pass", confidence: 0.4 }),
      problem,
    );
    expect(assessment.verdict).toBe("likely_tle");
  });
});
