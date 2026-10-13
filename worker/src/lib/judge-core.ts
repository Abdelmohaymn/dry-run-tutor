// The shared body of one assessment, extracted from routes/judge.ts so
// routes/trial.ts (T092) can reuse it against a pool-selected credential.
import type { JudgeRequest, Turn } from "./schemas";
import { claimJudge, releaseJudgeClaim, type TurnCounterKey } from "./turn-cap";
import { judgeSlice, renderJudgeGroundTruth } from "./ground-truth";
import { buildJudgeSchema } from "./judge-schema";
import {
  isSelfContradictory,
  parseJudgeOutput,
  postprocessJudge,
  type Assessment,
  type SettledInsights,
} from "./judge-postprocess";
import { runFinishCheck, withinMs } from "./finish-check";
import { gatherEvidence, verifySettled } from "./judge-evidence";
import { JUDGE_PROMPT } from "../prompts/judge";
import { AppError } from "./errors";
import type { StructuredCompletionResult } from "./provider";
import type { Problem } from "../../../tools/problem-types";

export const JUDGE_CONVERSATION_PLACEHOLDER = "It is in the user message below, one turn per line.";

/** The "Settled insights" block the judge model is shown (judge prompt v7). */
function renderSettled(problem: Problem, reached: readonly string[], assisted: readonly string[]): string {
  const list = (keys: readonly string[]) => (keys.length > 0 ? keys.join(", ") : "none");
  const rest = problem.private.key_insights.map((i) => i.key).filter((k) => !reached.includes(k) && !assisted.includes(k));
  return [
    "Settled insights:",
    `- reached in their own words: ${list(reached)}`,
    `- reached with the tutor's help: ${list(assisted)}`,
    `- not reached: ${list(rest)}`,
  ].join("\n");
}

function renderConversation(turns: Turn[]): string {
  return turns.map((t) => `${t.role}: ${t.text}`).join("\n");
}

export interface JudgeDeps {
  db: D1Database;
  installId: string;
  problemId: string;
  date: string;
  /**
   * How long the judge-time progress check may take (`finish_offer.timeout_ms`,
   * 2026-10-12, PLAN_07). A check that is late counts as failed.
   */
  finishCheckTimeoutMs: number;
  /** Resolves the credential and makes the structured-completion call. */
  structuredCompletion: (
    systemPrompt: string,
    userContent: string,
    jsonSchema: { name: string; schema: Record<string, unknown> },
  ) => Promise<{ result: StructuredCompletionResult; providerId: string; model: string }>;
}

export async function runJudge(deps: JudgeDeps, body: JudgeRequest, problem: Problem): Promise<Assessment> {
  const key: TurnCounterKey = { installId: deps.installId, problemId: deps.problemId, date: deps.date };

  // Claimed before the provider call (FR-013a, Constitution X.1), and
  // RELEASED again if no assessment comes back — Constitution VIII.
  const { judgedAt } = await claimJudge(deps.db, key);

  // FR-021/FR-021a: a solution-ended session is graded on the conversation
  // as it stood before the reveal.
  const conversation =
    body.ended_by === "solution" ? body.conversation.slice(0, body.reveal_at_index!) : body.conversation;

  // Each learner turn with the tutor turn just before it, so the evidence
  // check can read "2 pointers" as the answer to "how would you check one
  // word?" (2026-10-12, PLAN_06). Provenance still checks learner text only.
  const learnerTurns = conversation.flatMap((t, i) =>
    t.role === "user" ? [{ text: t.text, asked: conversation[i - 1]?.role === "tutor" ? conversation[i - 1].text : null }] : [],
  );

  // One source with the Finish card, verified (2026-10-13, PLAN_08): the
  // progress check runs once more on the judged conversation and quotes its
  // evidence; the quotes that hold up in a support check are the insight
  // lists. Earlier turns' stored keys are not read: merging unverified runs
  // only added false credit ("nested loop" got "complement lookup, with a
  // nudge"). No final answer: today's path (the model's lists plus the
  // evidence check). It runs whatever finish_offer.enabled says: the judge
  // needs it either way.
  const final = await withinMs(
    runFinishCheck(problem, conversation, deps.structuredCompletion),
    deps.finishCheckTimeoutMs,
  );
  const verified = final
    ? await verifySettled(final.evidence, learnerTurns, problem, deps.structuredCompletion)
    : null;
  const settled: SettledInsights | undefined = verified
    ? { hit: [...verified.reached, ...verified.assisted], assisted: verified.assisted }
    : undefined;

  const slice = judgeSlice(problem);
  const groundTruthText = renderJudgeGroundTruth(slice);
  // The conversation goes in the user message, not the system prompt:
  // with it inlined there, Nemotron intermittently returned a hollow
  // assessment for a plainly correct explanation (2026-10-04).
  const systemPrompt = JUDGE_PROMPT.replace("{{GROUND_TRUTH}}", groundTruthText).replace(
    "{{CONVERSATION}}",
    JUDGE_CONVERSATION_PLACEHOLDER,
  );
  const settledBlock = verified ? `${renderSettled(problem, verified.reached, verified.assisted)}\n\n` : "";
  const userContent = `${renderConversation(conversation)}\n\n${settledBlock}Return the assessment now.`;

  const ask = () =>
    deps.structuredCompletion(systemPrompt, userContent, {
      name: "assessment",
      schema: buildJudgeSchema(problem),
    });
  let postprocessed: ReturnType<typeof postprocessJudge>;
  try {
    let raw = (await ask()).result.json;
    // One more ask when the answer contradicts itself, decided on the model's
    // own claims: a zero made by the evidence checks is deterministic, so
    // asking again would only spend budget. The first answer stands if the
    // second fails or is no better.
    if (isSelfContradictory(postprocessJudge(raw, problem, undefined, settled).assessment, problem)) {
      try {
        const second = (await ask()).result.json;
        if (!isSelfContradictory(postprocessJudge(second, problem, undefined, settled).assessment, problem)) raw = second;
      } catch {
        // Keep the first assessment.
      }
    }
    // The quotes are checked once, on whichever answer was kept. Never throws.
    // With settled lists the insights were verified before the judge call
    // (PLAN_08 D5), so no insight claim is sent here; only the approach is
    // checked.
    const parsed = parseJudgeOutput(raw);
    const evidence = await gatherEvidence(
      settled ? { ...parsed, insights_hit: [] } : parsed,
      learnerTurns,
      problem,
      deps.structuredCompletion,
    );
    postprocessed = postprocessJudge(raw, problem, evidence, settled);
  } catch (err) {
    // Nothing assessable came back. Hand the session's one assessment back
    // before surfacing the error, or the retry we are about to advise is a
    // guaranteed SESSION_ALREADY_JUDGED.
    await releaseJudgeClaim(deps.db, key, judgedAt);
    throw err instanceof AppError ? err : new AppError("UNCLEAR_RETRY");
  }

  return postprocessed.assessment;
}
