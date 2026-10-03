import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import {
  isRepeatedWrongTurn,
  learnerNamedTerms,
  reachedInsightKeys,
  score,
  selectSlice,
} from "../../src/lib/ground-truth";
import { getRuntimeConfig } from "../../src/lib/runtime-config";
import type { Turn } from "../../src/lib/schemas";
import type { Problem } from "../../../tools/problem-types";

function allSeedProblems(): Problem[] {
  return getPublicManifest().problems.map((pub) => ({
    public: pub,
    private: getPrivate(pub.id)!,
  }));
}

function userTurn(text: string): Turn {
  return { role: "user", text };
}

describe("learnerNamedTerms() vs reachedInsightKeys() — FR-004a", () => {
  it("naming a never_say term unblocks the term without reaching its insight", async () => {
    const problem = getPrivate("vp-0001")!;
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: problem };
    const cfg = await getRuntimeConfig(env.DB);

    // Deliberately just the bare term: any filler word risks a coincidental
    // token overlap with the insight's own scoring text (e.g. "a", "you")
    // pushing score() over cfg.trim.narrow_margin on its own, which would
    // confound this test's isolation of the two predicates.
    const messages: Turn[] = [userTurn("hashmap")];

    const named = learnerNamedTerms(full, messages);
    expect(named.has("hashmap")).toBe(true);

    const reached = reachedInsightKeys(full, messages, cfg);
    expect(reached.has("complement_lookup")).toBe(false);
  });

  it("a term the learner never used appears in neither set", async () => {
    const problem = getPrivate("vp-0001")!;
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: problem };
    const cfg = await getRuntimeConfig(env.DB);

    const messages: Turn[] = [userTurn("I would check every pair with two nested loops")];

    const named = learnerNamedTerms(full, messages);
    expect(named.has("hashmap")).toBe(false);
    expect(named.has("hash map")).toBe(false);

    const reached = reachedInsightKeys(full, messages, cfg);
    expect(reached.has("complement_lookup")).toBe(false);
  });
});

describe("learnerNamedTerms() — typos and the words inside a named term", () => {
  const full = (): Problem => ({
    public: getPublicManifest().problems.find((p) => p.id === "vp-0001")!,
    private: getPrivate("vp-0001")!,
  });

  it("a swapped-letter typo names the term, its spelling variant, and the short word inside it", () => {
    const named = learnerNamedTerms(full(), [userTurn("I store in hashamp after I check")]);
    expect(named.has("hashmap")).toBe(true);
    expect(named.has("hash map")).toBe(true);
    expect(named.has("map")).toBe(true);
  });

  it("two substituted letters name a 7+ letter term", () => {
    expect(learnerNamedTerms(full(), [userTurn("hamsmap")]).has("hashmap")).toBe(true);
  });

  it("a 5-6 letter term takes one edit, not two", () => {
    expect(learnerNamedTerms(full(), [userTurn("the indx of it")]).has("index")).toBe(true);
    expect(learnerNamedTerms(full(), [userTurn("an inner loop")]).has("index")).toBe(false);
  });

  it("a short term needs its exact spelling", () => {
    expect(learnerNamedTerms(full(), [userTurn("mad cap tap")]).has("map")).toBe(false);
  });

  it("a run of typed words never fuzzy-matches a phrase term", () => {
    expect(learnerNamedTerms(full(), [userTurn("as you do")]).has("as you go")).toBe(false);
  });

  it("a different first letter is not a typo", () => {
    expect(learnerNamedTerms(full(), [userTurn("cashmap")]).has("hashmap")).toBe(false);
  });
});

