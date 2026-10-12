import { describe, expect, it, vi } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import {
  buildEvidenceCheckInput,
  evidenceCheckSchema,
  gatherEvidence,
  normaliseEvidence,
  quotedByLearner,
  type EvidenceCall,
} from "../../src/lib/judge-evidence";
import type { Problem } from "../../../tools/problem-types";

// docs/judge-evidence-issues.md. vp-0002 has the loop approach that
// `requires` process_shrinks_fast, and a `wrong` approach.
const problem: Problem = {
  public: getPublicManifest().problems.find((p) => p.id === "vp-0002")!,
  private: getPrivate("vp-0002")!,
};

function stubCall(json: unknown): EvidenceCall & ReturnType<typeof vi.fn> {
  return vi.fn(async () => ({
    result: { text: "", json, usage: { inputTokens: 0, outputTokens: 0 } },
    providerId: "t",
    model: "t",
  })) as never;
}

const verdicts = (map: Record<string, boolean>) => ({
  results: Object.entries(map).map(([id, supported]) => ({ id, why: "stub", supported })),
});

describe("normaliseEvidence()", () => {
  it("lowercases, folds punctuation to single spaces, and keeps Arabic letters", () => {
    expect(normaliseEvidence("Nested-Loop!")).toBe("nested loop");
    expect(normaliseEvidence("  A,  B  ")).toBe("a b");
    expect(normaliseEvidence("هاستخدم لوب")).toBe("هاستخدم لوب");
  });
});

describe("quotedByLearner()", () => {
  it("accepts an exact substring of a learner turn", () => {
    expect(quotedByLearner("loop until one digit", ["I would loop until one digit remains"])).toBe(true);
  });

  it("ignores case and punctuation", () => {
    expect(quotedByLearner("Nested-Loop!", ["nested loop"])).toBe(true);
  });

  it("drops a leading 'user:' label the model copied", () => {
    expect(quotedByLearner("user: nested loop", ["nested loop"])).toBe(true);
    expect(quotedByLearner("User: nested loop", ["nested loop"])).toBe(true);
  });

  it("rejects words that are not in any learner turn (a tutor sentence, say)", () => {
    expect(quotedByLearner("it shrinks fast", ["loop until one digit"])).toBe(false);
  });

  it("does not match a whole word inside a longer one", () => {
    expect(quotedByLearner("loop", ["loops"])).toBe(false);
  });

  it("accepts ellipsis fragments from different turns and rejects an invented fragment", () => {
    const turns = ["I would loop over the digits", "and then sum them up"];
    expect(quotedByLearner("loop over the digits ... sum them up", turns)).toBe(true);
    expect(quotedByLearner("loop over the digits… sum them up", turns)).toBe(true);
    expect(quotedByLearner("loop over the digits ... never said this", turns)).toBe(false);
  });

  it("accepts a small paraphrase: 4 of 5 tokens in one window, not 3 of 5", () => {
    const turns = ["we keep summing the digits again and again"];
    expect(quotedByLearner("keep summing all the digits", turns)).toBe(true);
    expect(quotedByLearner("keep adding all the numbers", turns)).toBe(false);
  });

  it("needs both tokens of a two-token fragment", () => {
    expect(quotedByLearner("sum digits", ["sum the digits"])).toBe(false);
    expect(quotedByLearner("sum digits", ["sum digits"])).toBe(true);
  });

  it("works on Arabic script", () => {
    expect(quotedByLearner("هاجمع الأرقام", ["أنا هاجمع الأرقام وأكرر"])).toBe(true);
    expect(quotedByLearner("هاجمع الأرقام", ["حاجة تانية خالص"])).toBe(false);
  });

  it("rejects an empty quote or one that is only ellipses", () => {
    expect(quotedByLearner("", ["anything"])).toBe(false);
    expect(quotedByLearner("...", ["anything"])).toBe(false);
    expect(quotedByLearner(" … ... ", ["anything"])).toBe(false);
  });
});

