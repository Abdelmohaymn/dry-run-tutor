// POST /v1/install — contracts/openapi.yaml. Mints a signed anonymous
// install identity. No accounts, no PII (FR-036).
import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../types";
import { AppError, toResponse } from "../lib/errors";
import { signInstallId } from "../lib/install-id";

const installRequestSchema = z
  .object({ install_uuid: z.string().uuid() })
  .strict();

export const installRoute = new Hono<{ Bindings: Env }>();

installRoute.post("/", async (c) => {
  // Each install id is a fresh claim on the trial, so minting them in bulk
  // is the first step of draining the pool. A real install calls this once.
  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  const { success } = await c.env.INSTALL_RL.limit({ key: ip });
  if (!success) {
    return toResponse(new AppError("RATE_LIMITED"));
  }

  const raw = await c.req.json().catch(() => null);
  const parsed = installRequestSchema.safeParse(raw);
  if (!parsed.success) {
    return toResponse(new AppError("BAD_REQUEST"));
  }

  const installId = await signInstallId(parsed.data.install_uuid, c.env.INSTALL_HMAC_SECRET);
  return c.json({ install_id: installId });
});
