import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getPrivate } from "../../src/lib/content";

describe("GET /v1/practice", () => {
  it("serves the warm-up with no install header, cacheable for an hour", async () => {
    const res = await SELF.fetch("https://worker.test/v1/practice");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toBe("public, max-age=3600");
    const body = (await res.json()) as { problem: { id: string; collections: string[] } };
    expect(body.problem.collections).toContain("practice");
  });

  it("carries no private field and no editorial text", async () => {
    const body = (await (await SELF.fetch("https://worker.test/v1/practice")).json()) as { problem: { id: string } };
    const text = JSON.stringify(body);
    for (const key of ["reference_approaches", "key_insights", "common_wrong_turns", "editorial", "never_say", "hints"]) {
      expect(text).not.toContain(`"${key}"`);
    }
    expect(text).not.toContain(getPrivate(body.problem.id)!.editorial.slice(0, 80));
  });

  it("409 PROBLEM_KILLED when the warm-up is withdrawn", async () => {
    const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
    const cfg = JSON.parse(row!.payload);
    const ok = (await (await SELF.fetch("https://worker.test/v1/practice")).json()) as { problem: { id: string } };
    cfg.killed_problem_ids = [ok.problem.id];
    await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();

    const res = await SELF.fetch("https://worker.test/v1/practice");
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: { code: string } }).error.code).toBe("PROBLEM_KILLED");
  });
});
