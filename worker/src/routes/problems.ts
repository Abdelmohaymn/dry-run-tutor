// GET /v1/problems — the public, selectable evergreen catalogue.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { getPublicManifest, isPracticeProblem } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";

export const problemsRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

problemsRoute.get("/", async (c) => {
  const cfg = await getRuntimeConfig(c.env.DB);
  const problems = getPublicManifest().problems
    .filter((problem) => !isPracticeProblem(problem.id))
    .filter((problem) => !cfg.killed_problem_ids.includes(problem.id))
    .map(({ id, title, difficulty, tags }) => ({ id, title, difficulty, tags }));

  return c.json({ problems }, 200, { "cache-control": "private, no-store" });
});
