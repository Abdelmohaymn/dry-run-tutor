import { describe, expect, it, vi } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import {
  buildEvidenceCheckInput,
  evidenceCheckSchema,
  gatherEvidence,
  normaliseEvidence,
  quotedByLearner,
  quotedTurnIndex,
  verifySettled,
  type EvidenceCall,
  type InsightEvidence,
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

  // 2026-10-13, PLAN_08: the progress check's tutor quotes are matched against
  // tutor turns, and a model copies the transcript's "tutor:" label too.
  it("drops a leading 'tutor:' label the same way", () => {
    expect(quotedByLearner("tutor: nested loop", ["nested loop"])).toBe(true);
    expect(quotedByLearner("Tutor: nested loop", ["nested loop"])).toBe(true);
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

describe("quotedTurnIndex()", () => {
  it("returns the index of the learner turn that holds the quote", () => {
    expect(quotedTurnIndex("two pointers", ["brute force", "2 pointers", "two pointers"])).toBe(2);
    expect(quotedTurnIndex("brute force", ["brute force", "2 pointers"])).toBe(0);
  });

  it("uses the turn that matches the first fragment of an ellipsis quote", () => {
    const turns = ["I would loop over the digits", "okay", "and then sum them up"];
    expect(quotedTurnIndex("loop over the digits ... sum them up", turns)).toBe(0);
    expect(quotedTurnIndex("sum them up … loop over the digits", turns)).toBe(2);
  });

  it("returns -1 when any fragment fails, or the quote is empty", () => {
    const turns = ["I would loop over the digits", "and then sum them up"];
    expect(quotedTurnIndex("loop over the digits ... never said this", turns)).toBe(-1);
    expect(quotedTurnIndex("never said this", turns)).toBe(-1);
    expect(quotedTurnIndex("...", turns)).toBe(-1);
  });

  it("agrees with quotedByLearner on a user: label and a paraphrase", () => {
    expect(quotedTurnIndex("user: nested loop", ["x", "nested loop"])).toBe(1);
    expect(quotedTurnIndex("keep summing all the digits", ["we keep summing the digits again and again"])).toBe(0);
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

  describe("the tutor question (PLAN_06)", () => {
    const oneWord = "How would you check if a single word reads the same forwards and backwards using brute force?";
    const sentInput = (call: ReturnType<typeof stubCall>) => (call.mock.calls[0] as unknown[])[1] as string;

    it("sends the tutor turn before the quoted learner turn as asked", async () => {
      const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "2 pointers", key: insight }] },
        [{ text: "brute force", asked: null }, { text: "2 pointers", asked: oneWord }],
        problem,
        call,
      );
      expect(sentInput(call)).toContain(`  asked: "${oneWord}"`);
    });

    it("sends asked for an approach claim too", async () => {
      const call = stubCall(verdicts({ [`approach:${loop}`]: true }));
      await gatherEvidence(
        { approach_quote: "loop summing digits", matched_approach: loop, insights_hit: [] },
        [{ text: "hi", asked: null }, { text: "loop summing digits", asked: "What is your plan?" }],
        problem,
        call,
      );
      expect(sentInput(call)).toContain('  asked: "What is your plan?"');
    });

    it("takes asked from the turn that holds the first fragment of the quote", async () => {
      const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "it shrinks fast ... sums to under 100", key: insight }] },
        [
          { text: "it shrinks fast", asked: "first question?" },
          { text: "ok", asked: "middle question?" },
          { text: "a 10 digit number sums to under 100", asked: "last question?" },
        ],
        problem,
        call,
      );
      expect(sentInput(call)).toContain('asked: "first question?"');
      expect(sentInput(call)).not.toContain("last question?");
    });

    it("sends at most the last 400 characters of a long tutor turn, from a word boundary", async () => {
      const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
      const long = `${"abcdefghi ".repeat(60)}…what would you check?`;
      expect(long.length).toBeGreaterThan(600);
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "2 pointers", key: insight }] },
        [{ text: "2 pointers", asked: long }],
        problem,
        call,
      );
      const asked = /^ {2}asked: "(.*)"$/m.exec(sentInput(call))![1];
      expect(asked.length).toBeLessThanOrEqual(400);
      expect(asked.endsWith("what would you check?")).toBe(true);
      expect(asked.startsWith("abcdefghi ")).toBe(true);
    });

    it("collapses whitespace in asked and leaves a short tutor turn whole", async () => {
      const call = stubCall(verdicts({ [`insight:${insight}`]: true }));
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "2 pointers", key: insight }] },
        [{ text: "2 pointers", asked: "Which\n  approach?" }],
        problem,
        call,
      );
      expect(sentInput(call)).toContain('asked: "Which approach?"');
    });

    it("sends no asked line for plain string turns, or when there was no tutor turn", async () => {
      const plain = stubCall(verdicts({ [`insight:${insight}`]: true }));
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "2 pointers", key: insight }] },
        ["2 pointers"],
        problem,
        plain,
      );
      expect(sentInput(plain)).not.toContain("asked:");
      const none = stubCall(verdicts({ [`insight:${insight}`]: true }));
      await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "2 pointers", key: insight }] },
        [{ text: "2 pointers", asked: null }],
        problem,
        none,
      );
      expect(sentInput(none)).not.toContain("asked:");
    });

    it("provenance still checks learner text only: the asked text earns nothing", async () => {
      const call = stubCall(verdicts({}));
      const evidence = await gatherEvidence(
        { approach_quote: "", matched_approach: "none", insights_hit: [{ quote: "reads the same forwards and backwards", key: insight }] },
        [{ text: "yes", asked: oneWord }],
        problem,
        call,
      );
      expect(call).not.toHaveBeenCalled();
      expect(evidence.supportedInsights.size).toBe(0);
    });
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
      { id: "approach:iterative_digit_sum", kind: "APPROACH", idea: `${approach.name}: ${approach.sketch.join("; ")}`, quote: "nested loop", asked: null },
      { id: "insight:process_shrinks_fast", kind: "INSIGHT", idea: ins.text, quote: "it shrinks fast", asked: null },
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

  it("renders asked before quote when a claim has one, and no asked line when null", () => {
    const withAsked = buildEvidenceCheckInput(problem, [
      { id: "insight:a", kind: "INSIGHT", idea: "idea", quote: "2 pointers", asked: "How would  you check\none word?" },
    ]);
    expect(withAsked).toContain('  idea: idea\n  asked: "How would you check one word?"\n  quote: "2 pointers"');
    const without = buildEvidenceCheckInput(problem, [
      { id: "insight:a", kind: "INSIGHT", idea: "idea", quote: "2 pointers", asked: null },
    ]);
    expect(without).not.toContain("asked");
  });
});

