// Feature 005, specs/005-finish-offer. Decides which key insights the
// learner has reached so far (prompt v4). The server derives three things
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
// accepted "compare both ends" and the judge credited nothing). The tutor's
// words can only ever produce `assisted`, never `reached`, so a tutor that
// names an idea still cannot make the learner look like they said it; the
// caller keeps `assisted` out of the leak filter.
//
// Input is the problem, the private key insights, their never_say terms and
// the conversation, each line labelled `user:` or `tutor:`.
import { FINISH_CHECK_PROMPT } from "../prompts/finish-check";
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
 * Strict schema: `reached` and `assisted` may only name this problem's
 * insight keys and `named` only its never_say terms. `named` is left out when there are no
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
        reached: { type: "array", items: { type: "string", enum: keys } },
        assisted: { type: "array", items: { type: "string", enum: keys } },
        ...(terms.length > 0 ? { named: { type: "array", items: { type: "string", enum: terms } } } : {}),
      },
      required: terms.length > 0 ? ["reached", "assisted", "named"] : ["reached", "assisted"],
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
}

/** `null` when the check failed or answered nothing usable. */
export async function runFinishCheck(
  problem: Problem,
  history: Turn[],
  call: FinishCheckCall,
): Promise<FinishCheckResult | null> {
  try {
    const { result } = await call(FINISH_CHECK_PROMPT, buildFinishCheckInput(problem, history), finishCheckSchema(problem));
    const json = result.json as { reached?: unknown; assisted?: unknown; named?: unknown } | undefined;
    if (!Array.isArray(json?.reached)) return null;
    const authored = new Set(problem.private.key_insights.map((i) => i.key));
    const reached = [...new Set(json.reached.filter((k): k is string => typeof k === "string" && authored.has(k)))];
    // A missing or malformed `assisted` or `named` costs only its own list,
    // never the `reached` result above. A key the learner stated themselves is
    // `reached` only (PLAN_07 D4).
    const assisted = Array.isArray(json.assisted)
      ? [...new Set(json.assisted.filter((k): k is string => typeof k === "string" && authored.has(k) && !reached.includes(k)))]
      : [];
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
    return { ready: isReady(problem, reached), reached, assisted, named };
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
