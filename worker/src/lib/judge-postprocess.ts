// contracts/judge-system-prompt.md §Server-side post-processing. Six steps,
// mandatory, in this exact order. Everything but step 6 (attach editorial)
// operates on the model's own output; step 6 is the only path by which
// private content is ever released (FR-022).
//
// Step 2a, evidence: claimed insights and approaches need the learner's own
// words, checked in judge-evidence.ts (docs/judge-evidence-issues.md,
// 2026-10-11). The quotes stop here: the Assessment carries keys only.
import { z } from "zod";
import type { Problem } from "../../../tools/problem-types";
import { AppError } from "./errors";
import { mapVerdict, requiredKeysFor, type JudgeOutput, type Verdict } from "./verdict-map";
import { takeCompleteSentence } from "./leak-filter";
import { JUDGE_FEEDBACK_FALLBACK } from "../prompts/judge";
import type { Evidence } from "./judge-evidence";

// Step 1: structural shape only. Per-problem key enums are already enforced
// upstream by strict json_schema decoding (judge-schema.ts); this is a
// defensive net against a refusal or a shape the provider client's own
// UNCLEAR_RETRY paths did not already catch.
const rawJudgeOutputSchema = z.object({
  approach_quote: z.string(),
  matched_approach: z.string(),
  matched_verdict: z.enum(["optimal", "acceptable", "suboptimal", "wrong", "none"]),
  insights_hit: z.array(z.object({ quote: z.string(), key: z.string() })),
  insights_missed: z.array(z.string()),
  wrong_turns_taken: z.array(z.string()),
  complexity: z.object({
    user_claimed_time: z.string().nullable(),
    user_claimed_space: z.string().nullable(),
    reference_time: z.string(),
    reference_space: z.string(),
    assessment: z.enum(["correct", "mismatched", "not_stated"]),
  }),
  verdict: z.enum(["strong_pass", "pass", "borderline", "likely_tle", "incorrect", "unclear"]),
  confidence: z.number(),
  feedback: z.string(),
});

export type RawJudgeOutput = z.infer<typeof rawJudgeOutputSchema>;

/** Step 1 on its own, for callers that need the typed answer (judge-core.ts). */
export function parseJudgeOutput(raw: unknown): RawJudgeOutput {
  const parsed = rawJudgeOutputSchema.safeParse(raw);
  if (!parsed.success) {
    throw new AppError("UNCLEAR_RETRY");
  }
  return parsed.data;
}

export interface Assessment {
  matched_approach: string;
  matched_verdict: "optimal" | "acceptable" | "suboptimal" | "wrong" | "none";
  insights_hit: string[];
  insights_missed: string[];
  wrong_turns_taken: string[];
  complexity: {
    user_claimed_time: string | null;
    user_claimed_space: string | null;
    reference_time: string;
    reference_space: string;
    assessment: "correct" | "mismatched" | "not_stated";
  };
  verdict: Verdict;
  confidence: number;
  feedback: string;
  editorial: string;
}

/** judge prompt: "Below 0.6 means you are genuinely unsure". */
const UNSURE_CONFIDENCE = 0.6;
const PASSING: ReadonlySet<Verdict> = new Set(["pass", "strong_pass"]);

export interface JudgePostprocessResult {
  assessment: Assessment;
  verdictOverridden: boolean;
  from?: Verdict;
  to?: Verdict;
  /** What the evidence checks removed. Set only when `evidence` was passed; never on the wire. */
  evidenceDropped?: { approach: boolean; insights: number };
}

