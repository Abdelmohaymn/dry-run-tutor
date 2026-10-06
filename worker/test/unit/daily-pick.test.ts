import { describe, expect, it } from "vitest";
import { dayNumber, pickDaily } from "../../src/lib/daily-pick";
import type { PublicHalf } from "../../../tools/problem-types";

function p(id: string, extra: Partial<PublicHalf> = {}): PublicHalf {
  return {
    schema_version: 2,
    id,
    title: id,
    ramp: "easy",
    tags: [],
    source: "test",
    statement: "s",
    constraints: [],
    est_speak_seconds: 60,
    glossary_terms: [],
    ...extra,
  };
}

const NONE = { killed_problem_ids: [] as string[], rotation: undefined };
// 2026-10-06 is dayNumber 20732 → % 3 === 2.
const DATE = "2026-10-06";
const pool = [p("vp-0003"), p("vp-0001"), p("vp-0002")];

describe("pickDaily()", () => {
  it("a dated problem for exactly that date wins", () => {
    const all = [...pool, p("vp-0009", { date: DATE })];
    expect(pickDaily(all, NONE, DATE)?.id).toBe("vp-0009");
    expect(pickDaily(all, NONE, "2026-10-07")?.id).not.toBe("vp-0009");
  });

  it("skips a killed dated problem", () => {
    const all = [...pool, p("vp-0009", { date: DATE })];
    expect(pickDaily(all, { ...NONE, killed_problem_ids: ["vp-0009"] }, DATE)?.id).not.toBe("vp-0009");
  });

  it("never picks the warm-up, even if it is dated for the day", () => {
    const all = [p("vp-0000", { date: DATE, collections: ["practice"] }), ...pool];
    expect(pickDaily(all, NONE, DATE)?.id).not.toBe("vp-0000");
  });

  it("without a pointer picks pool[dayNumber % pool.length] over the id-sorted pool", () => {
    const sorted = ["vp-0001", "vp-0002", "vp-0003"];
    expect(pickDaily(pool, NONE, DATE)?.id).toBe(sorted[dayNumber(DATE) % 3]);
    expect(pickDaily(pool, NONE, "2026-10-07")?.id).toBe(sorted[dayNumber("2026-10-07") % 3]);
  });

  describe("rotation pointer", () => {
    const rot = (start: string, anchor: string) => ({ ...NONE, rotation: { start_problem_id: start, anchor_date: anchor } });

    it("on the anchor day serves the start problem", () => {
      expect(pickDaily(pool, rot("vp-0002", DATE), DATE)?.id).toBe("vp-0002");
    });

    it("advances one problem per day", () => {
      expect(pickDaily(pool, rot("vp-0002", DATE), "2026-10-07")?.id).toBe("vp-0003");
    });

    it("wraps around the pool", () => {
      expect(pickDaily(pool, rot("vp-0003", DATE), "2026-10-07")?.id).toBe("vp-0001");
    });

    it("an unknown start id starts at index 0", () => {
      expect(pickDaily(pool, rot("vp-0777", DATE), DATE)?.id).toBe("vp-0001");
    });

    it("an anchor in the future clamps to zero elapsed days", () => {
      expect(pickDaily(pool, rot("vp-0002", "2027-01-01"), DATE)?.id).toBe("vp-0002");
    });

    it("an unparseable anchor means zero elapsed days", () => {
      expect(pickDaily(pool, rot("vp-0002", "not-a-date"), DATE)?.id).toBe("vp-0002");
    });

    it("a dated problem still beats the pointer", () => {
      const all = [...pool, p("vp-0009", { date: DATE })];
      expect(pickDaily(all, rot("vp-0002", DATE), DATE)?.id).toBe("vp-0009");
    });
  });

  it("returns null when every candidate is killed", () => {
    expect(pickDaily(pool, { ...NONE, killed_problem_ids: pool.map((x) => x.id) }, DATE)).toBeNull();
  });

  it("returns null for an empty catalogue", () => {
    expect(pickDaily([], NONE, DATE)).toBeNull();
  });
});
