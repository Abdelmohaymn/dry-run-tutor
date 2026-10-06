// The shared body of one assessment, extracted from routes/judge.ts so
// routes/trial.ts (T092) can reuse it against a pool-selected credential.
import type { JudgeRequest, Turn } from "./schemas";
import { claimJudge, releaseJudgeClaim, type TurnCounterKey } from "./turn-cap";
import { judgeSlice, renderJudgeGroundTruth } from "./ground-truth";
import { buildJudgeSchema } from "./judge-schema";
import { isSelfContradictory, postprocessJudge, type Assessment } from "./judge-postprocess";
import { JUDGE_PROMPT } from "../prompts/judge";
import { AppError } from "./errors";
import type { StructuredCompletionResult } from "./provider";
import type { Problem } from "../../../tools/problem-types";

export const JUDGE_CONVERSATION_PLACEHOLDER = "It is in the user message below, one turn per line.";

function renderConversation(turns: Turn[]): string {
  return turns.map((t) => `${t.role}: ${t.text}`).join("\n");
}

export interface JudgeDeps {
  db: D1Database;
  installId: string;
  problemId: string;
  date: string;
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

  const slice = judgeSlice(problem);
  const groundTruthText = renderJudgeGroundTruth(slice);
  // The conversation goes in the user message, not the system prompt:
  // with it inlined there, Nemotron intermittently returned a hollow
  // assessment for a plainly correct explanation (2026-10-04).
  const systemPrompt = JUDGE_PROMPT.replace("{{GROUND_TRUTH}}", groundTruthText).replace(
    "{{CONVERSATION}}",
    JUDGE_CONVERSATION_PLACEHOLDER,
  );
  const userContent = `${renderConversation(conversation)}\n\nReturn the assessment now.`;

  const ask = () =>
    deps.structuredCompletion(systemPrompt, userContent, {
      name: "assessment",
      schema: buildJudgeSchema(problem),
    });
  let postprocessed: ReturnType<typeof postprocessJudge>;
  try {
    postprocessed = postprocessJudge((await ask()).result.json, problem);
    // One more ask when the answer contradicts itself. The first answer
    // stands if the second fails or is no better.
    if (isSelfContradictory(postprocessed.assessment, problem)) {
      try {
        const secondProcessed = postprocessJudge((await ask()).result.json, problem);
        if (!isSelfContradictory(secondProcessed.assessment, problem)) {
          postprocessed = secondProcessed;
        }
      } catch {
        // Keep the first assessment.
      }
    }
  } catch (err) {
    // Nothing assessable came back. Hand the session's one assessment back
    // before surfacing the error, or the retry we are about to advise is a
    // guaranteed SESSION_ALREADY_JUDGED.
    await releaseJudgeClaim(deps.db, key, judgedAt);
    throw err instanceof AppError ? err : new AppError("UNCLEAR_RETRY");
  }

  return postprocessed.assessment;
}
