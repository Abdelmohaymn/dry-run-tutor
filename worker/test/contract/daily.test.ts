import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { mintInstallId } from "./helpers";

const DAY = 86_400_000;
const dateOffset = (days: number) => new Date(Date.now() + days * DAY).toISOString().slice(0, 10);
const TODAY = dateOffset(0);

function daily(installId: string | null, date: string | null) {
  const url = date === null ? "https://worker.test/v1/daily" : `https://worker.test/v1/daily?date=${date}`;
  return SELF.fetch(url, { headers: installId ? { "X-Install-Id": installId } : {} });
}

async function killEverything(): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  const cfg = JSON.parse(row!.payload);
  cfg.killed_problem_ids = getPublicManifest().problems.map((x) => x.id);
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();
}

describe("GET /v1/daily", () => {
  it("400 without an install header, and with a legacy uuid token", async () => {
    expect((await daily(null, TODAY)).status).toBe(400);
    expect((await daily("3f1c2a4e-5b6d-4e7f-89ab-1234567890ab.AAAA", TODAY)).status).toBe(400);
  });

  it("200 { date, problem } for today, never cached", async () => {
    const res = await daily(await mintInstallId(), TODAY);
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toContain("no-store");
    const body = (await res.json()) as { date: string; problem: { id: string; statement: string } };
    expect(body.date).toBe(TODAY);
    expect(body.problem.id).toMatch(/^vp-\d{4}$/);
    expect(getPublicManifest().problems.map((x) => x.id)).toContain(body.problem.id);
  });

  it("two devices asking for the same date get the same problem", async () => {
    const a = (await (await daily(await mintInstallId(), TODAY)).json()) as { problem: { id: string } };
    const b = (await (await daily(await mintInstallId(), TODAY)).json()) as { problem: { id: string } };
    expect(a.problem.id).toBe(b.problem.id);
  });

  it("accepts ±1 day and refuses ±2 days", async () => {
    const id = await mintInstallId();
    expect((await daily(id, dateOffset(1))).status).toBe(200);
    expect((await daily(id, dateOffset(-1))).status).toBe(200);
    const ahead = await daily(id, dateOffset(2));
    expect(ahead.status).toBe(400);
    expect(((await ahead.json()) as { error: { code: string } }).error.code).toBe("BAD_REQUEST");
    expect((await daily(id, dateOffset(-2))).status).toBe(400);
  });

  it("400 for a malformed or missing date", async () => {
    const id = await mintInstallId();
    for (const bad of ["2026-13-01", "abc", "2026-02-30", null]) {
      expect((await daily(id, bad)).status, String(bad)).toBe(400);
    }
  });

  it("writes one device_day row with zero counters, and never resets them", async () => {
    const id = await mintInstallId();
    const hash = id.split(".")[0];
    const body = (await (await daily(id, TODAY)).json()) as { problem: { id: string } };

    const row = await env.DB.prepare("SELECT * FROM device_day WHERE device_hash = ?1 AND date = ?2")
      .bind(hash, TODAY)
      .first<Record<string, unknown>>();
    expect(row).toMatchObject({ problem_id: body.problem.id, turns: 0, solution_requests: 0, hints_revealed: 0, judged_at: null });

    await env.DB.prepare("UPDATE device_day SET turns = 3 WHERE device_hash = ?1 AND date = ?2").bind(hash, TODAY).run();
    await daily(id, TODAY);
    const rows = await env.DB.prepare("SELECT turns FROM device_day WHERE device_hash = ?1 AND date = ?2")
      .bind(hash, TODAY)
      .all<{ turns: number }>();
    expect(rows.results).toEqual([{ turns: 3 }]);
  });

  it("409 PROBLEM_KILLED when every problem is withdrawn", async () => {
    await killEverything();
    const res = await daily(await mintInstallId(), TODAY);
    expect(res.status).toBe(409);
    expect(((await res.json()) as { error: { code: string } }).error.code).toBe("PROBLEM_KILLED");
  });

  it("serves the public half only: no private key names, no editorial text", async () => {
    const res = await daily(await mintInstallId(), TODAY);
    const body = (await res.json()) as { problem: { id: string } };
    const text = JSON.stringify(body);
    for (const key of [
      "reference_approaches", "key_insights", "common_wrong_turns", "edge_cases", "followups",
      "editorial", "hints", "never_say", "counter_question", "failing_case", "why_it_fails",
      "model_answer", "grading_note", "sketch",
    ]) {
      expect(text).not.toContain(`"${key}"`);
    }
    expect(text).not.toContain(getPrivate(body.problem.id)!.editorial.slice(0, 80));
  });
});
