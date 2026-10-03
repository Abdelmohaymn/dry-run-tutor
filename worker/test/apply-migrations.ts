// Runs once per test file inside the Workers runtime, before any test.
// Applies worker/migrations/*.sql (including the runtime_config seed row) to
// the isolated-storage D1 instance so every unit and contract test starts
// from the same schema `wrangler d1 migrations apply --local` would produce.
import { applyD1Migrations, env } from "cloudflare:test";
import type { D1Migration } from "@cloudflare/vitest-pool-workers/config";

declare module "cloudflare:test" {
  interface ProvidedEnv {
    DB: D1Database;
    TEST_MIGRATIONS: D1Migration[];
    EXPECTED_PROMPTS: { tutor: string; judge: string; condense: string; repair: string };
    /** worker/src/**\/*.ts, path -> content, injected at config-build time (T095). */
    WORKER_SOURCE: Record<string, string>;
    TRIAL_KEY_GROQ: string;
    TRIAL_KEY_TEST2?: string;
    /** harness project only — a real learner key, injected from process.env.GROQ_API_KEY at config-build time. */
    GROQ_API_KEY?: string;
    /** harness project only — optional provider/model override for a harness run, see live-client.ts applyProviderOverride(). */
    HARNESS_PROVIDER?: string;
    HARNESS_MODEL?: string;
    // Feature 007, web-only routes.
    WEB_EVENT_RL: RateLimit;
    TURNSTILE_SECRET: string;
  }
}

await applyD1Migrations(env.DB, env.TEST_MIGRATIONS);
