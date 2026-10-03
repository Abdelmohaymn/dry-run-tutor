import { describe, expect, it } from "vitest";
import {
  containsNoGroundTruth,
  retainsLearnerWords,
  withinLengthRatio,
} from "../../src/lib/repair";

describe("withinLengthRatio()", () => {
  it("a transcript with no near-miss comes back unchanged word for word", () => {
    const raw = "I'd use a hash map to store the values I have seen so far.";
    expect(withinLengthRatio(raw, raw, 1.5)).toBe(true);
    expect(retainsLearnerWords(raw, raw, 0.6)).toBe(true);
    expect(containsNoGroundTruth(raw, ["binary search"])).toBe(true);
  });

  it("rejects when the repaired text is 3x the raw's length", () => {
    const raw = "hash mop";
    const repaired = "hash mop hash mop hash mop hash mop hash mop hash mop";
    expect(withinLengthRatio(raw, repaired, 1.5)).toBe(false);
  });

  it("rejects when the repaired text is half the raw's length", () => {
    const raw = "I would use a hash mop to store the compliment of each value";
    const repaired = "hash map";
    expect(withinLengthRatio(raw, repaired, 1.5)).toBe(false);
  });
});

describe("containsNoGroundTruth()", () => {
  it("rejects when the repaired text contains a blocked term the raw did not", () => {
    const repaired = "you should use a two pointer approach here";
    expect(containsNoGroundTruth(repaired, ["two pointer"])).toBe(false);
  });
});

describe("retainsLearnerWords()", () => {
  it("rejects when the repaired text is an answer to the problem rather than a correction", () => {
    const raw = "I'd use a hash mop to store the compliment";
    const repaired =
      "The optimal solution iterates once while maintaining a running total and a lookup structure";
    expect(retainsLearnerWords(raw, repaired, 0.6)).toBe(false);
  });
});

describe("all three guards together", () => {
  it("accepts a repair that fixes two terms and changes nothing else", () => {
    const raw = "I'd use a hash mop to store the compliment of each value";
    const repaired = "I'd use a hash map to store the complement of each value";
    expect(withinLengthRatio(raw, repaired, 1.5)).toBe(true);
    expect(retainsLearnerWords(raw, repaired, 0.6)).toBe(true);
    expect(containsNoGroundTruth(repaired, ["two pointer"])).toBe(true);
  });
});
