// Worker bindings. Secrets are never given a literal default — they exist
// only as `wrangler secret put` values (dev) or CI/dashboard secrets (prod).
export interface Env {
  DB: D1Database;
  INSTALL_HMAC_SECRET: string;
  // One binding per trial pool member, named by that member's
  // `secret_binding` in contracts/config.schema.json. TRIAL_KEY_GROQ is the
  // only one enabled by default (data-model.md §A5, §B8).
  TRIAL_KEY_GROQ: string;
  // Test-only second pool-member binding (worker/.dev.vars) — exercised by
  // trial-pool.test.ts / trial.test.ts, not part of the shipped default pool.
  TRIAL_KEY_TEST2?: string;
  ENVIRONMENT?: string;
  // POST /v1/install, per IP.
  INSTALL_RL: RateLimit;
  // Feature 007, web-only routes.
  WEB_EVENT_RL: RateLimit;
  TURNSTILE_SECRET: string;
}

// Set by middleware/install-auth.ts once the X-Install-Id header verifies.
// This is the 64-hex device hash — the part of the signed header that
// identifies the phone — never the signature. The name predates 006
// (research.md R-3).
export interface Variables {
  installId: string;
}
