// CORS guard for the site-only routes (feature 007): /v1/notify,
// /v1/web-event. These have no install auth — the browser has
// no install ID — so an exact-match origin allowlist is the only gate before
// Turnstile and the rate limits. Never `*`, and never an echoed origin that
// isn't in the list.
import type { MiddlewareHandler } from "hono";
import type { Env, Variables } from "../types";
import { getRuntimeConfig, webConfig } from "../lib/runtime-config";

export const webCors: MiddlewareHandler<{ Bindings: Env; Variables: Variables }> = async (
  c,
  next,
) => {
  const origin = c.req.header("Origin");
  const cfg = await getRuntimeConfig(c.env.DB);
  const allowedOrigins = webConfig(cfg).allowed_origins;

  if (!origin || !allowedOrigins.includes(origin)) {
    return c.body(null, 403);
  }

  if (c.req.method === "OPTIONS") {
    return c.body(null, 204, {
      "Access-Control-Allow-Origin": origin,
      Vary: "Origin",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "content-type",
      "Access-Control-Max-Age": "600",
    });
  }

  await next();
  c.res.headers.set("Access-Control-Allow-Origin", origin);
  c.res.headers.set("Vary", "Origin");
};
