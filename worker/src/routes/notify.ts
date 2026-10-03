// POST /v1/notify — contracts/web-api.openapi.yaml. The landing site's
// "tell me when it's on my store" form (feature 007). A new signup and a
// duplicate get the same 202, so the form can't be used to check whether an
// address is signed up (FR-024). Stores the email, the store and a time:
// no IP, no user agent.
import { Hono } from "hono";
import { z } from "zod";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { getRuntimeConfig, webConfig } from "../lib/runtime-config";
import { verifyTurnstile } from "../lib/turnstile";
import { nowIso } from "../lib/time";

const notifyBodySchema = z
  .object({
    email: z.string().max(254),
    store: z.enum(["play", "app_store"]),
    turnstile_token: z.string().max(2048),
  })
  .strict();

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const notifyRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

notifyRoute.post("/", async (c) => {
  const cfg = await getRuntimeConfig(c.env.DB);
  if (!webConfig(cfg).notify_enabled) return c.body(null, 503);

  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  const limited = await c.env.WEB_EVENT_RL.limit({ key: ip });
  if (!limited.success) throw new AppError("RATE_LIMITED");

  const rawBody = await c.req.json().catch(() => null);
  const parsed = notifyBodySchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");

  const ok = await verifyTurnstile(c.env.TURNSTILE_SECRET, parsed.data.turnstile_token, "notify", ip);
  if (!ok) return c.body(null, 403);

  const email = parsed.data.email.trim().toLowerCase();
  if (email.length > 254 || !EMAIL_PATTERN.test(email)) throw new AppError("INVALID_EMAIL");

  await c.env.DB.prepare("INSERT OR IGNORE INTO notify_signup (email, store, created_at) VALUES (?1, ?2, ?3)")
    .bind(email, parsed.data.store, nowIso())
    .run();

  return c.json({ ok: true }, 202);
});
