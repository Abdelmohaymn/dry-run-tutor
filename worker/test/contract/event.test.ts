import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { mintInstallId } from "./helpers";

async function sendEvents(installId: string, events: unknown[]) {
  return SELF.fetch("https://worker.test/v1/event", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ events }),
  });
}

async function eventCountFor(installId: string): Promise<number> {
  const bareInstallId = installId.split(".")[0];
  const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM events WHERE install_id = ?1")
    .bind(bareInstallId)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

// US6 scenario 4.
describe("POST /v1/event", () => {
  it("a valid batch is accepted with 202 and is queryable", async () => {
    const installId = await mintInstallId();
    const res = await sendEvents(installId, [
      { name: "app_open", client_ts: "2026-08-21T00:00:00.000Z" },
      { name: "hint_revealed", client_ts: "2026-08-21T00:01:00.000Z", props: { problem_id: "vp-0001" } },
    ]);
    expect(res.status).toBe(202);
    expect(await eventCountFor(installId)).toBe(2);
  });

  it("a nested value in props is rejected with BAD_REQUEST and nothing is inserted", async () => {
    const installId = await mintInstallId();
    const res = await sendEvents(installId, [
      { name: "app_open", client_ts: "2026-08-21T00:00:00.000Z", props: { nested: { a: 1 } } },
    ]);
    expect(res.status).toBe(400);
    expect(await eventCountFor(installId)).toBe(0);
  });

  it("a 13th prop key is rejected with BAD_REQUEST and nothing is inserted", async () => {
    const installId = await mintInstallId();
    const props: Record<string, string> = {};
    for (let i = 0; i < 13; i++) props[`k${i}`] = "v";
    const res = await sendEvents(installId, [
      { name: "app_open", client_ts: "2026-08-21T00:00:00.000Z", props },
    ]);
    expect(res.status).toBe(400);
    expect(await eventCountFor(installId)).toBe(0);
  });

  it("a 65-char string prop value is rejected with BAD_REQUEST and nothing is inserted", async () => {
    const installId = await mintInstallId();
    const res = await sendEvents(installId, [
      { name: "app_open", client_ts: "2026-08-21T00:00:00.000Z", props: { long: "x".repeat(65) } },
    ]);
    expect(res.status).toBe(400);
    expect(await eventCountFor(installId)).toBe(0);
  });

  it("an unknown event name is rejected with BAD_REQUEST and nothing is inserted", async () => {
    const installId = await mintInstallId();
    const res = await sendEvents(installId, [
      { name: "not_a_real_event", client_ts: "2026-08-21T00:00:00.000Z" },
    ]);
    expect(res.status).toBe(400);
    expect(await eventCountFor(installId)).toBe(0);
  });

  it("a batch containing one bad event rejects the WHOLE batch — nothing is silently trimmed", async () => {
    const installId = await mintInstallId();
    const res = await sendEvents(installId, [
      { name: "app_open", client_ts: "2026-08-21T00:00:00.000Z" },
      { name: "not_a_real_event", client_ts: "2026-08-21T00:00:01.000Z" },
    ]);
    expect(res.status).toBe(400);
    expect(await eventCountFor(installId)).toBe(0);
  });
});
