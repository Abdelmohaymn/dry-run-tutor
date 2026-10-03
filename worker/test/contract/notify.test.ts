import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, beforeEach, describe, expect, it } from "vitest";
import { setWebConfig } from "./helpers";

const ORIGIN = "https://site.test";
const TURNSTILE_ORIGIN = "https://challenges.cloudflare.com";
const TURNSTILE_PATH = "/turnstile/v0/siteverify";
const DUMMY_TOKEN = "XXXX.DUMMY.TOKEN.XXXX";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

// The real local WEB_EVENT_RL binding is shared across every case in this
// file under the same "unknown" IP key. Default it to always-succeed; the
// one test that means to hit the limit overrides it itself.
beforeEach(() => {
  env.WEB_EVENT_RL.limit = async () => ({ success: true });
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function mockTurnstile(success: boolean) {
  fetchMock
    .get(TURNSTILE_ORIGIN)
    .intercept({ path: TURNSTILE_PATH, method: "POST" })
    .reply(200, JSON.stringify({ success, action: success ? "notify" : undefined }), {
      headers: { "content-type": "application/json" },
    });
}

function notify(body: Record<string, unknown>, origin: string = ORIGIN) {
  return SELF.fetch("https://worker.test/v1/notify", {
    method: "POST",
    headers: { Origin: origin, "content-type": "application/json" },
    body: JSON.stringify({ turnstile_token: DUMMY_TOKEN, ...body }),
  });
}

async function signupRows(): Promise<{ email: string; store: string }[]> {
  const { results } = await env.DB.prepare(
    "SELECT email, store FROM notify_signup ORDER BY store",
  ).all<{ email: string; store: string }>();
  return results;
}

describe("POST /v1/notify", () => {
  it("202s and stores the trimmed, lower-cased email with its store", async () => {
    await setWebConfig();
    mockTurnstile(true);
    const res = await notify({ email: " Test@Example.com ", store: "app_store" });
    expect(res.status).toBe(202);
    expect(await res.json()).toEqual({ ok: true });
    expect(await signupRows()).toEqual([{ email: "test@example.com", store: "app_store" }]);
  });

  it("202s a duplicate signup and still keeps one row", async () => {
    await setWebConfig();
    mockTurnstile(true);
    mockTurnstile(true);
    const first = await notify({ email: " Test@Example.com ", store: "app_store" });
    expect(first.status).toBe(202);
    const second = await notify({ email: " Test@Example.com ", store: "app_store" });
    expect(second.status).toBe(202);
    expect(await signupRows()).toHaveLength(1);
  });

  it("stores a second row for the same email on the other store", async () => {
    await setWebConfig();
    mockTurnstile(true);
    mockTurnstile(true);
    await notify({ email: " Test@Example.com ", store: "app_store" });
    const res = await notify({ email: " Test@Example.com ", store: "play" });
    expect(res.status).toBe(202);
    expect(await signupRows()).toEqual([
      { email: "test@example.com", store: "app_store" },
      { email: "test@example.com", store: "play" },
    ]);
  });

  it.each([
    ["bad@", "app_store", true],
    ["a b@c.de", "app_store", true],
    [`${"a".repeat(243)}@example.com`, "app_store", false],
    ["test@example.com", "windows", false],
  ])("400s email %j with store %j", async (email, store, reachesTurnstile) => {
    await setWebConfig();
    if (reachesTurnstile) mockTurnstile(true);
    const res = await notify({ email, store });
    expect(res.status).toBe(400);
    expect(await signupRows()).toHaveLength(0);
  });

  it("403s when siteverify says success: false", async () => {
    await setWebConfig();
    mockTurnstile(false);
    const res = await notify({ email: "test@example.com", store: "play" });
    expect(res.status).toBe(403);
    expect(await signupRows()).toHaveLength(0);
  });

  it("503s when web.notify_enabled is false, with no Turnstile call", async () => {
    await setWebConfig({ notify_enabled: false });
    const res = await notify({ email: "test@example.com", store: "play" });
    expect(res.status).toBe(503);
  });

  it("403s an unknown origin, with no Turnstile call", async () => {
    await setWebConfig();
    const res = await notify({ email: "test@example.com", store: "play" }, "https://evil.test");
    expect(res.status).toBe(403);
  });

  it("429s when WEB_EVENT_RL.limit refuses, with no Turnstile call", async () => {
    await setWebConfig();
    env.WEB_EVENT_RL.limit = async () => ({ success: false });
    const res = await notify({ email: "test@example.com", store: "play" });
    expect(res.status).toBe(429);
  });

  it("notify_signup holds only email, store and created_at", async () => {
    const { results } = await env.DB.prepare("PRAGMA table_info(notify_signup)").all<{ name: string }>();
    expect(results.map((r) => r.name).sort()).toEqual(["created_at", "email", "store"]);
  });
});
