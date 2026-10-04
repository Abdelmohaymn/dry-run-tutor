import { describe, expect, it } from "vitest";
import { withinMs } from "../../src/lib/finish-check";

describe("withinMs", () => {
  it("passes through a check that settles in time", async () => {
    expect(await withinMs(Promise.resolve(true), 1000)).toBe(true);
  });

  it("resolves false when the check is still running at the deadline", async () => {
    const never = new Promise<boolean>(() => {});
    expect(await withinMs(never, 10)).toBe(false);
  });
});
