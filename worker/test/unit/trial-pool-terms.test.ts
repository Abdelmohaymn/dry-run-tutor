import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig, type RuntimeConfig } from "../../src/lib/runtime-config";
import type { TrialPoolMember } from "../../src/lib/trial-pool";

function originOf(baseUrl: string): string {
  return new URL(baseUrl).origin;
}

function noDuplicateOrigins(pool: TrialPoolMember[]): boolean {
  const origins = pool.map((m) => originOf(m.base_url));
  return new Set(origins).size === origins.length;
}

// FR-031b: the pool multiplies capacity by adding PROVIDERS, never
// accounts at the same provider — several accounts at one provider is
// rate-limit evasion and provider-terms violation.
describe("cfg.trial.pool — no duplicate provider host", () => {
  it("the seeded pool has no duplicate origin", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    expect(noDuplicateOrigins(cfg.trial.pool)).toBe(true);
  });

  it("two members sharing an origin fail the check", async () => {
    const base = await getRuntimeConfig(env.DB);
    const withDuplicate: RuntimeConfig = {
      ...base,
      trial: {
        ...base.trial,
        pool: [
          ...base.trial.pool,
          { ...base.trial.pool[0], id: "groq_second_account" },
        ],
      },
    };
    expect(noDuplicateOrigins(withDuplicate.trial.pool)).toBe(false);
  });
});