describe("selectSlice() never leaks private fields, for every seed problem at every turn index", () => {
  it("no editorial, why_it_fails, model_answer, grading_note, or hints array at any turn 1..15", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    for (const problem of allSeedProblems()) {
      const messages: Turn[] = [userTurn("I could check every pair with two nested loops")];
      for (let turnIndex = 1; turnIndex <= 15; turnIndex++) {
        const slice = selectSlice(problem, messages, turnIndex, cfg);
        const serialised = JSON.stringify(slice);
        expect(serialised).not.toContain("editorial");
        expect(serialised).not.toContain("why_it_fails");
        expect(serialised).not.toContain("model_answer");
        expect(serialised).not.toContain("grading_note");
        expect(serialised).not.toContain("hints");
        // no insight `text` — only `insightKeys` (keys only)
        for (const insight of problem.private.key_insights) {
          if (slice.insightKeys.includes(insight.key)) {
            expect(serialised).not.toContain(insight.text);
          }
        }
      }
    }
  });

  it("an insight the learner has demonstrably reached drops out of insightKeys", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: getPrivate("vp-0001")! };

    const messages: Turn[] = [
      userTurn(
        "I would walk the list once and for each element compute the target minus that element, its complement, and check if the complement is already in a map",
      ),
    ];
    const slice = selectSlice(full, messages, 1, cfg);
    expect(slice.insightKeys).not.toContain("complement_lookup");
  });
});

describe("score() ignores stopwords — regression, found via the live tutor harness", () => {
  it("a shared stopword alone does not count as content overlap", () => {
    // Reproduces exactly what worker/test/harness/tutor.harness.test.ts's
    // vp-0001 concept_question case hit live: "what is a hashmap
    // actually?" against index_storage's insight text (which ends "...the
    // answer IS positions") scored 0.267 on the shared word "is" alone
    // before this fix — clearing cfg.trim.narrow_margin's 0.15 default and
    // marking index_storage falsely reached, which turned off its
    // never_say protection and let a real reply say "index" uncensored.
    const insightText =
      "index_storage The map has to store positions, not just presence, because the answer is positions";
    const learnerText = "what is a hashmap actually?";
    expect(score(insightText, learnerText)).toBe(0);
  });

  it("reachedInsightKeys() does not falsely mark an insight reached from a concept question alone", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: getPrivate("vp-0001")! };
    const messages: Turn[] = [userTurn("what is a hashmap actually?")];

    const reached = reachedInsightKeys(full, messages, cfg);
    expect(reached.has("index_storage")).toBe(false);
    expect(reached.size).toBe(0);
  });

  it("genuine content-word overlap still scores above zero", () => {
    const insightText = "complement_lookup Realizing you are searching for a specific complement";
    const learnerText = "I need to find the complement of each value";
    expect(score(insightText, learnerText)).toBeGreaterThan(0);
  });
});

describe("isRepeatedWrongTurn() and the failing_case tier-B gate", () => {
  it("a wrong turn raised once ships its counter_question (tierA) but the failing_case gate stays closed", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: getPrivate("vp-0001")! };
    const wrongTurn = full.private.common_wrong_turns.find((w) => w.key === "sort_first")!;

    const messages: Turn[] = [userTurn("I will sort the values first and then use two pointers")];

    expect(isRepeatedWrongTurn(wrongTurn, messages, cfg)).toBe(false);

    const slice = selectSlice(full, messages, 1, cfg);
    expect(slice.wrongTurns.find((w) => w.key === "sort_first")?.counter_question).toBe(
      wrongTurn.counter_question,
    );
    expect(slice.failingCases).not.toContain(wrongTurn.failing_case);
  });

  it("the same wrong turn raised a second time ships both the counter_question and the failing_case", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
    const full: Problem = { public: pub, private: getPrivate("vp-0001")! };
    const wrongTurn = full.private.common_wrong_turns.find((w) => w.key === "sort_first")!;

    const messages: Turn[] = [
      userTurn("I will sort the values first and then use two pointers"),
      { role: "tutor", text: "If you sort the values first, what happens to the positions?" },
      userTurn("right, but I still think I should sort the values first and use two pointers"),
    ];

    expect(isRepeatedWrongTurn(wrongTurn, messages, cfg)).toBe(true);

    const slice = selectSlice(full, messages, 2, cfg);
    expect(slice.wrongTurns.find((w) => w.key === "sort_first")?.counter_question).toBe(
      wrongTurn.counter_question,
    );
    expect(slice.failingCases).toContain(wrongTurn.failing_case);
  });
});
