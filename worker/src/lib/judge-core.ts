// The shared body of one assessment, extracted from routes/judge.ts so
// routes/trial.ts (T092) can reuse it against a pool-selected credential.
import type { JudgeRequest, Turn } from "./schemas";
import { claimJudge, releaseJudgeClaim, type TurnCounterKey } from "./turn-cap";
import { judgeSlice, renderJudgeGroundTruth } from "./ground-truth";
import { buildJudgeSchema } from "./judge-schema";
import { postprocessJudge, type Assessment } from "./judge-postprocess";
import { JUDGE_PROMPT } from "../prompts/judge";
import { writeUsage, type UsageEndpoint } from "./usage";
import { writeEvent } from "./events";
import { nowIso } from "./time";
import { AppError } from "./errors";
import type { StructuredCompletionResult } from "./provider";
import type { Problem } from "../../../tools/problem-types";

function renderConversation(turns: Turn[]): string {
  return turns.map((t) => `${t.role}: ${t.text}`).join("\n");
}

export interface JudgeDeps {
  db: D1Database;
  installId: string;
  problemId: string;
  date: string;
  usageEndpoint: UsageEndpoint; // "judge" | "trial_judge"
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
  const systemPrompt = JUDGE_PROMPT.replace("{{GROUND_TRUTH}}", groundTruthText).replace(
    "{{CONVERSATION}}",
    renderConversation(conversation),
  );

  const startedAt = Date.now();
  let call: { result: StructuredCompletionResult; providerId: string; model: string };
  let postprocessed: ReturnType<typeof postprocessJudge>;
  try {
    call = await deps.structuredCompletion(systemPrompt, "Return the assessment now.", {
      name: "assessment",
      schema: buildJudgeSchema(problem),
    });
    postprocessed = postprocessJudge(call.result.json, problem);
  } catch (err) {
    // Nothing assessable came back. Hand the session's one assessment back
    // before surfacing the error, or the retry we are about to advise is a
    // guaranteed SESSION_ALREADY_JUDGED.
    await releaseJudgeClaim(deps.db, key, judgedAt);
    throw err instanceof AppError ? err : new AppError("UNCLEAR_RETRY");
  }
  const latencyMs = Date.now() - startedAt;

  const { assessment, verdictOverridden, from, to } = postprocessed;

  await writeUsage(deps.db, {
    installId: deps.installId,
    date: deps.date,
    endpoint: deps.usageEndpoint,
    problemId: deps.problemId,
    turnIndex: 0,
    model: call.model,
    provider: call.providerId,
    inputTokens: call.result.usage.inputTokens,
    outputTokens: call.result.usage.outputTokens,
    latencyMs,
    verdictOverridden,
  });

  if (verdictOverridden) {
    await writeEvent(deps.db, {
      installId: deps.installId,
      name: "assessment_verdict_overridden",
      props: { from: from ?? "unclear", to: to ?? "unclear", problem_id: deps.problemId },
      clientTs: nowIso(),
    });
  }

  return assessment;
}
