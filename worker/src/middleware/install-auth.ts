// Verifies the X-Install-Id header on every route that needs a session
// identity: /v1/chat, /v1/judge, /v1/repair, /v1/trial, /v1/daily. A missing or bad
// signature is rejected with BAD_REQUEST before any handler logic runs.
import type { MiddlewareHandler } from "hono";
import type { Env, Variables } from "../types";
import { verifyInstallId } from "../lib/install-id";
import { AppError, toResponse } from "../lib/errors";

export const installAuth: MiddlewareHandler<{ Bindings: Env; Variables: Variables }> = async (
  c,
  next,
) => {
  const header = c.req.header("X-Install-Id");
  if (!header) {
    return toResponse(new AppError("BAD_REQUEST"));
  }

  const installId = await verifyInstallId(header, c.env.INSTALL_HMAC_SECRET);
  if (!installId) {
    return toResponse(new AppError("BAD_REQUEST"));
  }

  c.set("installId", installId);
  await next();
};
