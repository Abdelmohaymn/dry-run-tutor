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
  });

  it("has no named property when the problem authors no terms: strict mode rejects an empty enum", () => {
    const { schema } = finishCheckSchema(noTerms) as { schema: any };
    expect(schema.required).toEqual(["insights"]);
    expect(schema.properties).not.toHaveProperty("named");
  });

  // 2026-10-13, PLAN_08 D1: one list, a learner quote and a tutor quote per key.
  it("asks for one insights list: key limited to the insight keys, both quotes strings, all required", () => {
    const { schema } = finishCheckSchema(problem) as { schema: any };
    const keys = problem.private.key_insights.map((i) => i.key);
    expect(schema.properties.insights.type).toBe("array");
    const item = schema.properties.insights.items;
    expect(item.type).toBe("object");
    expect(item.properties.key).toEqual({ type: "string", enum: keys });
    expect(item.properties.learner_quote).toEqual({ type: "string" });
    expect(item.properties.tutor_quote).toEqual({ type: "string" });
    expect(item.required).toEqual(["key", "learner_quote", "tutor_quote"]);
    expect(item.additionalProperties).toBe(false);
  });

  it("requires insights at the top level, plus named when there are terms, and nothing else", () => {
    const { schema } = finishCheckSchema(problem) as { schema: any };
    expect(schema.required).toEqual(["insights", "named"]);
    expect(schema.additionalProperties).toBe(false);
  });

  it("has no reached or assisted property any more", () => {
    const { schema } = finishCheckSchema(problem) as { schema: any };
    expect(schema.properties).not.toHaveProperty("reached");
    expect(schema.properties).not.toHaveProperty("assisted");
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

// 2026-10-13, PLAN_08 D1/D2: the check quotes its evidence and the server
// decides "reached" or "assisted" from the quote that holds up, so a claim with
// no words behind it is dropped.
const LEARNER_LINE = "I'd keep a map of value to index";
const TUTOR_LINE = "So you'd look up target minus the value?";
const talk = [
  { role: "user" as const, text: LEARNER_LINE },
  { role: "tutor" as const, text: TUTOR_LINE },
  { role: "user" as const, text: "yes" },
];
const entry = (key: string, learner_quote: string, tutor_quote: string) => ({ key, learner_quote, tutor_quote });

describe("runFinishCheck()", () => {
  it("returns the terms the learner named, keeping only authored ones, case-insensitively and once each", async () => {
    const result = await runFinishCheck(
      problem,
      talk,
      stubCall({ insights: [entry("index_storage", "keep a map of value to index", "")], named: ["Hash Map", "hash map", "not-a-term", 7] }),
    );
    expect(result?.named).toEqual(["hash map"]);
    expect(result?.reached).toEqual(["index_storage"]);
  });

  it("an answer without named still returns the insights, with named empty", async () => {
    const result = await runFinishCheck(
      problem,
      talk,
      stubCall({ insights: [entry("index_storage", LEARNER_LINE, ""), entry("complement_lookup", "look up target minus the value", "")] }),
    );
    expect(result?.named).toEqual([]);
    // The second learner_quote is only in a tutor line: assisted, not reached.
    expect(result?.reached).toEqual(["index_storage"]);
    expect(result?.assisted).toEqual(["complement_lookup"]);
  });

  it("a named that is not a list is ignored, not fatal", async () => {
    const result = await runFinishCheck(
      problem,
      talk,
      stubCall({ insights: [entry("index_storage", LEARNER_LINE, "")], named: "hash map" }),
    );
    expect(result?.named).toEqual([]);
    expect(result?.reached).toEqual(["index_storage"]);
  });

  it("naming a term never marks an insight reached or makes the learner ready", async () => {
    const result = await runFinishCheck(problem, talk, stubCall({ insights: [], named: neverSayTerms(problem) }));
    expect(result?.reached).toEqual([]);
    expect(result?.assisted).toEqual([]);
    expect(result?.ready).toBe(false);
  });

  describe("provenance (D2)", () => {
    it("a learner_quote found in a user line is reached", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("index_storage", "keep a map of value to index", "")] }));
      expect(result?.reached).toEqual(["index_storage"]);
      expect(result?.assisted).toEqual([]);
    });

    it("an empty learner_quote with a tutor_quote found in a tutor line is assisted", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("complement_lookup", "", TUTOR_LINE)] }));
      expect(result?.reached).toEqual([]);
      expect(result?.assisted).toEqual(["complement_lookup"]);
    });

    it("a learner_quote copied from a tutor line is assisted, never reached (D2 c)", async () => {
      const result = await runFinishCheck(
        problem,
        talk,
        stubCall({ insights: [entry("complement_lookup", "look up target minus the value", "")] }),
      );
      expect(result?.reached).toEqual([]);
      expect(result?.assisted).toEqual(["complement_lookup"]);
      expect(result?.evidence).toEqual([
        { key: "complement_lookup", learnerQuote: null, tutorQuote: "look up target minus the value" },
      ]);
    });

    it("quotes found in no line drop the key from both lists", async () => {
      const result = await runFinishCheck(
        problem,
        talk,
        stubCall({ insights: [entry("complement_lookup", "I would sort the array first", "Sorting makes it cheap")] }),
      );
      expect(result?.reached).toEqual([]);
      expect(result?.assisted).toEqual([]);
      expect(result?.evidence).toEqual([]);
    });

    it("a tutor_quote that is only in a user line, with no learner_quote, is dropped", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("index_storage", "", LEARNER_LINE)] }));
      expect(result?.reached).toEqual([]);
      expect(result?.assisted).toEqual([]);
    });

    it("an unauthored key is dropped", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("made_up_key", LEARNER_LINE, "")] }));
      expect(result?.reached).toEqual([]);
      expect(result?.evidence).toEqual([]);
    });

    it("the same key twice gives one entry, and reached wins over assisted", async () => {
      const result = await runFinishCheck(
        problem,
        talk,
        stubCall({
          insights: [
            entry("index_storage", "", TUTOR_LINE),
            entry("index_storage", LEARNER_LINE, ""),
            entry("index_storage", LEARNER_LINE, ""),
          ],
        }),
      );
      expect(result?.reached).toEqual(["index_storage"]);
      expect(result?.assisted).toEqual([]);
      expect(result?.evidence.map((e) => e.key)).toEqual(["index_storage"]);
      expect(result?.evidence[0].learnerQuote).toBe(LEARNER_LINE);
    });

    it("a tutor_quote that passed provenance is kept beside a learner_quote that did too", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("index_storage", LEARNER_LINE, TUTOR_LINE)] }));
      expect(result?.evidence).toEqual([{ key: "index_storage", learnerQuote: LEARNER_LINE, tutorQuote: TUTOR_LINE }]);
    });

    it("a tutor_quote that failed provenance is not kept beside a learner_quote that passed", async () => {
      const result = await runFinishCheck(problem, talk, stubCall({ insights: [entry("index_storage", LEARNER_LINE, "something nobody said")] }));
      expect(result?.reached).toEqual(["index_storage"]);
      expect(result?.evidence).toEqual([{ key: "index_storage", learnerQuote: LEARNER_LINE, tutorQuote: null }]);
    });

    it("copes with a quote that carries the transcript's role label", async () => {
      const result = await runFinishCheck(
        problem,
        talk,
        stubCall({ insights: [entry("index_storage", `user: ${LEARNER_LINE}`, ""), entry("complement_lookup", "", `tutor: ${TUTOR_LINE}`)] }),
      );
      expect(result?.reached).toEqual(["index_storage"]);
      expect(result?.assisted).toEqual(["complement_lookup"]);
    });
  });

  describe("a malformed answer", () => {
    it("insights missing gives null", async () => {
      expect(await runFinishCheck(problem, talk, stubCall({ named: ["hash map"] }))).toBeNull();
    });

    it("insights not an array gives null", async () => {
      expect(await runFinishCheck(problem, talk, stubCall({ insights: "index_storage" }))).toBeNull();
      expect(await runFinishCheck(problem, talk, stubCall({ insights: { key: "index_storage" } }))).toBeNull();
    });

    it("an entry with no key, or a quote that is not a string, is skipped and the rest are kept", async () => {
      const result = await runFinishCheck(
        problem,
        talk,
        stubCall({
          insights: [
            { learner_quote: LEARNER_LINE, tutor_quote: "" },
            { key: "single_pass", learner_quote: 7, tutor_quote: "" },
            { key: "duplicates_ok", learner_quote: LEARNER_LINE, tutor_quote: null },
            "nonsense",
            null,
            entry("index_storage", LEARNER_LINE, ""),
          ],
        }),
      );
      expect(result?.reached).toEqual(["index_storage"]);
      expect(result?.evidence.map((e) => e.key)).toEqual(["index_storage"]);
    });
  });

  it("ready counts reached only; callers combine the lists", async () => {
    const result = await runFinishCheck(
      problem,
      talk,
      stubCall({ insights: [entry("index_storage", LEARNER_LINE, ""), entry("complement_lookup", "", TUTOR_LINE)] }),
    );
    expect(result?.reached).toEqual(["index_storage"]);
    expect(result?.assisted).toEqual(["complement_lookup"]);
    expect(result?.ready).toBe(false);
  });

  it("ready when every required insight is reached in the learner's own words", async () => {
    const both = [
      { role: "user" as const, text: "look up target minus the number, and keep each number's index" },
    ];
    const result = await runFinishCheck(
      problem,
      both,
      stubCall({
        insights: [
          entry("complement_lookup", "look up target minus the number", ""),
          entry("index_storage", "keep each number's index", ""),
        ],
      }),
    );
    expect(result?.ready).toBe(true);
  });

  it("evidence holds { key, learnerQuote, tutorQuote } for every kept key, nulls where a quote did not pass", async () => {
    const result = await runFinishCheck(
      problem,
      talk,
      stubCall({ insights: [entry("index_storage", LEARNER_LINE, ""), entry("complement_lookup", "", TUTOR_LINE)] }),
    );
    expect(result?.evidence).toEqual([
      { key: "index_storage", learnerQuote: LEARNER_LINE, tutorQuote: null },
      { key: "complement_lookup", learnerQuote: null, tutorQuote: TUTOR_LINE },
    ]);
  });

  it("returns null when the call throws", async () => {
    const call = vi.fn(async () => {
      throw new Error("boom");
    }) as never as FinishCheckCall;
    expect(await runFinishCheck(problem, talk, call)).toBeNull();
  });
});
