// POST /v1/install — contracts/openapi.yaml. Mints a signed anonymous
// identity for a phone: the same Android ID always yields the same identity,
// so a reinstall keeps its spent taster (specs/006-lean-backend). No accounts,
// no PII (FR-036). The raw device id is hashed here and never stored or logged.
import { Hono } from "hono";
import { z } from "zod";
import type { Env } from "../types";
import { AppError, toResponse } from "../lib/errors";
import { signInstallId } from "../lib/install-id";
import { networkKey } from "../lib/network-key";
import { nowIso } from "../lib/time";

const installRequestSchema = z
  .object({
    platform: z.literal("android"),
    device_id: z.string().trim().toLowerCase().min(1).max(128),
  })
  .strict();

async function hashDeviceId(deviceId: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`android:${deviceId}`));
  return [...new Uint8Array(mac)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export const installRoute = new Hono<{ Bindings: Env }>();

installRoute.post("/", async (c) => {
  // Forging device ids in bulk is the first step of draining the pool. A real
  // install calls this once. Keyed per network (IPv6 by /64).
  const ip = c.req.header("CF-Connecting-IP") ?? "unknown";
  const { success } = await c.env.INSTALL_RL.limit({ key: networkKey(ip) });
  if (!success) {
    return toResponse(new AppError("RATE_LIMITED"));
  }

  const raw = await c.req.json().catch(() => null);
  const parsed = installRequestSchema.safeParse(raw);
  if (!parsed.success) {
    return toResponse(new AppError("BAD_REQUEST"));
  }

  const deviceHash = await hashDeviceId(parsed.data.device_id, c.env.INSTALL_HMAC_SECRET);
  // A reinstall hits the existing row and changes nothing.
  await c.env.DB
    .prepare("INSERT OR IGNORE INTO devices (device_hash, created_at) VALUES (?1, ?2)")
    .bind(deviceHash, nowIso())
    .run();

  const installId = await signInstallId(deviceHash, c.env.INSTALL_HMAC_SECRET);
  return c.json({ install_id: installId });
});
