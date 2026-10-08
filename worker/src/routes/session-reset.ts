// POST /v1/session/reset — retire today's local session so it can be
// replayed without granting an additional trial session.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { sessionResetRequestSchema } from "../lib/schemas";
import { utcDate } from "../lib/time";
import { resetTrialSession } from "../lib/trial-pool";

export const sessionResetRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

sessionResetRoute.post("/", async (c) => {
  const rawBody = await c.req.json().catch(() => null);
  const parsed = sessionResetRequestSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");

  const deviceHash = c.get("installId");
  const date = utcDate();
  const problemId = parsed.data.problem_id;
  await c.env.DB
    .prepare("DELETE FROM device_day WHERE device_hash = ?1 AND date = ?2 AND problem_id = ?3")
    .bind(deviceHash, date, problemId)
    .run();
  await resetTrialSession(c.env.DB, deviceHash, problemId, date);

  return c.json({ ok: true }, 200);
});
