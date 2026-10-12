import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { renderGroundTruth, selectSlice } from "../../src/lib/ground-truth";
import { getRuntimeConfig } from "../../src/lib/runtime-config";
import { LEAK_BLOCKED_FALLBACK, rewriteNote, WRAP_UP_SENTENCE } from "../../src/prompts/tutor";
import type { Problem } from "../../../tools/problem-types";

// These strings are code, outside the §Prompt fence, so prompts-verbatim does
// not cover them. docs/tutor-focus-issues.md Issues 1 and 2, 2026-10-11.

describe("renderGroundTruth() — counter-questions are conditional", () => {
  it("offers each wrong turn's question only for a mistake the learner's position actually contains", async () => {
    const problem: Problem = {
      public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!,
      private: getPrivate("vp-0001")!,
    };
    const cfg = await getRuntimeConfig(env.DB);
    const text = renderGroundTruth(selectSlice(problem, [], 1, cfg, "A"));
    for (const w of problem.private.common_wrong_turns) {
      expect(text).toContain(
        `- ${w.text} — only if their CURRENT position contains this mistake and they have not already dealt with it, you may ask: "${w.counter_question}"`,
      );
    }
    expect(text).not.toContain("if raised for the first time");
  });
});

describe("WRAP_UP_SENTENCE", () => {
  it("asks only for what is missing and otherwise points to Finish", () => {
    expect(WRAP_UP_SENTENCE).toContain("If they have not yet stated");
    expect(WRAP_UP_SENTENCE).toContain("they can finish");
  });

  it("keeps its trailing space: the substitution relies on it", () => {
    expect(WRAP_UP_SENTENCE.endsWith(". ")).toBe(true);
    expect(WRAP_UP_SENTENCE.endsWith("  ")).toBe(false);
  });
});

describe("rewriteNote()", () => {
  it("keeps the answer: reword, do not switch to a question", () => {
    const note = rewriteNote(["dp"]);
    expect(note).toContain("still answer it");
    expect(note).not.toContain("Ask about the idea without naming it");
  });

  it("keeps the singular and plural wording", () => {
    expect(rewriteNote(["dp"])).toContain("without that word");
    expect(rewriteNote(["dp"])).toContain("just say it without that word.");
    expect(rewriteNote(["dp", "memoization"])).toContain("just say it without those words.");
  });
});

// 2026-10-12, PLAN_04: "put that another way" read as broken when nothing had
// been said before the blocked draft.
describe("LEAK_BLOCKED_FALLBACK", () => {
  it("asks for a dry run, not a restatement", () => {
    expect(LEAK_BLOCKED_FALLBACK).not.toContain("another way");
    expect(LEAK_BLOCKED_FALLBACK.endsWith("?")).toBe(true);
  });
});
