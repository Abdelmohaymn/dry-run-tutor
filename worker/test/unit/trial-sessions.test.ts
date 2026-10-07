import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import {
  countSessionsStartedToday,
  markTrialStarted,
  releaseTrialStart,
} from "../../src/lib/trial-pool";

const TODAY = "2031-02-03";
const IP = "ip-hash-trial-sessions";

let counter = 0;
function freshDevice(): string {
  counter += 1;
  return `trial-sessions-${counter}-${crypto.randomUUID()}`;
}

function startedAt(n: number): string {
  return `${TODAY}T10:00:0${n}.000Z`;
}

async function ipSessions(ipHash: string, date: string): Promise<number> {
  const row = await env.DB.prepare(
    "SELECT COALESCE(SUM(trial_day_sessions), 0) AS n FROM devices WHERE trial_ip_hash = ?1 AND trial_day_date = ?2",
  )
    .bind(ipHash, date)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

describe("markTrialStarted() and the daily caps", () => {
  it("counts every session a device starts today, not the device once", async () => {
    const before = await countSessionsStartedToday(env.DB, TODAY);
    const id = freshDevice();

    expect(await markTrialStarted(env.DB, id, startedAt(1), "vp-0001", TODAY, IP, 5)).toBe(true);
    expect(await markTrialStarted(env.DB, id, startedAt(2), "vp-0002", TODAY, IP, 5)).toBe(true);
    expect(await markTrialStarted(env.DB, id, startedAt(3), "vp-0003", TODAY, IP, 5)).toBe(true);

    expect(await countSessionsStartedToday(env.DB, TODAY)).toBe(before + 3);
    expect(await ipSessions(IP, TODAY)).toBeGreaterThanOrEqual(3);
  });

  it("a later turn of the session in flight counts nothing extra", async () => {
    const ip = `${IP}-inflight`;
    const id = freshDevice();
    await markTrialStarted(env.DB, id, startedAt(1), "vp-0001", TODAY, ip, 5);

    expect(await markTrialStarted(env.DB, id, startedAt(2), "vp-0001", TODAY, ip, 5)).toBe(true);
    expect(await ipSessions(ip, TODAY)).toBe(1);
  });

  it("a start the provider never answered is taken back, and earlier ones still count", async () => {
    const ip = `${IP}-release`;
    const id = freshDevice();
    await markTrialStarted(env.DB, id, startedAt(1), "vp-0001", TODAY, ip, 5);
    await markTrialStarted(env.DB, id, startedAt(2), "vp-0002", TODAY, ip, 5);

    await releaseTrialStart(env.DB, id, startedAt(2));

    expect(await ipSessions(ip, TODAY)).toBe(1);
  });

  it("returns false when another request already took the device's last session", async () => {
    const id = freshDevice();
    // sessions_per_device 2: A, then B wins the race for the second slot.
    await markTrialStarted(env.DB, id, startedAt(1), "vp-0001", TODAY, IP, 2);
    expect(await markTrialStarted(env.DB, id, startedAt(2), "vp-0002", TODAY, IP, 2)).toBe(true);

    // C passed the route's check on the stale row (A only) before B wrote.
    expect(await markTrialStarted(env.DB, id, startedAt(3), "vp-0003", TODAY, IP, 2)).toBe(false);

    const row = await env.DB.prepare(
      "SELECT trial_problem_id, trial_sessions_done FROM devices WHERE device_hash = ?1",
    )
      .bind(id)
      .first<{ trial_problem_id: string; trial_sessions_done: number }>();
    expect(row).toEqual({ trial_problem_id: "vp-0002", trial_sessions_done: 1 });
  });

  it("returns false for a second problem racing the very first start", async () => {
    const id = freshDevice();
    expect(await markTrialStarted(env.DB, id, startedAt(1), "vp-0001", TODAY, IP, 1)).toBe(true);
    expect(await markTrialStarted(env.DB, id, startedAt(2), "vp-0002", TODAY, IP, 1)).toBe(false);
  });
});
