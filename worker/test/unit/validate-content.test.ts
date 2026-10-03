// Fixtures are imported as JSON modules rather than read via node:fs at
// runtime — @cloudflare/vitest-pool-workers' node:fs polyfill percent-
// encodes any path containing a space, and this repo's directory does
// ("dry run app"), which breaks readFileSync/readdirSync here. Static
// JSON imports go through the bundler instead and are unaffected.
import { describe, expect, it } from "vitest";
import { validateOne } from "../../../tools/validate-content";

import rule0 from "../fixtures/content/rule0-glossary-on-private.json";
import rule1 from "../fixtures/content/rule1-wrong-schema-version.json";
import rule2 from "../fixtures/content/rule2-missing-wrong-approach.json";
import rule3 from "../fixtures/content/rule3-unresolvable-followup.json";
import rule4 from "../fixtures/content/rule4-duplicate-insight-key.json";
import rule5 from "../fixtures/content/rule5-two-hint-rungs.json";
import rule6 from "../fixtures/content/rule6-empty-never-say.json";
import rule7 from "../fixtures/content/rule7-missing-counter-question.json";
import rule8 from "../fixtures/content/rule8-counter-question-not-a-question.json";
import rule9 from "../fixtures/content/rule9-never-say-leaks-in-hints.json";
import rule11 from "../fixtures/content/rule11-never-say-already-public.json";
import rule12 from "../fixtures/content/rule12-tag-not-plain-words.json";
import valid from "../fixtures/content/valid.json";

// T074's fixtures, one per failing rule.
const RULE_FIXTURES: [number, unknown][] = [
  [0, rule0],
  [1, rule1],
  [2, rule2],
  [3, rule3],
  [4, rule4],
  [5, rule5],
  [6, rule6],
  [7, rule7],
  [8, rule8],
  [9, rule9],
  // Rule 11 has no fixture pair in T074 — it was added after a physical
  // device run where `vp-0003` blocked "in order", a phrase printed in its
  // own public statement, and the leak filter therefore discarded ordinary
  // tutor replies whole.
  [11, rule11],
  // Rule 12: one spelling per tag (`two pointers`, not `two-pointers`).
  [12, rule12],
];

// FR-029, SC-013.
describe("validateOne() — each T074 fixture fails its own rule", () => {
  for (const [rule, fixture] of RULE_FIXTURES) {
    it(`fixture for rule ${rule} fails rule ${rule}`, () => {
      const { failures } = validateOne(fixture);
      expect(failures.some((f) => f.rule === rule)).toBe(true);
    });
  }

  it("the rule-0 fixture fails ONLY rule 0 — it short-circuits before any other rule reports", () => {
    const { failures } = validateOne(rule0);
    expect(failures.length).toBeGreaterThan(0);
    expect(failures.every((f) => f.rule === 0)).toBe(true);
  });

  it("a valid problem passes all eleven rules (rule 10 excepted — asserted over build output, not here)", () => {
    const { failures } = validateOne(valid);
    expect(failures).toEqual([]);
  });
});
