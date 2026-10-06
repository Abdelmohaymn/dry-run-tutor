import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";

// R-001, R-011: the keyed paths never read provider_day and can never
// return TRIAL_UNAVAILABLE — a learner spending their own allowance has
// their own concurrency budget and must never be rationed against the
// operator's.
describe("keyed paths are isolated from the trial budget", () => {
  it("no source file outside trial.ts / trial-pool.ts / practice-turn.ts references the provider_day table or the devices.trial_* columns", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    const trialFiles = new Set(["routes/trial.ts", "lib/trial-pool.ts", "lib/practice-turn.ts"]);
    for (const [path, content] of Object.entries(source)) {
      if (trialFiles.has(path)) continue;
      expect(content).not.toContain("provider_day");
      for (const term of ["trial_started_at", "trial_problem_id", "trial_completed_at", "trial_ip_hash"]) {
        expect(content).not.toContain(term);
      }
    }
  });

  it("TRIAL_UNAVAILABLE is thrown only from trial.ts/trial-pool.ts/practice-turn.ts — errors.ts merely catalogues the code", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    const throwSites = new Set([
      "routes/trial.ts",
      "lib/trial-pool.ts",
      "lib/errors.ts",
      "lib/practice-turn.ts",
    ]);
    for (const [path, content] of Object.entries(source)) {
      if (throwSites.has(path)) continue;
      expect(content).not.toContain("TRIAL_UNAVAILABLE");
    }
  });

  it("routes/chat.ts and routes/judge.ts never reference cfg.trial", () => {
    const source: Record<string, string> = env.WORKER_SOURCE;
    expect(source["routes/chat.ts"]).not.toMatch(/cfg\.trial/);
    expect(source["routes/judge.ts"]).not.toMatch(/cfg\.trial/);
  });
});
