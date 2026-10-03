// POST /v1/event — contracts/openapi.yaml, contracts/event.schema.json.
// Batched anonymous analytics. No PII, no message content, ever (FR-034).
// A batch containing a disallowed key or a nested value is REJECTED, not
// silently trimmed — a silent trim is how message content ends up in an
// analytics table.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { eventBatchSchema } from "../lib/schemas";
import { writeEvent } from "../lib/events";

export const eventRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

eventRoute.post("/", async (c) => {
  const installId = c.get("installId");

  const rawBody = await c.req.json().catch(() => null);
  const parsed = eventBatchSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");

  for (const event of parsed.data.events) {
    await writeEvent(c.env.DB, {
      installId,
      name: event.name,
      props: event.props ?? {},
      clientTs: event.client_ts,
    });
  }

  return c.body(null, 202);
});
