import { describe, expect, it } from "vitest";
import { assertNoPrivateLeak } from "../../../tools/build-content";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import type { Problem } from "../../../tools/problem-types";

// FR-028, SC-014. Re-runs the assertion over the BUILT manifest so it gates
// CI even when the build is cached, per data-model.md §B5.
describe("assertNoPrivateLeak() over the built manifest", () => {
  it("finds no private key name and no verbatim private content reachable from the built public manifest", () => {
    const manifest = getPublicManifest();
    const problems: Problem[] = manifest.problems.map((pub) => ({
      public: pub,
      private: getPrivate(pub.id)!,
    }));

    const result = assertNoPrivateLeak(manifest, problems);
    expect(result.failures).toEqual([]);
    expect(result.ok).toBe(true);
  });

  it("catches a deliberately reintroduced leak — the key-name blacklist", () => {
    const manifest = getPublicManifest();
    const problems: Problem[] = manifest.problems.map((pub) => ({
      public: pub,
      private: getPrivate(pub.id)!,
    }));
    const leaking = { ...manifest, leaked: { editorial: "oops" } };

    const result = assertNoPrivateLeak(leaking, problems);
    expect(result.ok).toBe(false);
    expect(result.failures.some((f) => f.includes("editorial"))).toBe(true);
  });

  it("catches a deliberately reintroduced leak — verbatim sketch content", () => {
    const manifest = getPublicManifest();
    const problems: Problem[] = manifest.problems.map((pub) => ({
      public: pub,
      private: getPrivate(pub.id)!,
    }));
    const sketchLine = problems[0].private.reference_approaches[0].sketch[0];
    const leaking = { ...manifest, leaked_sketch: sketchLine };

    const result = assertNoPrivateLeak(leaking, problems);
    expect(result.ok).toBe(false);
    expect(result.failures.some((f) => f.includes("sketch"))).toBe(true);
  });
});
