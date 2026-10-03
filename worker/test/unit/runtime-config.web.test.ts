import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig, webConfig } from "../../src/lib/runtime-config";

describe("webConfig()", () => {
  it("parses the seeded row, which has no web key", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    expect(cfg.web).toBeUndefined();
  });

  it("returns the defaults when web is absent", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const web = webConfig(cfg);
    expect(web.allowed_origins).toEqual([]);
    expect(web.notify_enabled).toBe(true);
  });
});
