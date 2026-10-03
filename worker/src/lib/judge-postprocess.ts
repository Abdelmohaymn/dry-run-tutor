// contracts/judge-system-prompt.md §Server-side post-processing. Six steps,
// mandatory, in this exact order. Everything but step 6 (attach editorial)
// operates on the model's own output; step 6 is the only path by which
// private content is ever released (FR-022).
import { z } from "zod";
import type { Problem } from "../../../tools/problem-types";
import { AppError } from "./errors";
import { mapVerdict, type JudgeOutput, type Verdict } from "./verdict-map";
import { takeCompleteSentence } from "./leak-filter";
import { JUDGE_FEEDBACK_FALLBACK } from "../prompts/judge";

// Step 1: structural shape only. Per-problem key enums are already enforced
// upstream by strict json_schema decoding (judge-schema.ts); this is a
// defensive net against a refusal or a shape the provider client's own
// UNCLEAR_RETRY paths did not already catch.
const rawJudgeOutputSchema = z.object({
  matched_approach: z.string(),
  matched_verdict: z.enum(["optimal", "acceptable", "suboptimal", "wrong", "none"]),
  insights_hit: z.array(z.string()),
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

export interface JudgePostprocessResult {
  assessment: Assessment;
  verdictOverridden: boolean;
  from?: Verdict;
  to?: Verdict;
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
 * provider.
 */
export function postprocessJudge(raw: unknown, problem: Problem): JudgePostprocessResult {
  // Step 1: refusal / malformed / non-JSON -> UNCLEAR_RETRY.
  const parsed = rawJudgeOutputSchema.safeParse(raw);
  if (!parsed.success) {
    throw new AppError("UNCLEAR_RETRY");
  }
  const out = parsed.data;

  // Step 2: insight coverage repair. Every authored key ends up in exactly
  // one of insights_hit / insights_missed; unauthored keys are dropped.
  const authoredKeys = new Set(problem.private.key_insights.map((i) => i.key));
  const hit = new Set(out.insights_hit.filter((k) => authoredKeys.has(k)));
  const missed = new Set(out.insights_missed.filter((k) => authoredKeys.has(k) && !hit.has(k)));
  for (const key of authoredKeys) {
    if (!hit.has(key) && !missed.has(key)) missed.add(key);
  }

  const repaired: JudgeOutput = {
    matched_approach: out.matched_approach,
    matched_verdict: out.matched_verdict,
    insights_hit: [...hit],
    insights_missed: [...missed],
    wrong_turns_taken: out.wrong_turns_taken.filter((k) =>
      problem.private.common_wrong_turns.some((w) => w.key === k),
    ),
    verdict: out.verdict,
  };

  // Step 3: verdict override. The mapped value always wins.
  const mapped = mapVerdict(repaired, problem);
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
    matched_verdict: out.matched_verdict,
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
  };
}
