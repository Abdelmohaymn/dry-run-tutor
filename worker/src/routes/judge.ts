// POST /v1/judge — contracts/openapi.yaml. One structured assessment per
// session, on the learner's own key. The assessment logic itself lives in
// judge-core.ts, shared with the trial path (routes/trial.ts, T092).
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { judgeRequestSchema } from "../lib/schemas";
import { getPrivate, getPublicManifest } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";
import { runJudge } from "../lib/judge-core";
import { PROVIDER_HEADER, resolveKeyedProvider } from "../lib/keyed-provider";
import { groqProvider } from "../lib/provider-groq";
import { utcDate } from "../lib/time";
import type { Problem } from "../../../tools/problem-types";

export const judgeRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

judgeRoute.post("/", async (c) => {
  const installId = c.get("installId");
  const userKey = c.req.header("X-User-Key");
  if (!userKey) throw new AppError("BAD_REQUEST");

  const rawBody = await c.req.json().catch(() => null);
  const parsed = judgeRequestSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");
  const body = parsed.data;

  // FR-021: solution-ended sessions are required to name where the reveal happened.
  if (body.ended_by === "solution" && body.reveal_at_index === undefined) {
    throw new AppError("BAD_REQUEST");
  }

  const publicEntry = getPublicManifest().problems.find((p) => p.id === body.problem_id);
  const privateHalf = getPrivate(body.problem_id);
  if (!publicEntry || !privateHalf) throw new AppError("BAD_REQUEST");
  const problem: Problem = { public: publicEntry, private: privateHalf };

  const cfg = await getRuntimeConfig(c.env.DB);
  const date = utcDate();
  const keyed = resolveKeyedProvider(cfg, c.req.header(PROVIDER_HEADER));

  if (cfg.killed_problem_ids.includes(body.problem_id)) {
    throw new AppError("PROBLEM_KILLED");
  }

  const assessment = await runJudge(
    {
      db: c.env.DB,
      installId,
      problemId: body.problem_id,
      date,
      usageEndpoint: "judge",
      structuredCompletion: async (systemPrompt, userContent, jsonSchema) => ({
        result: await groqProvider.structuredCompletion({
          baseUrl: keyed.baseUrl,
          model: keyed.model,
          apiKey: userKey,
          structuredExtraBody: keyed.structuredExtraBody,
          systemPrompt,
          userContent,
          maxTokens: 2000,
          temperature: 0,
          jsonSchema,
        }),
        providerId: keyed.id,
        model: keyed.model,
      }),
    },
    body,
    problem,
  );

  return c.json(assessment, 200);
});
