import { Hono } from "hono";
import { env } from "cloudflare:test";
import { beforeEach, describe, expect, it } from "vitest";
import { webCors } from "../../src/middleware/web-cors";
import type { Env, Variables } from "../../src/types";

async function setAllowedOrigins(origins: string[]): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  cfg.web = { allowed_origins: origins };
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

function testApp() {
  const app = new Hono<{ Bindings: Env; Variables: Variables }>();
  app.use("*", webCors);
  app.all("*", (c) => c.body("ok", 200));
  return app;
}

beforeEach(async () => {
  await setAllowedOrigins(["https://site.test"]);
});

describe("webCors", () => {
  it("sets the header for an allowed origin", async () => {
    const res = await testApp().request(
      "https://worker.test/x",
      { headers: { Origin: "https://site.test" } },
      env,
    );
    expect(res.status).toBe(200);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("https://site.test");
    expect(res.headers.get("Vary")).toBe("Origin");
  });

  it("403s an unknown origin", async () => {
    const res = await testApp().request(
      "https://worker.test/x",
      { headers: { Origin: "https://evil.test" } },
      env,
    );
    expect(res.status).toBe(403);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBeNull();
  });

  it("403s a missing Origin", async () => {
    const res = await testApp().request("https://worker.test/x", {}, env);
    expect(res.status).toBe(403);
  });

  it("204s an OPTIONS preflight with the CORS headers", async () => {
    const res = await testApp().request(
      "https://worker.test/x",
      { method: "OPTIONS", headers: { Origin: "https://site.test" } },
      env,
    );
    expect(res.status).toBe(204);
    expect(res.headers.get("Access-Control-Allow-Origin")).toBe("https://site.test");
    expect(res.headers.get("Access-Control-Allow-Methods")).toBe("POST, OPTIONS");
    expect(res.headers.get("Access-Control-Allow-Headers")).toBe("content-type");
    expect(res.headers.get("Access-Control-Max-Age")).toBe("600");
  });
});