// Step 4's two patterns, fixed verbatim by contracts/judge-system-prompt.md
// §Server-side post-processing step 4. Do NOT reuse text-match.ts's
// normalise() — both patterns depend on apostrophes and sentence
// punctuation surviving.
const COPULA_ADJACENT =
  /\b(is|isn'?t|was|wasn'?t|are|aren'?t|that'?s|this is|it'?s|you'?re|we'?re|were|be|been|being)\s+(not\s+|quite\s+|entirely\s+|really\s+|totally\s+){0,2}(correct|incorrect|wrong|right|perfect)\b/;
const STANDALONE_SENTENCE = /(^|[.!?]\s+)(correct|incorrect|wrong|right|perfect)\s*[.!?]/;

function truncateFeedback(feedback: string): string {
  // First at the second sentence boundary.
  let remaining = feedback;
  let twoSentences = "";
  for (let i = 0; i < 2; i++) {
    const taken = takeCompleteSentence(remaining);
    if (!taken) {
      twoSentences += remaining;
      remaining = "";
      break;
    }
    twoSentences += taken.sentence;
    remaining = taken.remainder;
  }
  const afterSentenceCap = twoSentences.trim().length > 0 ? twoSentences : feedback;

  // Then at 320 chars on a word boundary.
  if (afterSentenceCap.length <= 320) return afterSentenceCap;
  const cut = afterSentenceCap.slice(0, 320);
  const lastSpace = cut.lastIndexOf(" ");
  return (lastSpace > 0 ? cut.slice(0, lastSpace) : cut).trimEnd();
}

/**
 * `raw` is the model's parsed JSON (provider-groq.ts already throws
 * UNCLEAR_RETRY on a refusal or unparseable body — step 1's remaining job
 * is a shape check on what did parse). `editorial` is the problem's
 * reveal-screen markdown, attached in step 6 and never sent to the
 * provider. `evidence` is judge-evidence.ts's verdict on the model's quotes;
 * without it the model's own claims stand (the retry decision, and callers
 * that have no learner turns to check against).
 */
export function postprocessJudge(raw: unknown, problem: Problem, evidence?: Evidence): JudgePostprocessResult {
  // Step 1: refusal / malformed / non-JSON -> UNCLEAR_RETRY.
  const out = parseJudgeOutput(raw);

  // Step 2: insight coverage repair. Every authored key ends up in exactly
  // one of insights_hit / insights_missed; unauthored keys are dropped.
  const authoredKeys = new Set(problem.private.key_insights.map((i) => i.key));
  const hit = new Set(out.insights_hit.map((h) => h.key).filter((k) => authoredKeys.has(k)));
  const missed = new Set(out.insights_missed.filter((k) => authoredKeys.has(k) && !hit.has(k)));
  for (const key of authoredKeys) {
    if (!hit.has(key) && !missed.has(key)) missed.add(key);
  }

  // Step 2a: an insight the learner's words do not support was not reached.
  let insightsDropped = 0;
  if (evidence) {
    for (const key of [...hit]) {
      if (!evidence.supportedInsights.has(key)) {
        hit.delete(key);
        missed.add(key);
        insightsDropped++;
      }
    }
  }

  // The model's job is to recognise WHICH reference approach the learner
  // described; how good that approach is, is authored. Nemotron named the
  // one-pass hash map and still labelled it "suboptimal" (2026-10-04),
  // which mapVerdict() turned into likely_tle for an optimal answer. An
  // approach that is not authored (in practice "none") gets no tier at all:
  // the model answered none + acceptable and the app showed "matched a
  // solid, accepted approach" beside "Approach: None" (2026-10-11).
  const claimedApproach = problem.private.reference_approaches.find((a) => a.key === out.matched_approach);
  // Step 2a: an approach whose words do not describe it is "none". A `wrong`
  // approach keeps its place: dropping it could only raise the grade.
  const approachDemoted = !!evidence && !!claimedApproach && claimedApproach.verdict !== "wrong" && !evidence.approachSupported;
  const authoredApproach = approachDemoted ? undefined : claimedApproach;
  const repaired: JudgeOutput = {
    matched_approach: approachDemoted ? "none" : out.matched_approach,
    matched_verdict: authoredApproach?.verdict ?? "none",
    insights_hit: [...hit],
    insights_missed: [...missed],
    wrong_turns_taken: out.wrong_turns_taken.filter((k) =>
      problem.private.common_wrong_turns.some((w) => w.key === k),
    ),
    verdict: out.verdict,
  };

  // Step 3: verdict override. The mapped value wins, with one exception:
  // below the prompt's own "genuinely unsure" line, the map may not lift
  // the verdict to a pass the model itself did not give. "um, numbers,
  // digits, add, I guess loop?" was credited with the loop approach and
  // one insight at confidence 0.5, model verdict borderline, and mapped to
  // pass (review F3 follow-up, 2026-10-07).
  const fullyMapped = mapVerdict(repaired, problem);
  const mapped =
    out.confidence < UNSURE_CONFIDENCE && PASSING.has(fullyMapped) && !PASSING.has(out.verdict)
      ? out.verdict
      : fullyMapped;
  const verdictOverridden = mapped !== out.verdict;

  // Step 4: hedge check. On a hit, the WHOLE feedback string is replaced.
  const lowered = out.feedback.toLowerCase();
  const hedgeViolation = COPULA_ADJACENT.test(lowered) || STANDALONE_SENTENCE.test(lowered);
  const hedgeChecked = hedgeViolation ? JUDGE_FEEDBACK_FALLBACK : out.feedback;

  // Step 5: truncation. Second-sentence boundary first, then 320 chars on
  // a word boundary.
  const feedback = truncateFeedback(hedgeChecked);

  // Step 6: attach the reveal. The only path private content ever crosses.
  const assessment: Assessment = {
    matched_approach: repaired.matched_approach,
    matched_verdict: repaired.matched_verdict,
    insights_hit: repaired.insights_hit,
    insights_missed: repaired.insights_missed,
    wrong_turns_taken: repaired.wrong_turns_taken,
    complexity: out.complexity,
    verdict: mapped,
    confidence: out.confidence,
    feedback,
    editorial: problem.private.editorial,
  };

  return {
    assessment,
    verdictOverridden,
    from: verdictOverridden ? (out.verdict as Verdict) : undefined,
    to: verdictOverridden ? mapped : undefined,
    evidenceDropped: evidence ? { approach: approachDemoted, insights: insightsDropped } : undefined,
  };
}

/**
 * An assessment whose parts cannot all be true: a good reference approach
 * recognised with not one key insight, or every required insight with a
 * suboptimal or wrong approach. Nemotron produced the first intermittently
 * for a plainly correct explanation (2026-10-04); judge-core.ts asks once
 * more when it sees either. Evaluated on the model's own unverified claims
 * (judge-evidence D8): a zero made by the evidence checks is deterministic,
 * so asking again would only spend budget and invite a better-made-up quote.
 */
export function isSelfContradictory(assessment: Assessment, problem: Problem): boolean {
  const approach = problem.private.reference_approaches.find((a) => a.key === assessment.matched_approach);
  if (!approach) return false;
  const required = [...requiredKeysFor(problem, approach.key)];
  const allRequiredHit = required.length > 0 && required.every((k) => assessment.insights_hit.includes(k));
  const goodApproach = approach.verdict === "optimal" || approach.verdict === "acceptable";
  return (goodApproach && assessment.insights_hit.length === 0) || (!goodApproach && allRequiredHit);
}
