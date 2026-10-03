// GET /v1/content/manifest.json — contracts/openapi.yaml. Serves the
// built public manifest verbatim: schema_version, generated, problems, and
// nothing else (FR-030). No private field is reachable from this route —
// build-content.ts's assertNoPrivateLeak() is what guarantees that.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { getPublicManifest } from "../lib/content";

export const manifestRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

manifestRoute.get("/", (c) => {
  return c.json(getPublicManifest());
});
