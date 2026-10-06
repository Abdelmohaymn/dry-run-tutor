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

// FR-035d. An invalid pointer never reaches the server's pick:
// getRuntimeConfig throws on a payload that fails the schema and the route
// surfaces 502, so a typo is a loud relay error rather than a silently wrong
// problem for every device.
//
// Since 006 the pointer is applied by GET /v1/daily (see daily-pick.test.ts)
// and is never served to the app.
describe("GET /v1/config — the rotation pointer", () => {
  it("is never served, whether absent or set", async () => {
    await putRotation(undefined);
    expect((await served()).rotation).toBeUndefined();

    await putRotation({ start_problem_id: "vp-0000", anchor_date: "2026-09-18" });
    expect((await served()).rotation).toBeUndefined();
    await putRotation(undefined);
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
