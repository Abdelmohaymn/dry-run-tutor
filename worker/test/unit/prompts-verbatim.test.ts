import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { CONDENSE_PROMPT } from "../../src/prompts/condense";
import { FINISH_CHECK_PROMPT } from "../../src/prompts/finish-check";
import { JUDGE_PROMPT } from "../../src/prompts/judge";
import { REPAIR_PROMPT } from "../../src/prompts/repair";
import { TUTOR_PROMPT } from "../../src/prompts/tutor";

// The §Prompt block of each contract file is extracted at vitest config
// build time (real Node, real fs — the Workers test runtime has no host
// filesystem access) and injected as the EXPECTED_PROMPTS binding. See
// vitest.config.ts.
describe("prompts are byte-identical to their contract file's §Prompt block", () => {
  it("tutor.ts", () => {
    expect(TUTOR_PROMPT).toBe(env.EXPECTED_PROMPTS.tutor);
  });

  it("judge.ts", () => {
    expect(JUDGE_PROMPT).toBe(env.EXPECTED_PROMPTS.judge);
  });

  it("condense.ts", () => {
    expect(CONDENSE_PROMPT).toBe(env.EXPECTED_PROMPTS.condense);
  });

  it("repair.ts", () => {
    expect(REPAIR_PROMPT).toBe(env.EXPECTED_PROMPTS.repair);
  });

  it("finish-check.ts", () => {
    expect(FINISH_CHECK_PROMPT).toBe(env.EXPECTED_PROMPTS.finishCheck);
  });
});
