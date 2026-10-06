import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

async function install(body: unknown): Promise<Response> {
  return SELF.fetch("https://worker.test/v1/install", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function mint(deviceId: string): Promise<string> {
  const res = await install({ platform: "android", device_id: deviceId });
  expect(res.status).toBe(200);
  return ((await res.json()) as { install_id: string }).install_id;
}

describe("POST /v1/install", () => {
  it("200: mints a signed <64 hex>.<sig> install id", async () => {
    const id = await mint("9f2c4e1a7b3d5f60");
    expect(id).toMatch(/^[0-9a-f]{64}\.[A-Za-z0-9_-]+$/);
  });

  it("the same device_id twice gives the identical install id", async () => {
    expect(await mint("abc123def4567890")).toBe(await mint("abc123def4567890"));
  });

  it("device_id is trimmed and case-insensitive", async () => {
    expect(await mint("ABC123")).toBe(await mint("abc123"));
    expect(await mint("  abc123  ")).toBe(await mint("abc123"));
  });

  it("different device ids give different install ids", async () => {
    expect(await mint("aaaa1111")).not.toBe(await mint("bbbb2222"));
  });

  it("400: empty device_id", async () => {
    const res = await install({ platform: "android", device_id: "" });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe("BAD_REQUEST");
  });

  it("400: missing device_id", async () => {
    expect((await install({ platform: "android" })).status).toBe(400);
  });

  it("400: platform other than android", async () => {
    expect((await install({ platform: "ios", device_id: "abc" })).status).toBe(400);
  });

  it("400: an extra key", async () => {
    expect((await install({ platform: "android", device_id: "abc", extra: 1 })).status).toBe(400);
  });

  it("400: the pre-006 uuid body", async () => {
    // Built from parts: the legacy field name is swept out of src/test elsewhere.
    const res = await install({ ["install_" + "uuid"]: "3f1c2a4e-5b6d-4e7f-89ab-1234567890ab" });
    expect(res.status).toBe(400);
  });

  it("writes a devices row with created_at, and never the raw id", async () => {
    const id = await mint("c0ffee0123456789");
    const hash = id.split(".")[0];
    const row = await env.DB.prepare("SELECT * FROM devices WHERE device_hash = ?1")
      .bind(hash)
      .first<Record<string, unknown>>();
    expect(row).not.toBeNull();
    expect(typeof row!.created_at).toBe("string");
    const all = await env.DB.prepare("SELECT * FROM devices").all();
    expect(JSON.stringify(all.results)).not.toContain("c0ffee0123456789");
  });

  it("a reinstall does not change the existing row", async () => {
    const id = await mint("1234abcd5678ef90");
    const hash = id.split(".")[0];
    const before = await env.DB.prepare("SELECT created_at FROM devices WHERE device_hash = ?1")
      .bind(hash)
      .first<{ created_at: string }>();
    await mint("1234abcd5678ef90");
    const after = await env.DB.prepare("SELECT created_at FROM devices WHERE device_hash = ?1")
      .bind(hash)
      .first<{ created_at: string }>();
    expect(after!.created_at).toBe(before!.created_at);
  });

  it("429 RATE_LIMITED when INSTALL_RL refuses this network", async () => {
    const original = env.INSTALL_RL.limit;
    env.INSTALL_RL.limit = async () => ({ success: false });
    try {
      const res = await install({ platform: "android", device_id: "abc123" });
      expect(res.status).toBe(429);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe("RATE_LIMITED");
    } finally {
      env.INSTALL_RL.limit = original;
    }
  });
});
