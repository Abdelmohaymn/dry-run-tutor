import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig } from "../../src/lib/runtime-config";

// FR-025, US5 scenario 3, Constitution VI. worker/src/**/*.ts is injected
// as the WORKER_SOURCE binding at vitest config build time — the Workers
// test runtime has no host filesystem access (see vitest.config.ts, same
// pattern as EXPECTED_PROMPTS for prompts-verbatim.test.ts).
describe("operator credentials never appear in source", () => {
  it("no pool member's secret VALUE (the test placeholder standing in for a real credential) appears anywhere in worker/src/**", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    const concatenated = Object.values(source).join("\n");

    const candidateSecrets = [env.TRIAL_KEY_GROQ, env.TRIAL_KEY_TEST2, env.STT_KEY_GROQ].filter(
      (v): v is string => typeof v === "string" && v.length > 0,
    );
    expect(candidateSecrets.length).toBeGreaterThan(0);
    for (const secret of candidateSecrets) {
      expect(concatenated).not.toContain(secret);
    }
  });

  it("every pool member's config carries a BINDING NAME, never a literal key-shaped value", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    for (const member of cfg.trial.pool) {
      expect(member.secret_binding).toMatch(/^[A-Z][A-Z0-9_]{0,31}$/);
      expect(member.secret_binding).not.toMatch(/^gsk_|^sk-/);
    }
  });

  it("no source file reads a pool credential from anywhere but the runtime secret binding named by secret_binding", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    // The only two files with any business reading Env's key-shaped
    // bindings are trial.ts (dynamic lookup by secret_binding name) and
    // provider-groq.ts (never touches Env at all — it takes apiKey as an
    // argument). Nothing else may reference an Env property that looks
    // like a credential binding.
    for (const [path, content] of Object.entries(source)) {
      if (path === "routes/trial.ts") continue;
      expect(content).not.toMatch(/env\.TRIAL_KEY_\w+/);
      expect(content).not.toMatch(/c\.env\.TRIAL_KEY_\w+/);
    }
  });

  it("env.STT_KEY_GROQ is referenced only in routes/stt.ts", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    expect(source["routes/stt.ts"]).toMatch(/env\.STT_KEY_GROQ/);
    for (const [path, content] of Object.entries(source)) {
      if (path === "routes/stt.ts") continue;
      expect(content, path).not.toMatch(/env\.STT_KEY_GROQ/);
    }
  });
});
