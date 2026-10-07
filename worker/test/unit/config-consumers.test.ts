import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";

// data-model.md §A5 — the ONLY authority for what counts as "read". Every
// key whose Read by column names a worker/src/** module must have a
// reader in that module; the two keys whose Read by column names THE APP
// (min_supported_version, content_manifest_url) must instead be served
// verbatim by routes/config.ts and read by no other module — they have no
// worker/src/** reader by design and never will.
const LEVER_CONSUMERS: Record<string, { file: string; needle: string }[]> = {
  "killed_problem_ids": [
    { file: "routes/chat.ts", needle: "killed_problem_ids" },
    { file: "routes/judge.ts", needle: "killed_problem_ids" },
    { file: "routes/trial.ts", needle: "killed_problem_ids" },
  ],
  "chat.turn_cap": [{ file: "routes/chat.ts", needle: "chat.turn_cap" }],
  "chat.wrap_up_at_turn": [{ file: "lib/chat-core.ts", needle: "wrap_up_at_turn" }],
  "chat.min_turn_chars": [{ file: "routes/chat.ts", needle: "min_turn_chars" }],
  // Since per-key routing (FR-008b) both are read by the resolver, not by the
  // routes: the route asks which provider THIS request belongs to, and
  // `model`/`provider` are only the fallback when the app names none.
  "model": [{ file: "lib/keyed-provider.ts", needle: "cfg.model" }],
  "provider": [{ file: "lib/keyed-provider.ts", needle: "cfg.provider" }],
  "keyed_providers": [{ file: "lib/keyed-provider.ts", needle: "keyed_providers" }],
  "providers": [{ file: "lib/keyed-provider.ts", needle: "cfg.providers" }],
  "trim.verbatim_turns": [{ file: "lib/condense.ts", needle: "verbatim_turns" }],
  "trim.narrow_after_turn": [{ file: "lib/ground-truth.ts", needle: "narrow_after_turn" }],
  "trim.narrow_margin": [{ file: "lib/ground-truth.ts", needle: "narrow_margin" }],
  "trim.condense_model": [{ file: "lib/keyed-provider.ts", needle: "condense_model" }],
  "trial.turn_cap": [{ file: "routes/trial.ts", needle: "trial.turn_cap" }],
  "trial.ground_truth_tier": [{ file: "routes/trial.ts", needle: "ground_truth_tier" }],
  "trial.condense": [{ file: "routes/trial.ts", needle: "condenseEnabled: cfg.trial.condense" }],
  "trial.daily_session_cap": [{ file: "lib/trial-pool.ts", needle: "daily_session_cap" }],
  "trial.sessions_per_device": [{ file: "lib/trial-pool.ts", needle: "sessions_per_device" }],
  "trial.pool": [{ file: "lib/trial-pool.ts", needle: "trial.pool" }],
  // Feature 008. `enabled` is read once, by voiceConfig(); the rest by the
  // stt route. `model` is the Worker's own choice and is never served.
  "voice.enabled": [{ file: "lib/runtime-config.ts", needle: "cfg.voice.enabled" }],
  "voice.seconds_per_device": [{ file: "routes/stt.ts", needle: "voice.seconds_per_device" }],
  "voice.max_clip_seconds": [{ file: "routes/stt.ts", needle: "voice.max_clip_seconds" }],
  "voice.model": [{ file: "routes/stt.ts", needle: "voice.model" }],
};

// The two app-only levers: served verbatim, read by no worker/src/** module.
const APP_ONLY_LEVERS = ["min_supported_version", "content_manifest_url"];

describe("every config lever has the consumer data-model.md §A5 names", () => {
  const source: Record<string, string> = env.WORKER_SOURCE;

  for (const [lever, consumers] of Object.entries(LEVER_CONSUMERS)) {
    for (const { file, needle } of consumers) {
      it(`${lever} is read in ${file}`, () => {
        expect(source[file]).toBeDefined();
        expect(source[file]).toContain(needle);
      });
    }
  }

  it("the app-only levers are served verbatim by routes/config.ts and read by no other module", () => {
    for (const lever of APP_ONLY_LEVERS) {
      // config.ts serves the whole cfg object verbatim (minus `web`, feature
      // 007's site-only block, stripped before stringifying), so it names no
      // individual APP_ONLY_LEVERS by string — that IS "served verbatim".
      expect(source["routes/config.ts"]).toContain("JSON.stringify(appCfg)");
      for (const [path, content] of Object.entries(source)) {
        if (path === "routes/config.ts" || path === "lib/runtime-config.ts") continue;
        expect(content).not.toContain(lever);
      }
    }
  });
});
