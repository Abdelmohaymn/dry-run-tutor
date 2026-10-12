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
const dialogue = [
  { role: "user" as const, text: "brute force" },
  { role: "tutor" as const, text: "How would you check one word?" },
  { role: "user" as const, text: "two pointers technique" },
];

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
    expect(schema.required).toContain("named");
    expect(schema.properties.named.type).toBe("array");
    expect(schema.properties.named.items.enum).toEqual(neverSayTerms(problem));
    expect(schema.properties.reached.items.enum).toEqual(problem.private.key_insights.map((i) => i.key));
  });

  it("has no named property when the problem authors no terms: strict mode rejects an empty enum", () => {
    const { schema } = finishCheckSchema(noTerms) as { schema: any };
    expect(schema.required).toEqual(["reached", "assisted"]);
    expect(schema.properties).not.toHaveProperty("named");
  });

  // 2026-10-12, PLAN_07 D1: assisted is limited to the insight keys, like reached.
  it("adds assisted, limited to the insight keys, and requires it", () => {
    const { schema } = finishCheckSchema(problem) as { schema: any };
    const keys = problem.private.key_insights.map((i) => i.key);
    expect(schema.properties.assisted.type).toBe("array");
    expect(schema.properties.assisted.items.enum).toEqual(keys);
    expect(schema.required).toEqual(["reached", "assisted", "named"]);
  });
});

describe("buildFinishCheckInput()", () => {
  it("lists the terms after the insights, and never a hint or the editorial", () => {
    const input = buildFinishCheckInput(problem, learner);
    const termsAt = input.indexOf("Terms:");
    expect(termsAt).toBeGreaterThan(input.indexOf("Key insights:"));
    expect(termsAt).toBeLessThan(input.indexOf("The conversation so far, oldest first:"));
    for (const term of neverSayTerms(problem)) expect(input).toContain(`- ${term}`);
    for (const insight of problem.private.key_insights) for (const hint of insight.hints) expect(input).not.toContain(hint);
    expect(input).not.toContain(problem.private.editorial);
  });

  // PLAN_07 D2: both roles, labelled, in order.
  it("renders user: and tutor: lines in order under the conversation heading", () => {
    const input = buildFinishCheckInput(problem, dialogue);
    const heading = input.indexOf("The conversation so far, oldest first:");
    expect(heading).toBeGreaterThan(-1);
    const tail = input.slice(heading);
    expect(tail).toBe(
      [
        "The conversation so far, oldest first:",
        "user: brute force",
        "tutor: How would you check one word?",
        "user: two pointers technique",
      ].join("\n"),
    );
    expect(input).not.toContain("The learner's words so far");
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

  // PLAN_07 D1/D4: assisted keeps only authored keys, never overlaps reached,
  // and a bad assisted never costs reached (the same policy as named).
  it("returns assisted, keeping only authored keys, once each, minus any key also in reached", async () => {
    const result = await runFinishCheck(
      problem,
      dialogue,
      stubCall({
        reached: ["complement_lookup"],
        assisted: ["complement_lookup", "index_storage", "index_storage", "made_up_key", 7],
        named: [],
      }),
    );
    expect(result?.reached).toEqual(["complement_lookup"]);
    expect(result?.assisted).toEqual(["index_storage"]);
  });

  it("a missing assisted yields an empty list without touching reached", async () => {
    const result = await runFinishCheck(problem, learner, stubCall({ reached: ["complement_lookup"], named: [] }));
    expect(result?.assisted).toEqual([]);
    expect(result?.reached).toEqual(["complement_lookup"]);
  });

  it("an assisted that is not a list yields an empty list without touching reached", async () => {
    const result = await runFinishCheck(problem, learner, stubCall({ reached: ["single_pass"], assisted: "index_storage" }));
    expect(result?.assisted).toEqual([]);
    expect(result?.reached).toEqual(["single_pass"]);
  });

  it("ready counts reached only; callers combine the lists", async () => {
    const result = await runFinishCheck(
      problem,
      dialogue,
      stubCall({ reached: ["complement_lookup"], assisted: ["index_storage"] }),
    );
    expect(result?.ready).toBe(false);
  });

  it("still returns null when reached itself is unusable", async () => {
    expect(await runFinishCheck(problem, learner, stubCall({ named: ["hash map"] }))).toBeNull();
  });
});
