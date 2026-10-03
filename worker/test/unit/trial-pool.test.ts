import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig, type RuntimeConfig } from "../../src/lib/runtime-config";
import { selectMember, type TrialPoolMember } from "../../src/lib/trial-pool";

let counter = 0;
function freshId(prefix: string): string {
  counter += 1;
  return `${prefix}-${counter}-${Date.now()}`;
}

function member(overrides: Partial<TrialPoolMember>): TrialPoolMember {
  return {
    id: freshId("member"),
    secret_binding: "TRIAL_KEY_GROQ",
    base_url: "https://api.groq.com/openai/v1",
    model: "openai/gpt-oss-120b",
    daily_token_budget: 100000,
    structured_output: false,
    enabled: true,
    cooldown_ms: 60000,
    ...overrides,
  };
}

async function cfgWithPool(pool: TrialPoolMember[]): Promise<RuntimeConfig> {
  const base = await getRuntimeConfig(env.DB);
  return { ...base, trial: { ...base.trial, pool } };
}

// data-model.md §B8, T091a.
describe("selectMember()", () => {
  it("a judge leg on an all-structured_output:false pool returns NULL rather than falling back", async () => {
    const cfg = await cfgWithPool([
      member({ structured_output: false }),
      member({ structured_output: false }),
    ]);
    const result = await selectMember("judge", cfg, env.DB, new Date());
    expect(result).toBeNull();
  });

  it("a judge leg only ever selects a structured_output:true member", async () => {
    const structured = member({ structured_output: true });
    const cfg = await cfgWithPool([member({ structured_output: false }), structured]);
    const result = await selectMember("judge", cfg, env.DB, new Date());
    expect(result?.id).toBe(structured.id);
  });

  it("a chat leg partitions non-structured members before structured ones, preserving pool array order within each group", async () => {
    const a = member({ structured_output: true });
    const b = member({ structured_output: false });
    const c = member({ structured_output: false });
    const cfg = await cfgWithPool([a, b, c]);
    // b and c (non-structured) come first, in pool order; a (structured) last.
    // b is first-fit since neither b nor c has budget/cooldown state yet.
    const result = await selectMember("chat", cfg, env.DB, new Date());
    expect(result?.id).toBe(b.id);
  });

  it("skips a member over its daily_token_budget", async () => {
    const over = member({ daily_token_budget: 100 });
    const under = member({ daily_token_budget: 100000 });
    const date = new Date().toISOString().slice(0, 10);
    await env.DB.prepare(
      "INSERT INTO trial_budget (date, provider_id, tokens_spent) VALUES (?1, ?2, ?3)",
    )
      .bind(date, over.id, 500)
      .run();

    const cfg = await cfgWithPool([over, under]);
    const result = await selectMember("chat", cfg, env.DB, new Date());
    expect(result?.id).toBe(under.id);
  });

  it("skips a member on cooldown", async () => {
    const cooling = member({});
    const available = member({});
    const date = new Date().toISOString().slice(0, 10);
    const future = new Date(Date.now() + 60_000).toISOString();
    await env.DB.prepare(
      "INSERT INTO trial_budget (date, provider_id, tokens_spent, cooldown_until) VALUES (?1, ?2, 0, ?3)",
    )
      .bind(date, cooling.id, future)
      .run();

    const cfg = await cfgWithPool([cooling, available]);
    const result = await selectMember("chat", cfg, env.DB, new Date());
    expect(result?.id).toBe(available.id);
  });

  it("skips a disabled member entirely", async () => {
    const disabled = member({ enabled: false });
    const cfg = await cfgWithPool([disabled]);
    const result = await selectMember("chat", cfg, env.DB, new Date());
    expect(result).toBeNull();
  });
});
