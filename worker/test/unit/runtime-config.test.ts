import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig, runtimeConfigSchema } from "../../src/lib/runtime-config";

describe("getRuntimeConfig()", () => {
  it("parses the seeded row", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    expect(cfg.chat.turn_cap).toBe(15);
    expect(cfg.trial.pool[0].id).toBe("groq");
  });

  it("rejects an invalid payload rather than serving it", () => {
    const invalid = { min_supported_version: "not-a-version" };
    expect(() => runtimeConfigSchema.parse(invalid)).toThrow();
  });

  it("rejects a payload with an unknown top-level key (additionalProperties: false)", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const withExtra = { ...cfg, unexpected_lever: true };
    expect(() => runtimeConfigSchema.parse(withExtra)).toThrow();
  });

  it("accepts an https update_url and rejects any other scheme", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    expect(() =>
      runtimeConfigSchema.parse({ ...cfg, update_url: "https://dry-run.en.uptodown.com/android" }),
    ).not.toThrow();
    expect(() => runtimeConfigSchema.parse({ ...cfg, update_url: "http://example.com/" })).toThrow();
    expect(() => runtimeConfigSchema.parse({ ...cfg, update_url: "intent://x#Intent;end" })).toThrow();
  });

  it("all seven levers are reachable on the parsed config", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    expect(cfg.killed_problem_ids).toBeDefined();
    expect(cfg.chat.turn_cap).toBeDefined();
    expect(cfg.chat.wrap_up_at_turn).toBeDefined();
    expect(cfg.chat.min_turn_chars).toBeDefined();
    expect(cfg.model).toBeDefined();
    expect(cfg.provider).toBeDefined();
    expect(cfg.trim.verbatim_turns).toBeDefined();
    expect(cfg.trim.narrow_after_turn).toBeDefined();
    expect(cfg.trim.narrow_margin).toBeDefined();
    expect(cfg.trim.condense_model).toBeDefined();
    expect(cfg.trial.turn_cap).toBeDefined();
    expect(cfg.trial.ground_truth_tier).toBeDefined();
    expect(cfg.trial.condense).toBeDefined();
    expect(cfg.trial.pool).toBeDefined();
  });
});