// 2026-10-13, PLAN_08 D5/D6: the support check on the progress check's quotes,
// run before the judge model sees the lists.
describe("buildEvidenceCheckInput() ASSISTED claims", () => {
  it("renders kind: ASSISTED, the tutor's quote, and no asked line", () => {
    const input = buildEvidenceCheckInput(problem, [
      { id: "assisted:process_shrinks_fast", kind: "ASSISTED", idea: "idea", quote: "the digits sum shrinks the number fast", asked: null },
    ]);
    expect(input).toContain("id: assisted:process_shrinks_fast");
    expect(input).toContain("kind: ASSISTED");
    expect(input).toContain('quote: "the digits sum shrinks the number fast"');
    expect(input).not.toContain("asked");
  });
});

describe("verifySettled()", () => {
  const key = "process_shrinks_fast";
  const other = "zero_is_its_own_answer";
  const asked = "How fast does the number shrink?";
  const turns = [
    { text: "it shrinks fast", asked: null },
    { text: "a 10 digit number sums to under 100", asked },
  ];
  const sent = (call: ReturnType<typeof stubCall>) => (call.mock.calls[0] as unknown[])[1] as string;
  const idsOf = (call: ReturnType<typeof stubCall>) =>
    ((call.mock.calls[0] as unknown[])[2] as any).schema.properties.results.items.properties.id.enum as string[];
  const learnerOnly = (k: string, q: string): InsightEvidence => ({ key: k, learnerQuote: q, tutorQuote: null });
  const tutorOnly = (k: string, q: string): InsightEvidence => ({ key: k, learnerQuote: null, tutorQuote: q });

  it("a key with a learnerQuote sends an insight claim whose asked is the tutor turn before the quoted learner turn", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: true }));
    await verifySettled([learnerOnly(key, "a 10 digit number sums to under 100")], turns, problem, call);
    expect(idsOf(call)).toEqual([`insight:${key}`]);
    expect(sent(call)).toContain("kind: INSIGHT");
    expect(sent(call)).toContain(`  asked: "${asked}"`);
    expect(sent(call)).toContain('quote: "a 10 digit number sums to under 100"');
  });

  it("a key with a tutorQuote sends an assisted claim with no asked", async () => {
    const call = stubCall(verdicts({ [`assisted:${key}`]: true }));
    await verifySettled([tutorOnly(key, "the sum shrinks the number each round")], turns, problem, call);
    expect(idsOf(call)).toEqual([`assisted:${key}`]);
    expect(sent(call)).toContain("kind: ASSISTED");
    expect(sent(call)).not.toContain("asked");
    expect(sent(call)).toContain('quote: "the sum shrinks the number each round"');
  });

  it("a key with both quotes sends both claims in the same call", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: false, [`assisted:${key}`]: true }));
    await verifySettled(
      [{ key, learnerQuote: "it shrinks fast", tutorQuote: "the sum shrinks the number each round" }],
      turns,
      problem,
      call,
    );
    expect(call).toHaveBeenCalledTimes(1);
    expect(idsOf(call)).toEqual([`insight:${key}`, `assisted:${key}`]);
  });

  it("strips a role label the model copied from the quote it sends", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: true }));
    await verifySettled([learnerOnly(key, "user: it shrinks fast")], turns, problem, call);
    expect(sent(call)).toContain('quote: "it shrinks fast"');
  });

  it("insight supported gives reached", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: true, [`assisted:${key}`]: true }));
    const out = await verifySettled(
      [{ key, learnerQuote: "it shrinks fast", tutorQuote: "the sum shrinks the number each round" }],
      turns,
      problem,
      call,
    );
    expect(out).toEqual({ reached: [key], assisted: [] });
  });

  it("insight unsupported and assisted supported gives assisted", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: false, [`assisted:${key}`]: true }));
    const out = await verifySettled(
      [{ key, learnerQuote: "it shrinks fast", tutorQuote: "the sum shrinks the number each round" }],
      turns,
      problem,
      call,
    );
    expect(out).toEqual({ reached: [], assisted: [key] });
  });

  it("both unsupported gives dropped from both lists", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: false, [`assisted:${key}`]: false }));
    const out = await verifySettled(
      [{ key, learnerQuote: "it shrinks fast", tutorQuote: "the sum shrinks the number each round" }],
      turns,
      problem,
      call,
    );
    expect(out).toEqual({ reached: [], assisted: [] });
  });

  it("decides each key on its own claims", async () => {
    const call = stubCall(verdicts({ [`insight:${key}`]: true, [`assisted:${other}`]: false }));
    const out = await verifySettled(
      [learnerOnly(key, "it shrinks fast"), tutorOnly(other, "the loop stops at one digit")],
      turns,
      problem,
      call,
    );
    expect(out).toEqual({ reached: [key], assisted: [] });
  });

  it("a call that throws gives the provenance-only lists: learnerQuote keys reached, the rest assisted", async () => {
    const call = vi.fn(async () => {
      throw new Error("boom");
    }) as never as EvidenceCall;
    const out = await verifySettled(
      [learnerOnly(key, "it shrinks fast"), tutorOnly(other, "the loop stops at one digit")],
      turns,
      problem,
      call,
    );
    expect(out).toEqual({ reached: [key], assisted: [other] });
  });

  it("an answer with no results array gives the provenance-only lists", async () => {
    const out = await verifySettled(
      [learnerOnly(key, "it shrinks fast"), tutorOnly(other, "the loop stops at one digit")],
      turns,
      problem,
      stubCall({}),
    );
    expect(out).toEqual({ reached: [key], assisted: [other] });
  });

  it("no evidence entries gives empty lists and no call", async () => {
    const call = stubCall(verdicts({}));
    expect(await verifySettled([], turns, problem, call)).toEqual({ reached: [], assisted: [] });
    expect(call).not.toHaveBeenCalled();
  });

  it("an unauthored key is never sent", async () => {
    const call = stubCall(verdicts({}));
    const out = await verifySettled([learnerOnly("made_up_key", "it shrinks fast")], turns, problem, call);
    expect(out).toEqual({ reached: [], assisted: [] });
    expect(call).not.toHaveBeenCalled();
  });
});
