// Feature 005, specs/005-finish-offer. Decides whether the learner has
// already explained every required key insight, so the app can offer to
// finish. Runs alongside the tutor reply and never fails the turn: any
// error, refusal or malformed answer is "not ready".
//
// Input is the problem, the private key insights and the learner's own
// turns. The tutor's turns are left out on purpose: a tutor that names an
// idea must not make the learner look ready.
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

export const FINISH_CHECK_SCHEMA = {
  name: "finish_check",
  schema: {
    type: "object",
    properties: { ready: { type: "boolean" } },
    required: ["ready"],
    additionalProperties: false,
  },
};

/** The user message: problem, insights, then the learner's words only. */
export function buildFinishCheckInput(problem: Problem, history: Turn[]): string {
  const insights = problem.private.key_insights
    .map((i) => `- [${i.required ? "required" : "optional"}] ${i.text}`)
    .join("\n");
  const learner = history
    .filter((t) => t.role === "user")
    .map((t, n) => `${n + 1}. ${t.text}`)
    .join("\n");
  return [
    `Problem: ${problem.public.title}`,
    problem.public.statement,
    "",
    "Key insights:",
    insights,
    "",
    "The learner's words so far, oldest first:",
    learner,
  ].join("\n");
}

export async function runFinishCheck(
  problem: Problem,
  history: Turn[],
  call: FinishCheckCall,
): Promise<boolean> {
  try {
    const { result } = await call(
      FINISH_CHECK_PROMPT,
      buildFinishCheckInput(problem, history),
      FINISH_CHECK_SCHEMA,
    );
    const json = result.json as { ready?: unknown } | undefined;
    return json?.ready === true;
  } catch {
    return false;
  }
}

/** Resolves to `false` if [check] has not settled within [ms]. */
export function withinMs(check: Promise<boolean>, ms: number): Promise<boolean> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<boolean>((resolve) => {
    timer = setTimeout(() => resolve(false), ms);
  });
  return Promise.race([check, timeout]).finally(() => clearTimeout(timer));
}
