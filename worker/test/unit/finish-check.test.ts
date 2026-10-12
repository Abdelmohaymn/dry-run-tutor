import { describe, expect, it, vi } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import {
  buildFinishCheckInput,
  finishCheckSchema,
  neverSayTerms,
  runFinishCheck,
  withinMs,
  type FinishCheckCall,
} from "../../src/lib/finish-check";
import type { Problem } from "../../../tools/problem-types";

describe("withinMs", () => {
  it("passes through a check that settles in time", async () => {
    expect(await withinMs(Promise.resolve(true), 1000)).toBe(true);
  });

  it("resolves null when the check is still running at the deadline", async () => {
    const never = new Promise<boolean>(() => {});
    expect(await withinMs(never, 10)).toBe(null);
  });
});

const problem: Problem = {
  public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!,
  private: getPrivate("vp-0001")!,
};

/** A problem whose insights author no never_say terms at all. */
const noTerms: Problem = {
  ...problem,
  private: { ...problem.private, key_insights: problem.private.key_insights.map((i) => ({ ...i, never_say: [] })) },
};

function stubCall(json: unknown): FinishCheckCall {
  return vi.fn(async () => ({
    result: { text: "", json, usage: { inputTokens: 0, outputTokens: 0 } },
    providerId: "t",
    model: "t",
  })) as never;
}

const learner = [{ role: "user" as const, text: "I would remember each number with its index" }];

// docs/tutor-focus-issues.md Issue 1 / D8: the progress check also reports
// which never_say terms the learner referred to in any form.
describe("neverSayTerms()", () => {
  it("lists every insight's terms lowercased, deduplicated, in authored order", () => {
    const priv = problem.private;
    const withDuplicate: Problem = {
      ...problem,
      private: {
        ...priv,
        key_insights: [
          { ...priv.key_insights[0], never_say: ["Hash Map", "complement"] },
          { ...priv.key_insights[1], never_say: ["hash map", "One Pass"] },
        ],
      },
    };
    expect(neverSayTerms(withDuplicate)).toEqual(["hash map", "complement", "one pass"]);
  });
});

describe("finishCheckSchema()", () => {
  it("adds named, limited to the problem's terms, and requires it", () => {
    const { schema } = finishCheckSchema(problem) as { schema: any };
    expect(schema.required).toEqual(["reached", "named"]);
    expect(schema.properties.named.type).toBe("array");
    expect(schema.properties.named.items.enum).toEqual(neverSayTerms(problem));
    expect(schema.properties.reached.items.enum).toEqual(problem.private.key_insights.map((i) => i.key));
  });

  it("has no named property when the problem authors no terms: strict mode rejects an empty enum", () => {
    const { schema } = finishCheckSchema(noTerms) as { schema: any };
    expect(schema.required).toEqual(["reached"]);
    expect(schema.properties).not.toHaveProperty("named");
  });
});

describe("buildFinishCheckInput()", () => {
  it("lists the terms after the insights, and never a hint or the editorial", () => {
    const input = buildFinishCheckInput(problem, learner);
    const termsAt = input.indexOf("Terms:");
    expect(termsAt).toBeGreaterThan(input.indexOf("Key insights:"));
    expect(termsAt).toBeLessThan(input.indexOf("The learner's words so far"));
    for (const term of neverSayTerms(problem)) expect(input).toContain(`- ${term}`);
    for (const insight of problem.private.key_insights) for (const hint of insight.hints) expect(input).not.toContain(hint);
    expect(input).not.toContain(problem.private.editorial);
  });

  it("omits the Terms block when there are none", () => {
    expect(buildFinishCheckInput(noTerms, learner)).not.toContain("Terms:");
  });
});

describe("runFinishCheck()", () => {
  it("returns the terms the learner named, keeping only authored ones, case-insensitively and once each", async () => {
    const result = await runFinishCheck(
      problem,
      learner,
      stubCall({ reached: ["complement_lookup"], named: ["Hash Map", "hash map", "not-a-term", 7] }),
    );
    expect(result?.named).toEqual(["hash map"]);
    expect(result?.reached).toEqual(["complement_lookup"]);
  });

  it("an answer without named still returns reached, with named empty", async () => {
    const result = await runFinishCheck(problem, learner, stubCall({ reached: ["complement_lookup", "index_storage"] }));
    expect(result?.named).toEqual([]);
    expect(result?.reached).toEqual(["complement_lookup", "index_storage"]);
    expect(result?.ready).toBe(true);
  });

  it("a named that is not a list is ignored, not fatal", async () => {
    const result = await runFinishCheck(problem, learner, stubCall({ reached: ["single_pass"], named: "hash map" }));
    expect(result?.named).toEqual([]);
    expect(result?.reached).toEqual(["single_pass"]);
  });

  it("naming a term never marks an insight reached or makes the learner ready", async () => {
    const result = await runFinishCheck(problem, learner, stubCall({ reached: [], named: neverSayTerms(problem) }));
    expect(result?.reached).toEqual([]);
    expect(result?.ready).toBe(false);
  });

  it("still returns null when reached itself is unusable", async () => {
    expect(await runFinishCheck(problem, learner, stubCall({ named: ["hash map"] }))).toBeNull();
  });
});
