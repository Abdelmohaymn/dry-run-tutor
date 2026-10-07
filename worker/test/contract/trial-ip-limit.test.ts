import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { hashIp } from "../../src/lib/trial-pool";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const IP = "203.0.113.7";

function randomHash(): string {
  return (crypto.randomUUID() + crypto.randomUUID()).replace(/-/g, "").slice(0, 64);
}

/** Seeds `n` sessions already started today from `ip` by other devices. */
async function seedSessions(ip: string, n: number) {
  const ipHash = await hashIp(ip, env.INSTALL_HMAC_SECRET);
  const date = new Date().toISOString().slice(0, 10);
  for (let i = 0; i < n; i++) {
    await env.DB.prepare(
      "INSERT INTO devices (device_hash, created_at, trial_started_at, trial_problem_id, trial_date, trial_ip_hash, trial_day_date, trial_day_sessions) VALUES (?1, ?2, ?2, 'vp-0001', ?3, ?4, ?3, 1)",
    )
      .bind(randomHash(), new Date().toISOString(), date, ipHash)
      .run();
  }
}

function startTrial(installId: string, ip: string) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "CF-Connecting-IP": ip, "content-type": "application/json" },
    body: JSON.stringify({ mode: "chat", problem_id: "vp-0001", messages: [{ role: "user", text: "hello" }] }),
  });
}

describe("POST /v1/trial — per-network daily session cap", () => {
  it("refuses a NEW session with 429 TRIAL_IP_LIMIT once the network has started 15 today, before any provider call", async () => {
    await seedSessions(IP, 15);

    const res = await startTrial(await mintInstallId(), IP);

    expect(res.status).toBe(429);
    const body = (await res.json()) as any;
    expect(body.error.code).toBe("TRIAL_IP_LIMIT");
    expect(body.error.retryable).toBe(false);
  });

  it("still serves a new session from another network, and records it against that network", async () => {
    await seedSessions(IP, 15);
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What would you try first?"), { headers: { "content-type": "text/event-stream" } });

    const other = "198.51.100.9";
    const res = await startTrial(await mintInstallId(), other);
    expect(res.status).toBe(200);
    await readChatSSE(res);

    const otherHash = await hashIp(other, env.INSTALL_HMAC_SECRET);
    const row = await env.DB.prepare("SELECT COUNT(*) AS n FROM devices WHERE trial_ip_hash = ?1")
      .bind(otherHash)
      .first<{ n: number }>();
    expect(row?.n).toBe(1);
  });

  it("never stores the raw IP", async () => {
    await seedSessions(IP, 1);
    const rows = await env.DB.prepare("SELECT trial_ip_hash FROM devices WHERE trial_ip_hash IS NOT NULL").all<{
      trial_ip_hash: string;
    }>();
    for (const r of rows.results) expect(r.trial_ip_hash).not.toContain(IP);
  });

  it("counts an IPv6 network by its /64: a neighbour address is refused, another /64 is served", async () => {
    await seedSessions("2a02:c7c:1234:5678::1", 15);

    const sameNet = await startTrial(await mintInstallId(), "2a02:c7c:1234:5678::99");
    expect(sameNet.status).toBe(429);
    expect(((await sameNet.json()) as any).error.code).toBe("TRIAL_IP_LIMIT");

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("What would you try first?"), { headers: { "content-type": "text/event-stream" } });
    const otherNet = await startTrial(await mintInstallId(), "2a02:c7c:1234:9999::1");
    expect(otherNet.status).toBe(200);
    await readChatSSE(otherNet);
  });
});
