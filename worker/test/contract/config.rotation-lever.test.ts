import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

async function putRotation(rotation: unknown): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  if (rotation === undefined) {
    delete cfg.rotation;
  } else {
    cfg.rotation = rotation;
  }
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

async function served(): Promise<any> {
  return (await (await SELF.fetch("https://worker.test/v1/config")).json()) as any;
}

// FR-035d. An invalid pointer never reaches an install: getRuntimeConfig
// throws on a payload that fails the schema and the route surfaces 502,
// so a typo is a loud relay error rather than a silently wrong problem
// on every device.
//
// The pointer itself is evaluated on the device — the relay's
// whole job here is to carry the two numbers verbatim and to refuse a
// pair it cannot carry, because an invalid pointer served to every
// install is the one failure that cannot be walked back with a release.
describe("GET /v1/config — the rotation pointer", () => {
  it("is absent by default, which is the per-install behaviour", async () => {
    await putRotation(undefined);
    expect((await served()).rotation).toBeUndefined();
  });

  it("is served verbatim once set, with no redeploy", async () => {
    await putRotation({ start_problem_id: "vp-0000", anchor_date: "2026-09-18" });
    expect((await served()).rotation).toEqual({
      start_problem_id: "vp-0000",
      anchor_date: "2026-09-18",
    });
  });

  it("moving the pointer back is one write", async () => {
    await putRotation({ start_problem_id: "vp-0042", anchor_date: "2026-09-18" });
    await env.DB.prepare(
      "UPDATE config SET payload = json_set(payload, '$.rotation.start_problem_id', 'vp-0000', '$.rotation.anchor_date', '2026-10-01')",
    ).run();

    expect((await served()).rotation).toEqual({
      start_problem_id: "vp-0000",
      anchor_date: "2026-10-01",
    });
  });

  it("refuses a malformed problem id rather than serving it", async () => {
    await putRotation({ start_problem_id: "vp-1", anchor_date: "2026-09-18" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
  });

  it("refuses a malformed anchor date rather than serving it", async () => {
    await putRotation({ start_problem_id: "vp-0000", anchor_date: "18-09-2026" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
  });

  it("refuses a half-written pointer rather than serving it", async () => {
    await putRotation({ start_problem_id: "vp-0000" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
    await putRotation(undefined);
  });
});
