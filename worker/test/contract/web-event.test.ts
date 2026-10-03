import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { setWebConfig } from "./helpers";

const ORIGIN = "https://site.test";

async function sendWebEvent(
  events: unknown[],
  opts: { origin?: string; contentType?: string } = {},
) {
  return SELF.fetch("https://worker.test/v1/web-event", {
    method: "POST",
    headers: {
      Origin: opts.origin ?? ORIGIN,
      "content-type": opts.contentType ?? "application/json",
    },
    body: JSON.stringify({ events }),
  });
}

async function webEventCount(name: string): Promise<number> {
  const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM events WHERE install_id = 'web' AND name = ?1")
    .bind(name)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

const WEB_EVENT_NAMES = [
  "web_page_view",
  "web_download_tapped",
] as const;

describe("POST /v1/web-event", () => {
  it.each(WEB_EVENT_NAMES)("%s is accepted with 202 and lands as install_id='web'", async (name) => {
    await setWebConfig();
    const props = name === "web_download_tapped" ? { store: "uptodown" } : undefined;
    const res = await sendWebEvent([
      { name, client_ts: "2026-09-25T00:00:00.000Z", ...(props ? { props } : {}) },
    ]);
    expect(res.status).toBe(202);
    expect(await webEventCount(name)).toBe(1);
  });

  it("rejects the app-only event session_ended with 400", async () => {
    await setWebConfig();
    const res = await sendWebEvent([{ name: "session_ended", client_ts: "2026-09-25T00:00:00.000Z" }]);
    expect(res.status).toBe(400);
  });

  it("rejects an unexpected prop with 400", async () => {
    await setWebConfig();
    const res = await sendWebEvent([
      { name: "web_try_tapped", client_ts: "2026-09-25T00:00:00.000Z", props: { x: 1 } },
    ]);
    expect(res.status).toBe(400);
  });

  it("403s an unknown origin", async () => {
    await setWebConfig();
    const res = await sendWebEvent(
      [{ name: "web_page_view", client_ts: "2026-09-25T00:00:00.000Z" }],
      { origin: "https://evil.test" },
    );
    expect(res.status).toBe(403);
  });

  it("accepts a text/plain body (sendBeacon) with valid JSON", async () => {
    await setWebConfig();
    const res = await sendWebEvent(
      [{ name: "web_page_view", client_ts: "2026-09-25T00:00:00.000Z" }],
      { contentType: "text/plain" },
    );
    expect(res.status).toBe(202);
  });

  it("429s when WEB_EVENT_RL.limit refuses", async () => {
    await setWebConfig();
    const original = env.WEB_EVENT_RL.limit.bind(env.WEB_EVENT_RL);
    env.WEB_EVENT_RL.limit = async () => ({ success: false });
    try {
      const res = await sendWebEvent([{ name: "web_page_view", client_ts: "2026-09-25T00:00:00.000Z" }]);
      expect(res.status).toBe(429);
    } finally {
      env.WEB_EVENT_RL.limit = original;
    }
  });
});
