// data-model.md §B4. Pure. `judge-spec.md` §5's table, inlined here in
// precedence order — first match wins. The mapped value always wins over
// the model's own `verdict` field (FR-019).
import type { Problem } from "../../../tools/problem-types";

export type Verdict = "strong_pass" | "pass" | "borderline" | "likely_tle" | "incorrect" | "unclear";

export interface JudgeOutput {
  matched_approach: string;
  matched_verdict: "optimal" | "acceptable" | "suboptimal" | "wrong" | "none";
  insights_hit: string[];
  insights_missed: string[];
  /**
   * Subset of `insights_hit` the learner reached by accepting an idea the
   * tutor put into words (2026-10-12, PLAN_07). Absent = none.
   */
  insights_assisted?: string[];
  wrong_turns_taken: string[];
  verdict: Verdict;
}

function approachVerdictOf(problem: Problem, approachKey: string): string | undefined {
  return problem.private.reference_approaches.find((a) => a.key === approachKey)?.verdict;
}

/**
 * SPEC GAP, flagged rather than silently invented (plan.md Gate H): §B4's
 * pseudocode calls `raisedAnEdgeCase(out)` but no prior document defines
 * it, and `judge-output.schema.json` has no dedicated field for it —
 * `problem.private.edge_cases` is plain strings with no keys a model could
 * cite back, unlike `insights_hit`/`wrong_turns_taken`. Interim reading,
 * built only from fields the schema already carries: a NON-required
 * insight is the schema's only "beyond the minimum" signal, so hitting at
 * least one is treated as edge-case depth. Needs a product-owner call to
 * either confirm this reading or add a dedicated `edge_cases_hit` field.
 */
function raisedAnEdgeCase(out: JudgeOutput, problem: Problem): boolean {
  const requiredKeys = requiredKeysFor(problem, out.matched_approach);
  return out.insights_hit.some((k) => !requiredKeys.has(k));
}

/**
 * The insights a pass needs ON THE APPROACH THE LEARNER TOOK: the
 * approach's own `requires` when authored, else the problem's
 * `required: true` set. `required` describes the optimal approach, so
 * without `requires` a perfect explanation of an acceptable approach was
 * capped at borderline on every model (review F3, 2026-10-07).
 */
export function requiredKeysFor(problem: Problem, approachKey: string): Set<string> {
  const approach = problem.private.reference_approaches.find((a) => a.key === approachKey);
  return new Set(
    approach?.requires ?? problem.private.key_insights.filter((i) => i.required).map((i) => i.key),
  );
}

export function mapVerdict(out: JudgeOutput, problem: Problem): Verdict {
  const requiredKeys = requiredKeysFor(problem, out.matched_approach);
  const hitSet = new Set(out.insights_hit);
  const allRequiredHit = [...requiredKeys].every((k) => hitSet.has(k));
  // A nudge is honest help and counts toward a pass, but top marks need every
  // required insight in the learner's own words (2026-10-12, PLAN_07 D10).
  const assistedSet = new Set(out.insights_assisted ?? []);
  const allRequiredOwn = [...requiredKeys].every((k) => !assistedSet.has(k));
  // §B4: a wrong_turns_taken entry "breaks correctness" when it names a key
  // that also appears among reference_approaches with verdict "wrong" —
  // exactly the pseudocode's approachVerdictOf(problem, wt) == "wrong".
  const brokeCorrectness = out.wrong_turns_taken.some((wt) => approachVerdictOf(problem, wt) === "wrong");

  // No insight stated at all: the matched approach is the model's only
  // evidence, so its own "unclear" stands. Without it a garbled turn that
  // brushed an approach name mapped to likely_tle (review F8).
  if (out.insights_hit.length === 0 && out.verdict === "unclear") return "unclear";
  // An unlisted approach the model calls incorrect stays incorrect whatever
  // the insight count: postprocessJudge() no longer lets such an approach
  // carry "wrong", so the model's verdict is the only signal left. A wrong
  // idea no reference covers used to map to unclear (review F8; 2026-10-11).
  if (out.matched_approach === "none" && out.verdict === "incorrect") return "incorrect";
  if (out.matched_approach === "none" && out.insights_hit.length === 0) return "unclear";
  if (out.matched_verdict === "wrong" || brokeCorrectness) return "incorrect";
  if (out.matched_verdict === "suboptimal") return "likely_tle";
  if (!allRequiredHit) return "borderline";
  if (out.matched_verdict === "optimal" && allRequiredOwn && raisedAnEdgeCase(out, problem)) return "strong_pass";
  if (out.matched_verdict === "optimal" || out.matched_verdict === "acceptable") return "pass";
  // An approach the catalogue does not list, that nonetheless reached every
  // required insight and took no wrong turn.
  //
  // DEPARTURE from judge-spec.md §5's table, which has no row for this and
  // fell through to "unclear". That contradicted the judge prompt one file
  // over, which instructs the model to "set matched_approach to 'none' and
  // judge on the insights and the constraints alone" — the mapping then
  // threw that judgement away. A learner who solves the problem a way the
  // author did not think of was told the conversation was too garbled to
  // classify, which is both wrong and the most discouraging thing the app
  // can say. "pass" and not "strong_pass": the catalogue cannot confirm an
  // unlisted approach is optimal, so that is the honest ceiling.
  if (out.matched_verdict === "none") return "pass";
  return "unclear";
}

export { approachVerdictOf };
