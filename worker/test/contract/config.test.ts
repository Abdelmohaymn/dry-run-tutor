import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { runtimeConfigSchema } from "../../src/lib/runtime-config";

// US6 scenario 1, SC-012.
describe("GET /v1/config", () => {
  it("the seeded payload validates against contracts/config.schema.json (via the zod transcription)", async () => {
    const res = await SELF.fetch("https://worker.test/v1/config");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toContain("max-age=300");
    expect(res.headers.get("etag")).toBeTruthy();
    const body = await res.json();
    expect(() => runtimeConfigSchema.parse(body)).not.toThrow();
  });

  it("never sends the web lever block (feature 007 — the app has no use for it)", async () => {
    const res = await SELF.fetch("https://worker.test/v1/config");
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.web).toBeUndefined();
  });
});
