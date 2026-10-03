import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { learnerNamedTerms } from "../../src/lib/ground-truth";
import {
  blockedTermsIn,
  buildBlockedTerms,
  cleanLead,
  containsBlockedTerm,
  streamFiltered,
  takeCompleteSentence,
} from "../../src/lib/leak-filter";
import type { Problem } from "../../../tools/problem-types";
import type { Turn } from "../../src/lib/schemas";
import { editDistance } from "../../src/lib/text-match";

function vp0001(): Problem {
  const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
  return { public: pub, private: getPrivate("vp-0001")! };
}

async function* deltas(...chunks: string[]): AsyncIterable<string> {
  for (const chunk of chunks) yield chunk;
}

describe("takeCompleteSentence()", () => {
  it("does not split early on a known abbreviation", () => {
    const result = takeCompleteSentence("e.g. this is one sentence.");
    expect(result).not.toBeNull();
    expect(result!.sentence).toBe("e.g. this is one sentence.");
    expect(result!.remainder).toBe("");
  });

  it("does not split on a decimal number", () => {
    const result = takeCompleteSentence("the ratio is 3.14 here.");
    expect(result!.sentence).toBe("the ratio is 3.14 here.");
  });

  it("returns null when no complete sentence is available yet", () => {
    expect(takeCompleteSentence("this has no ending yet")).toBeNull();
  });

  it("does not mangle complexity notation like O(n log n)", () => {
    const result = takeCompleteSentence("This runs in O(n log n) time overall.");
    expect(result!.sentence).toBe("This runs in O(n log n) time overall.");
  });

  it("an abbreviation split across the sentence boundary check still resolves at the real sentence end", () => {
    const result = takeCompleteSentence("e.g. this, i.e. that. Next sentence.");
    expect(result!.sentence).toBe("e.g. this, i.e. that.");
    expect(result!.remainder).toBe(" Next sentence.");
  });
});

describe("containsBlockedTerm()", () => {
  it("hashmapping does not match the term 'hash map'", () => {
    expect(containsBlockedTerm("I'm hashmapping this problem", ["hash map"])).toBe(false);
  });

  it("matches the whole word regardless of punctuation", () => {
    expect(containsBlockedTerm("That's a HashMap, right?", ["hashmap"])).toBe(true);
  });
});

describe("streamFiltered()", () => {
  it("catches a blocked term split across two deltas", async () => {
    const emitted: string[] = [];
    const result = await streamFiltered(
      deltas("That's a hash", " map, right?"),
      ["hash map"],
      (s) => { emitted.push(s); },
    );
    expect(result.leakBlocked).toBe(true);
    expect(emitted).toEqual([]);
  });

  it("emits sentences that contain no blocked term", async () => {
    const emitted: string[] = [];
    const result = await streamFiltered(
      deltas("What are you searching for", " at each step? Think about it."),
      ["hash map"],
      (s) => { emitted.push(s); },
    );
    expect(result.leakBlocked).toBe(false);
    expect(emitted.join("")).toBe("What are you searching for at each step? Think about it.");
  });
});

describe("buildBlockedTerms()", () => {
  it("sessionEnded == 'solution' disables the filter entirely", () => {
    const problem = vp0001();
    const terms = buildBlockedTerms(problem, new Set(), new Set(), "solution");
    expect(terms).toEqual([]);
  });

  it("blocks an unreached insight's never_say terms by default", () => {
    const problem = vp0001();
    const terms = buildBlockedTerms(problem, new Set(), new Set(), null);
    expect(terms).toContain("hash map");
    expect(terms).toContain("hashmap");
  });

  it("drops a reached insight's terms", () => {
    const problem = vp0001();
    const terms = buildBlockedTerms(problem, new Set(["complement_lookup"]), new Set(), null);
    expect(terms).not.toContain("hash map");
  });
});

describe("FR-004a: a term the learner has named is unblocked, one they have not stays blocked", () => {
  it("a reply explaining 'hash map' is emitted in full once the learner has said 'hashmap'", async () => {
    const problem = vp0001();
    const messages: Turn[] = [{ role: "user", text: "hashmap" }];
    const named = learnerNamedTerms(problem, messages);
    const blocked = buildBlockedTerms(problem, new Set(), named, null);

    const emitted: string[] = [];
    const result = await streamFiltered(
      deltas("A hash map lets you look values up directly."),
      blocked,
      (s) => { emitted.push(s); },
    );
    expect(result.leakBlocked).toBe(false);
    expect(emitted.join("")).toContain("hash map");
  });

  it("the same reply is blocked when the learner has not said 'hashmap'", async () => {
    const problem = vp0001();
    const messages: Turn[] = [{ role: "user", text: "I would check every pair" }];
    const named = learnerNamedTerms(problem, messages);
    const blocked = buildBlockedTerms(problem, new Set(), named, null);

    const result = await streamFiltered(
      deltas("A hash map lets you look values up directly."),
      blocked,
      () => {},
    );
    expect(result.leakBlocked).toBe(true);
  });

  it("removing the learnerNamed subtraction from buildBlockedTerms() fails this test", () => {
    const problem = vp0001();
    const messages: Turn[] = [{ role: "user", text: "hashmap" }];
    const named = learnerNamedTerms(problem, messages);

    const withSubtraction = buildBlockedTerms(problem, new Set(), named, null);
    const withoutSubtraction = buildBlockedTerms(problem, new Set(), new Set(), null);

    expect(withSubtraction).not.toContain("hashmap");
    expect(withoutSubtraction).toContain("hashmap");
  });
});

describe("editDistance()", () => {
  it("counts an adjacent swap as one edit", () => {
    expect(editDistance("hashamp", "hashmap", 2)).toBe(1);
  });
  it("stops at max + 1 once the distance is exceeded", () => {
    expect(editDistance("pointer", "hashmap", 2)).toBe(3);
  });
});

describe("blockedTermsIn() and cleanLead()", () => {
  it("lists every blocked term in a draft, whole-word", () => {
    expect(blockedTermsIn("Try a HashMap, or the complement.", ["hashmap", "complement", "index"])).toEqual([
      "hashmap",
      "complement",
    ]);
    expect(blockedTermsIn("mapping it out", ["map"])).toEqual([]);
  });

  it("keeps the sentences before the first blocked one", () => {
    expect(cleanLead("Good start. What does that cost? Use a hash map.", ["hash map"])).toBe(
      "Good start. What does that cost?",
    );
    expect(cleanLead("Use a hash map. Good start.", ["hash map"])).toBe("");
    expect(cleanLead("All clean here", ["hash map"])).toBe("All clean here");
  });
});
