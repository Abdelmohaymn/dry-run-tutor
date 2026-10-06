// The practice branch of routes/trial.ts: the onboarding walkthrough's
// conversational turn — runConversationalTurn, groqProvider, the trial pool
// via runLeg, the leak filter. The caller reserves/releases the turn on its
// own side (devices.trial_*) and passes that in as `reserve`/`release`; this
// function has no opinion on either.
import type { Context } from "hono";
import { AppError } from "./errors";
import type { ChatRequest } from "./schemas";
import type { RuntimeConfig } from "./runtime-config";
import { runConversationalTurn } from "./chat-core";
import { runLeg, selectMember, settleTrialBudget } from "./trial-pool";
import { groqProvider } from "./provider-groq";
import type { Problem } from "../../../tools/problem-types";

export interface PracticeTurnOptions {
  c: Context;
  body: ChatRequest;
  db: D1Database;
  /** installId for the device_day counters. */
  installId: string;
  problemId: string;
  date: string;
  cfg: RuntimeConfig;
  turnCap: number;
  now: Date;
  secretFor: (bindingName: string) => string;
  problem: Problem;
  /** Called once, immediately before the provider call. Optional — the site reserves on its own side before calling this. */
  reserve?: () => Promise<void>;
  /** Called when the provider never answers, so the caller can refund whatever it reserved. */
  release?: () => Promise<void>;
}

export async function runPracticeTurn(opts: PracticeTurnOptions): Promise<Response> {
  return runConversationalTurn(
    opts.c,
    opts.body,
    {
      db: opts.db,
      installId: opts.installId,
      problemId: opts.problemId,
      date: opts.date,
      cfg: opts.cfg,
      provider: groqProvider,
      turnCap: opts.turnCap,
      groundTruthTier: opts.cfg.trial.ground_truth_tier,
      condenseEnabled: false,
      streamChat: async (systemPrompt, messages) => {
        const { member, result } = await runLeg(
          "chat",
          opts.cfg,
          opts.db,
          opts.now,
          (o) => groqProvider.streamChat({ ...o, systemPrompt, messages }),
          opts.secretFor,
        );
        const wrappedUsage = async () => {
          const usage = await result.usage();
          await settleTrialBudget(opts.db, opts.now, member.id, "chat", usage.inputTokens + usage.outputTokens);
          return usage;
        };
        return { stream: { deltas: result.deltas, usage: wrappedUsage }, providerId: member.id, model: member.model };
      },
      condenseCallOptions: async () => {
        const m = await selectMember("chat", opts.cfg, opts.db, opts.now);
        if (!m) throw new AppError("TRIAL_UNAVAILABLE");
        return { baseUrl: m.base_url, apiKey: opts.secretFor(m.secret_binding), model: m.model };
      },
      onBeforeProviderCall: opts.reserve,
      onProviderCallUnanswered: opts.release,
    },
    opts.problem,
  );
}
