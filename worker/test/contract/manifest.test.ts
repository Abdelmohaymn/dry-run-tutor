import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";

// US3 scenarios 1, 4.
describe("GET /v1/content/manifest.json", () => {
  it("serves only public fields, dated entries, and no private key name or content is reachable", async () => {
    const res = await SELF.fetch("https://worker.test/v1/content/manifest.json");
    expect(res.status).toBe(200);
    const body = (await res.json()) as any;

    expect(body.schema_version).toBe(2);
    expect(typeof body.generated).toBe("string");
    expect(Array.isArray(body.problems)).toBe(true);
    expect(body.problems.length).toBe(getPublicManifest().problems.length);

    const bodyText = JSON.stringify(body);
    const privateKeys = [
      "reference_approaches",
      "key_insights",
      "common_wrong_turns",
      "edge_cases",
      "followups",
      "editorial",
      "hints",
      "never_say",
      "counter_question",
      "failing_case",
      "why_it_fails",
      "model_answer",
      "grading_note",
      "sketch",
    ];
    for (const key of privateKeys) {
      expect(bodyText).not.toContain(`"${key}"`);
    }

    for (const pub of body.problems) {
      const priv = getPrivate(pub.id)!;
      expect(bodyText).not.toContain(priv.editorial.slice(0, 80));
      // Each entry is dated for prefetch.
      expect(typeof pub.title).toBe("string");
    }
  });
});
