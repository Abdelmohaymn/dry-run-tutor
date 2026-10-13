// Feature 005, specs/005-finish-offer. Decides which key insights the
// learner has reached so far (prompt v5). The server derives three things
// from the answer: whether every required insight is in (the finish
// offer), which insights' never_say words the leak filter may stop
// blocking (review F4, replacing the word-overlap guess), and which
// insights the learner reached only with the tutor's help. Runs alongside
// the tutor reply and never fails the turn: any error, refusal or
// malformed answer is "nothing new reached".
//
// It also reports `named`: the never_say terms the learner referred to in any
// form (an abbreviation, a speech-recognition mangling, another language),
// which the leak filter stops blocking from the next turn, or this turn when a
// draft is blocked (2026-10-11,
// docs/tutor-focus-issues.md Issue 1). Naming a term is not having the idea:
// `named` never touches `reached` or `ready`.
//
// `assisted` (2026-10-12, PLAN_07): the tutor put the idea into words and the
// learner accepted it. The check now sees both roles, because otherwise the
// Finish card and the judge disagreed on the vp-0003 session (the learner
// accepted "compare both ends" and the judge credited nothing). The caller
// keeps `assisted` out of the leak filter.
//
// The check quotes its evidence (2026-10-13, PLAN_08, prompt v5), and the
// server decides own words versus with a nudge from the quote that holds up,
// not from a label the model chose: in the playtest an unchecked answer
// credited "complement lookup, with a nudge" after the learner said only
// "nested loop", and showed an idea only the tutor stated as the learner's own
// words. So a tutor's words can only ever produce `assisted`, and that is
// enforced by provenance, not trusted: a learner_quote found only in a tutor
// line is `assisted`, a quote found in no line drops the key. Quotes live in
// `FinishCheckResult.evidence` for one request: never stored, logged or
// returned.
//
// Input is the problem, the private key insights, their never_say terms and
// the conversation, each line labelled `user:` or `tutor:`.
import { FINISH_CHECK_PROMPT } from "../prompts/finish-check";
import { quotedTurnIndex, type InsightEvidence } from "./judge-evidence";
import type { StructuredCompletionResult } from "./provider";
import type { Turn } from "./schemas";
import type { Problem } from "../../../tools/problem-types";

export type FinishCheckCall = (
  systemPrompt: string,
  userContent: string,
  jsonSchema: { name: string; schema: Record<string, unknown> },
) => Promise<{ result: StructuredCompletionResult; providerId: string; model: string }>;

/**
 * Headroom for a reasoning model's hidden tokens before the one-field
 * answer (the same failure condense.ts documents at its maxTokens).
 */
export const FINISH_CHECK_MAX_TOKENS = 1500;

/** Every insight's never_say term, lowercased, deduplicated, in authored order. */
export function neverSayTerms(problem: Problem): string[] {
  return [...new Set(problem.private.key_insights.flatMap((i) => i.never_say.map((t) => t.toLowerCase())))];
}

/**
 * Strict schema: `insights` entries may only name this problem's insight keys
 * (each with a learner quote and a tutor quote, "" when there is none) and
 * `named` only its never_say terms. `named` is left out when there are no
 * terms: strict mode rejects an empty enum.
 */
export function finishCheckSchema(problem: Problem): { name: string; schema: Record<string, unknown> } {
  const terms = neverSayTerms(problem);
  const keys = problem.private.key_insights.map((i) => i.key);
  return {
    name: "finish_check",
    schema: {
      type: "object",
      properties: {
        insights: {
          type: "array",
          items: {
            type: "object",
            properties: {
              key: { type: "string", enum: keys },
              learner_quote: { type: "string" },
              tutor_quote: { type: "string" },
            },
            required: ["key", "learner_quote", "tutor_quote"],
            additionalProperties: false,
          },
        },
        ...(terms.length > 0 ? { named: { type: "array", items: { type: "string", enum: terms } } } : {}),
      },
      required: terms.length > 0 ? ["insights", "named"] : ["insights"],
      additionalProperties: false,
    },
  };
}

/** The user message: problem, insights by key, then the conversation with both roles labelled. */
export function buildFinishCheckInput(problem: Problem, history: Turn[]): string {
  const insights = problem.private.key_insights.map((i) => `- ${i.key}: ${i.text}`).join("\n");
  const terms = neverSayTerms(problem);
  const termsBlock = terms.length > 0 ? ["Terms:", ...terms.map((t) => `- ${t}`), ""] : [];
  const conversation = history.map((t) => `${t.role}: ${t.text}`).join("\n");
  return [
    `Problem: ${problem.public.title}`,
    problem.public.statement,
    "",
    "Key insights:",
    insights,
    "",
    ...termsBlock,
    "The conversation so far, oldest first:",
    conversation,
  ].join("\n");
}

