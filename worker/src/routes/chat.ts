// POST /v1/chat — contracts/openapi.yaml. One tutor turn, streamed, on the
// learner's own key. The solution is withheld by code (leak-filter.ts,
// turn-cap.ts), not requested in a prompt (Constitution III). The turn
// logic itself lives in chat-core.ts, shared with the trial path
// (routes/trial.ts, T092).
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { chatRequestSchema } from "../lib/schemas";
import { getPrivate, getPublicManifest } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";
import { runConversationalTurn, runHintTurn, runKeyCheck } from "../lib/chat-core";
import { PROVIDER_HEADER, resolveKeyedProvider } from "../lib/keyed-provider";
import { groqProvider } from "../lib/provider-groq";
import { utcDate } from "../lib/time";
import { FINISH_CHECK_MAX_TOKENS } from "../lib/finish-check";
import type { ProviderMessage } from "../lib/provider";
import type { Problem } from "../../../tools/problem-types";

export const chatRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

chatRoute.post("/", async (c) => {
  const installId = c.get("installId");
  const userKey = c.req.header("X-User-Key");
  if (!userKey) throw new AppError("BAD_REQUEST");

  const rawBody = await c.req.json().catch(() => null);
  const parsed = chatRequestSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");
  const body = parsed.data;

  const publicEntry = getPublicManifest().problems.find((p) => p.id === body.problem_id);
  const privateHalf = getPrivate(body.problem_id);
  if (!publicEntry || !privateHalf) throw new AppError("BAD_REQUEST");
  const problem: Problem = { public: publicEntry, private: privateHalf };

  const cfg = await getRuntimeConfig(c.env.DB);
  const date = utcDate();
  const keyed = resolveKeyedProvider(cfg, c.req.header(PROVIDER_HEADER));

  // PROBLEM_KILLED applies to both the hint path and the conversational
  // path, and must be checked before either (FR-040).
  if (cfg.killed_problem_ids.includes(body.problem_id)) {
    throw new AppError("PROBLEM_KILLED");
  }

  const commonDeps = {
    db: c.env.DB,
    installId,
    problemId: body.problem_id,
    date,
    cfg,
    turnCap: cfg.chat.turn_cap,
    usageEndpoint: "chat" as const,
  };

  const streamChat = async (systemPrompt: string, messages: ProviderMessage[]) => ({
    stream: await groqProvider.streamChat({
      baseUrl: keyed.baseUrl,
      model: keyed.model,
      apiKey: userKey,
      systemPrompt,
      messages,
    }),
    providerId: keyed.id,
    model: keyed.model,
  });

  // ---- Key check on save: no turn, no tutor prompt. ----
  if (body.key_check) {
    return runKeyCheck(c, commonDeps, problem, streamChat);
  }

  // ---- Hint branch (T046a): returns before reserveTurn() and before any
  // provider call, so a rung costs zero tokens and zero turns. ----
  if (body.hint_requested) {
    return runHintTurn(c, body, commonDeps, problem);
  }

  // ---- Pre-provider guards (T048): both before reserveTurn(), so neither
  // costs the learner anything. ----
  const lastMessage = body.messages[body.messages.length - 1];
  const nonWhitespaceChars = lastMessage.text.replace(/\s+/g, "").length;
  if (nonWhitespaceChars < cfg.chat.min_turn_chars) {
    throw new AppError("EMPTY_TURN");
  }

  return runConversationalTurn(
    c,
    body,
    {
      ...commonDeps,
      provider: groqProvider,
      groundTruthTier: "AB",
      condenseEnabled: true,
      condenseUsageEndpoint: "condense",
      streamChat,
      condenseCallOptions: () => ({ baseUrl: keyed.baseUrl, apiKey: userKey, model: keyed.condenseModel }),
      finishCheck: async (systemPrompt, userContent, jsonSchema) => ({
        result: await groqProvider.structuredCompletion({
          baseUrl: keyed.baseUrl,
          model: keyed.model,
          apiKey: userKey,
          systemPrompt,
          userContent,
          maxTokens: FINISH_CHECK_MAX_TOKENS,
          temperature: 0,
          jsonSchema,
        }),
        providerId: keyed.id,
        model: keyed.model,
      }),
      finishCheckUsageEndpoint: "finish_check",
    },
    problem,
  );
});
