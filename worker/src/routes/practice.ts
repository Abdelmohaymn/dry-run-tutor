// GET /v1/practice — contracts/worker-api.md. The onboarding warm-up's public
// half, served without an install token so the app can show it before it has
// registered. Same for every caller, so it is cacheable.
import { Hono } from "hono";
import type { Env } from "../types";
import { AppError } from "../lib/errors";
import { PRACTICE_COLLECTION, getPublicManifest } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";

export const practiceRoute = new Hono<{ Bindings: Env }>();

practiceRoute.get("/", async (c) => {
  const cfg = await getRuntimeConfig(c.env.DB);
  const problem = getPublicManifest()
    .problems.filter((p) => (p.collections ?? []).includes(PRACTICE_COLLECTION) && !cfg.killed_problem_ids.includes(p.id))
    .sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0))[0];
  if (!problem) throw new AppError("PROBLEM_KILLED");
  return c.json({ problem }, 200, { "cache-control": "public, max-age=3600" });
});