export interface FinishCheckResult {
  /** Every `required: true` insight is in `reached`. */
  ready: boolean;
  /** Authored insight keys the learner has stated, per this check. */
  reached: string[];
  /** Authored insight keys the tutor put into words and the learner accepted. Never overlaps `reached`. */
  assisted: string[];
  /** Authored never_say terms (lowercased) the learner referred to in any form. Unblocks words only. */
  named: string[];
  /**
   * One entry per kept key, with the quotes that passed provenance (PLAN_08).
   * In memory for one request: never stored, logged or returned.
   */
  evidence: InsightEvidence[];
}

/**
 * `null` when the check failed or answered nothing usable. Provenance (PLAN_08
 * D2), per insight, in this order: a learner_quote found in a `user:` line is
 * reached; else a tutor_quote found in a `tutor:` line is assisted; else a
 * learner_quote found only in a `tutor:` line is assisted (the model credited
 * the tutor's words to the learner); else the insight is dropped.
 */
export async function runFinishCheck(
  problem: Problem,
  history: Turn[],
  call: FinishCheckCall,
): Promise<FinishCheckResult | null> {
  try {
    const { result } = await call(FINISH_CHECK_PROMPT, buildFinishCheckInput(problem, history), finishCheckSchema(problem));
    const json = result.json as { insights?: unknown; named?: unknown } | undefined;
    if (!Array.isArray(json?.insights)) return null;
    const authored = new Set(problem.private.key_insights.map((i) => i.key));
    const learnerTexts = history.filter((t) => t.role === "user").map((t) => t.text);
    const tutorTexts = history.filter((t) => t.role === "tutor").map((t) => t.text);
    const inLearner = (quote: string) => quotedTurnIndex(quote, learnerTexts) >= 0;
    const inTutor = (quote: string) => quotedTurnIndex(quote, tutorTexts) >= 0;

    const kept = new Map<string, InsightEvidence>();
    for (const raw of json.insights as unknown[]) {
      const entry = raw as { key?: unknown; learner_quote?: unknown; tutor_quote?: unknown } | null;
      if (
        !entry ||
        typeof entry.key !== "string" ||
        typeof entry.learner_quote !== "string" ||
        typeof entry.tutor_quote !== "string" ||
        !authored.has(entry.key)
      ) {
        continue;
      }
      const { key, learner_quote: learner, tutor_quote: tutor } = entry as { key: string; learner_quote: string; tutor_quote: string };
      const found: InsightEvidence | null = inLearner(learner)
        ? { key, learnerQuote: learner, tutorQuote: inTutor(tutor) ? tutor : null }
        : inTutor(tutor)
          ? { key, learnerQuote: null, tutorQuote: tutor }
          : inTutor(learner)
            ? { key, learnerQuote: null, tutorQuote: learner }
            : null;
      if (!found) continue;
      // The same key twice is one entry, and reached wins over assisted.
      const earlier = kept.get(key);
      if (!earlier || (earlier.learnerQuote === null && found.learnerQuote !== null)) kept.set(key, found);
    }
    const evidence = [...kept.values()];
    const reached = evidence.filter((e) => e.learnerQuote !== null).map((e) => e.key);
    const assisted = evidence.filter((e) => e.learnerQuote === null).map((e) => e.key);

    // A missing or malformed `named` costs only its own list, never the
    // insights above.
    const authoredTerms = new Set(neverSayTerms(problem));
    const named = Array.isArray(json.named)
      ? [
          ...new Set(
            json.named
              .filter((t): t is string => typeof t === "string")
              .map((t) => t.toLowerCase())
              .filter((t) => authoredTerms.has(t)),
          ),
        ]
      : [];
    return { ready: isReady(problem, reached), reached, assisted, named, evidence };
  } catch {
    return null;
  }
}

/** Ready = every required insight reached. A problem with none is never ready. */
export function isReady(problem: Problem, reached: readonly string[]): boolean {
  const required = problem.private.key_insights.filter((i) => i.required).map((i) => i.key);
  return required.length > 0 && required.every((k) => reached.includes(k));
}

/** Resolves to `null` if [check] has not settled within [ms]. */
export function withinMs<T>(check: Promise<T | null>, ms: number): Promise<T | null> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<null>((resolve) => {
    timer = setTimeout(() => resolve(null), ms);
  });
  return Promise.race([check, timeout]).finally(() => clearTimeout(timer));
}