describe("gatherEvidence()", () => {
  const loop = "iterative_digit_sum";
  const insight = "process_shrinks_fast";

  it("nested loop repro: verbatim but empty, the support check rejects both claims", async () => {
    const call = stubCall(verdicts({ [`approach:${loop}`]: false, [`insight:${insight}`]: false }));
    const evidence = await gatherEvidence(
      { approach_quote: "nested loop", matched_approach: loop, insights_hit: [{ quote: "nested loop", key: insight }] },
      ["nested loop"],
      problem,
      call,
    );
    expect(evidence.approachSupported).toBe(false);
    expect(evidence.supportedInsights.size).toBe(0);
    expect(call).toHaveBeenCalledTimes(1);
  });

  it("makes no call when nothing is in the learner's words", async () => {
    const call = stubCall(verdicts({}));
    const evidence = await gatherEvidence(
      { approach_quote: "made up", matched_approach: loop, insights_hit: [{ quote: "also made up", key: insight }] },
      ["nested loop"],
      problem,
      call,
    );
    expect(call).not.toHaveBeenCalled();
    expect(evidence.approachSupported).toBe(false);
    expect(evidence.supportedInsights.size).toBe(0);
  });

  it("keeps whatever the support check says is supported", async () => {
    const call = stubCall(verdicts({ [`approach:${loop}`]: true, [`insight:${insight}`]: true }));
    const evidence = await gatherEvidence(
      {
        approach_quote: "loop summing digits",
        matched_approach: loop,
        insights_hit: [{ quote: "it shrinks fast", key: insight }],
      },
      ["loop summing digits while it is over 9", "it shrinks fast since a 10 digit number sums to under 100"],
      problem,
      call,
    );
    expect(evidence.approachSupported).toBe(true);
    expect([...evidence.supportedInsights]).toEqual([insight]);
  });

  it("falls back to provenance only when the call throws", async () => {
    const call = vi.fn(async () => {
      throw new Error("provider down");
    }) as never as EvidenceCall;
    const evidence = await gatherEvidence(
      { approach_quote: "nested loop", matched_approach: loop, insights_hit: [{ quote: "nested loop", key: insight }] },
      ["nested loop"],
      problem,
      call,
    );
    expect(evidence.approachSupported).toBe(true);
    expect([...evidence.supportedInsights]).toEqual([insight]);
  });

  it("falls back to provenance only when the reply is not { results: [...] }", async () => {
    const evidence = await gatherEvidence(
      { approach_quote: "nested loop", matched_approach: loop, insights_hit: [{ quote: "nested loop", key: insight }] },
      ["nested loop"],
      problem,
      stubCall({ nope: 1 }),
    );
    expect(evidence.approachSupported).toBe(true);
    expect([...evidence.supportedInsights]).toEqual([insight]);
  });

  it("treats a claim the reply leaves out as unsupported", async () => {
    const evidence = await gatherEvidence(
      { approach_quote: "loop summing digits", matched_approach: loop, insights_hit: [{ quote: "it shrinks fast", key: insight }] },
      ["loop summing digits", "it shrinks fast"],
      problem,
      stubCall(verdicts({ [`approach:${loop}`]: true })),
    );
    expect(evidence.approachSupported).toBe(true);
    expect(evidence.supportedInsights.size).toBe(0);
  });

  it("does not send a 'wrong' approach to the check, and keeps it", async () => {
    const call = stubCall(verdicts({}));
    const evidence = await gatherEvidence(
      { approach_quote: "sum the digits once", matched_approach: "single_pass_no_repeat", insights_hit: [] },
      ["sum the digits once and return it"],
      problem,
      call,
    );
    expect(evidence.approachSupported).toBe(true);
    // Nothing else to check, so no call at all.
    expect(call).not.toHaveBeenCalled();
  });

  it("leaves a 'wrong' approach out of the schema's id enum when an insight is sent too", async () => {
    const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
    const evidence = await gatherEvidence(
      {
        approach_quote: "sum the digits once",
        matched_approach: "single_pass_no_repeat",
        insights_hit: [{ quote: "it shrinks fast", key: insight }],
      },
      ["sum the digits once and return it", "it shrinks fast"],
      problem,
      call,
    );
    const schema = (call.mock.calls[0] as unknown[])[2] as { schema: any };
    expect(schema.schema.properties.results.items.properties.id.enum).toEqual([`insight:${insight}`]);
    expect(evidence.approachSupported).toBe(true);
  });

  it("an approach the problem does not list is never supported", async () => {
    const evidence = await gatherEvidence(
      { approach_quote: "hash map", matched_approach: "none", insights_hit: [] },
      ["hash map"],
      problem,
      stubCall(verdicts({})),
    );
    expect(evidence.approachSupported).toBe(false);
  });

  it("ignores a hit whose key is not authored, and keeps the first passing entry for a repeated key", async () => {
    const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
    const evidence = await gatherEvidence(
      {
        approach_quote: "",
        matched_approach: "none",
        insights_hit: [
          { quote: "not said", key: insight },
          { quote: "it shrinks fast", key: insight },
          { quote: "it shrinks fast", key: "not_authored" },
        ],
      },
      ["it shrinks fast"],
      problem,
      call,
    );
    expect([...evidence.supportedInsights]).toEqual([insight]);
  });
});

describe("evidenceCheckSchema() / buildEvidenceCheckInput()", () => {
  it("lists why before supported, and restricts id to the claim ids", () => {
    const { name, schema } = evidenceCheckSchema(["approach:a", "insight:b"]) as { name: string; schema: any };
    const item = schema.properties.results.items;
    expect(name).toBe("evidence_check");
    expect(item.required).toEqual(["id", "why", "supported"]);
    expect(Object.keys(item.properties)).toEqual(["id", "why", "supported"]);
    expect(item.properties.id.enum).toEqual(["approach:a", "insight:b"]);
  });

  it("carries the problem, each idea and each quote, and nothing private beyond the claimed ideas", () => {
    const approach = problem.private.reference_approaches.find((a) => a.key === "iterative_digit_sum")!;
    const ins = problem.private.key_insights.find((i) => i.key === "process_shrinks_fast")!;
    const input = buildEvidenceCheckInput(problem, [
      { id: "approach:iterative_digit_sum", kind: "APPROACH", idea: `${approach.name}: ${approach.sketch.join("; ")}`, quote: "nested loop" },
      { id: "insight:process_shrinks_fast", kind: "INSIGHT", idea: ins.text, quote: "it shrinks fast" },
    ]);
    expect(input).toContain(problem.public.title);
    expect(input).toContain(problem.public.statement);
    expect(input).toContain("id: approach:iterative_digit_sum");
    expect(input).toContain("kind: APPROACH");
    expect(input).toContain(ins.text);
    expect(input).toContain('quote: "it shrinks fast"');
    expect(input).not.toContain(problem.private.editorial);
    for (const term of ins.never_say) expect(input.toLowerCase()).not.toContain(term.toLowerCase());
  });
});
