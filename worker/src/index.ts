// Hono app: route registration and a global error handler only. No logic
// of its own (plan.md §Source Code). Routes are added here as each one is
// implemented; this file's job never grows beyond wiring.
import { Hono } from "hono";
import type { Env, Variables } from "./types";
import { AppError, toResponse } from "./lib/errors";
import { redact } from "./lib/redact";
import { installRoute } from "./routes/install";
import { chatRoute } from "./routes/chat";
import { judgeRoute } from "./routes/judge";
import { repairRoute } from "./routes/repair";
import { manifestRoute } from "./routes/manifest";
import { trialRoute } from "./routes/trial";
import { configRoute } from "./routes/config";
import { eventRoute } from "./routes/event";
import { privacyRoute } from "./routes/privacy";
import { webEventRoute } from "./routes/web-event";
import { notifyRoute } from "./routes/notify";
import { installAuth } from "./middleware/install-auth";
import { webCors } from "./middleware/web-cors";

const app = new Hono<{ Bindings: Env; Variables: Variables }>();

app.route("/v1/install", installRoute);
app.use("/v1/chat", installAuth);
app.route("/v1/chat", chatRoute);
app.use("/v1/judge", installAuth);
app.route("/v1/judge", judgeRoute);
app.use("/v1/repair", installAuth);
app.route("/v1/repair", repairRoute);
app.use("/v1/trial", installAuth);
app.route("/v1/trial", trialRoute);
app.route("/v1/content/manifest.json", manifestRoute);
app.route("/v1/config", configRoute);
app.use("/v1/event", installAuth);
app.route("/v1/event", eventRoute);
// Website only: CORS-guarded, no install auth (feature 007).
app.use("/v1/web-event", webCors);
app.route("/v1/web-event", webEventRoute);
app.use("/v1/notify", webCors);
app.route("/v1/notify", notifyRoute);
// Public, unauthenticated, and deliberately outside /v1: this is a page for
// people and store reviewers, not an API surface.
app.route("/privacy", privacyRoute);

app.onError((err, c) => {
  if (err instanceof AppError) {
    return toResponse(err);
  }
  console.error("unhandled error", redact({ message: err.message, stack: err.stack }));
  return toResponse(new AppError("UNCLEAR_RETRY"));
});

export default app;
