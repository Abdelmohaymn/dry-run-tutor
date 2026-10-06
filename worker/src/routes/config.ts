// GET /v1/config — contracts/openapi.yaml. The only remote-control
// surface. Gates app launch, so the payload stays small (FR-033).
//
// CLIENT FAIL-OPEN OBLIGATION (research.md R-010, Constitution X.3): if
// this endpoint is unreachable, the app MUST fall back to its last cached
// response rather than blocking launch. Config must never be able to lock
// a learner out — see worker/README.md for the client-side contract this
// implies (T099).
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { getRuntimeConfig } from "../lib/runtime-config";

export const configRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

configRoute.get("/", async (c) => {
  const cfg = await getRuntimeConfig(c.env.DB);
  // `web` (feature 007) is the landing site's own levers; `rotation` is read
  // by GET /v1/daily (006). The app has no use for either, so neither leaves
  // the Worker in this payload.
  const { web: _web, rotation: _rotation, ...appCfg } = cfg;
  const body = JSON.stringify(appCfg);
  // A stable ETag over the served bytes, not a per-request random value —
  // it changes only when the lever payload itself changes.
  const etag = `"${await sha256Hex(body)}"`;
  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "application/json",
      "cache-control": "public, max-age=300",
      etag,
    },
  });
});

async function sha256Hex(input: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(input));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}
