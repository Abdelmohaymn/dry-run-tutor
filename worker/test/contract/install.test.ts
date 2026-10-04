import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

describe("POST /v1/install", () => {
  it("200: mints a signed install id for a valid uuid", async () => {
    const res = await SELF.fetch("https://worker.test/v1/install", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ install_uuid: "3f1c2a4e-5b6d-4e7f-89ab-1234567890ab" }),
    });
    expect(res.status).toBe(200);
    const body = (await res.json()) as { install_id: string };
    expect(body.install_id).toMatch(/^3f1c2a4e-5b6d-4e7f-89ab-1234567890ab\.[A-Za-z0-9_-]+$/);
  });

  it("400: rejects a non-uuid install_uuid", async () => {
    const res = await SELF.fetch("https://worker.test/v1/install", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ install_uuid: "not-a-uuid" }),
    });
    expect(res.status).toBe(400);
    const body = (await res.json()) as { error: { code: string } };
    expect(body.error.code).toBe("BAD_REQUEST");
  });

  it("400: rejects a missing body field", async () => {
    const res = await SELF.fetch("https://worker.test/v1/install", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(400);
  });

  it("429 RATE_LIMITED when INSTALL_RL refuses this IP", async () => {
    const original = env.INSTALL_RL.limit;
    env.INSTALL_RL.limit = async () => ({ success: false });
    try {
      const res = await SELF.fetch("https://worker.test/v1/install", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ install_uuid: "3f1c2a4e-5b6d-4e7f-89ab-1234567890ab" }),
      });
      expect(res.status).toBe(429);
      const body = (await res.json()) as { error: { code: string } };
      expect(body.error.code).toBe("RATE_LIMITED");
    } finally {
      env.INSTALL_RL.limit = original;
    }
  });
});
