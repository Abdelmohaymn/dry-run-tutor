// POST /v1/web-event — contracts/web-api.openapi.yaml. The landing site's
// own analytics, written with install_id='web' into the same `events` table
// as the app (feature 007). A SEPARATE closed name list from EVENT_NAMES
// (schemas.ts): the site and the app never share an event vocabulary, so a
// site event can never accidentally validate against an app-only name.
import { Hono } from "hono";
import { z } from "zod";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { writeEvent } from "../lib/events";

const WEB_EVENT_NAMES = [
  "web_page_view",
  "web_download_tapped",
] as const;

const clientTs = z.iso.datetime({ offset: true });

// Each web event's own closed prop shape — no shared generic bag, so a prop
// that doesn't belong to that name is a 400, not a silent accept.
const webEventItemSchema = z.discriminatedUnion("name", [
  z.object({ name: z.literal("web_page_view"), client_ts: clientTs }).strict(),
  z
    .object({
      name: z.literal("web_download_tapped"),
      client_ts: clientTs,
      props: z.object({ store: z.string() }).strict(),
    })
    .strict(),
]);

const webEventBatchSchema = z
  .object({
    events: z.array(webEventItemSchema).min(1).max(100),
  })
  .strict();

export const webEventRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

webEventRoute.post("/", async (c) => {
  const limited = await c.env.WEB_EVENT_RL.limit({
    key: c.req.header("CF-Connecting-IP") ?? "unknown",
  });
  if (!limited.success) throw new AppError("RATE_LIMITED");

  // Read as text first, not c.req.json(): a beacon (navigator.sendBeacon)
  // sends content-type: text/plain, and the body is still valid JSON.
  const rawBody = await c.req
    .text()
    .then((text) => JSON.parse(text))
    .catch(() => null);
  const parsed = webEventBatchSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");

  for (const event of parsed.data.events) {
    await writeEvent(c.env.DB, {
      installId: "web",
      name: event.name,
      props: "props" in event ? event.props : {},
      clientTs: event.client_ts,
    });
  }

  return c.body(null, 202);
});
