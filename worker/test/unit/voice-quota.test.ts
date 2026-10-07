import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import {
  getVoiceSecondsUsed,
  reserveVoiceSeconds,
  settleVoiceSeconds,
  voiceSecondsLeft,
} from "../../src/lib/voice-quota";

const TODAY = "2026-10-07";
const YESTERDAY = "2026-10-06";
const CAP = 300;
const CREATED_AT = "2026-10-07T00:00:00.000Z";

let counter = 0;
function freshDevice(): string {
  counter += 1;
  return `voice-device-${counter}-${Date.now()}`;
}

async function seedDevice(
  deviceHash: string,
  voiceDate: string | null,
  voiceSeconds: number,
): Promise<void> {
  await env.DB.prepare(
    "INSERT INTO devices (device_hash, created_at, voice_date, voice_seconds) VALUES (?1, ?2, ?3, ?4)",
  )
    .bind(deviceHash, CREATED_AT, voiceDate, voiceSeconds)
    .run();
}

async function storedRow(
  deviceHash: string,
): Promise<{ voice_date: string | null; voice_seconds: number } | null> {
  return env.DB.prepare("SELECT voice_date, voice_seconds FROM devices WHERE device_hash = ?1")
    .bind(deviceHash)
    .first<{ voice_date: string | null; voice_seconds: number }>();
}

describe("getVoiceSecondsUsed()", () => {
  it("returns 0 when the device has no row", async () => {
    expect(await getVoiceSecondsUsed(env.DB, freshDevice(), TODAY)).toBe(0);
  });

  it("returns 0 when voice_date is NULL", async () => {
    const id = freshDevice();
    await seedDevice(id, null, 0);
    expect(await getVoiceSecondsUsed(env.DB, id, TODAY)).toBe(0);
  });

  it("returns 0 when voice_date is yesterday, even with a stale non-zero count", async () => {
    const id = freshDevice();
    await seedDevice(id, YESTERDAY, 250);
    expect(await getVoiceSecondsUsed(env.DB, id, TODAY)).toBe(0);
  });

  it("returns the stored count when voice_date is today", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, 42);
    expect(await getVoiceSecondsUsed(env.DB, id, TODAY)).toBe(42);
  });
});

describe("voiceSecondsLeft()", () => {
  it("returns cap minus used", () => {
    expect(voiceSecondsLeft(300, 100)).toBe(200);
    expect(voiceSecondsLeft(300, 0)).toBe(300);
  });

  it("clamps at 0 when used equals or exceeds the cap", () => {
    expect(voiceSecondsLeft(300, 300)).toBe(0);
    expect(voiceSecondsLeft(300, 450)).toBe(0);
  });
});

describe("reserveVoiceSeconds()", () => {
  it("creates the device row on the first hold", async () => {
    const id = freshDevice();
    expect(await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT)).toBe(true);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 120 });
  });

  it("stacks holds while seconds are left, then refuses without changing the row", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, 100);
    expect(await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT)).toBe(true);
    expect(await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT)).toBe(true);
    expect((await storedRow(id))?.voice_seconds).toBe(340);
    expect(await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT)).toBe(false);
    expect((await storedRow(id))?.voice_seconds).toBe(340);
  });

  it("refuses a device already at the cap", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, CAP);
    expect(await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT)).toBe(false);
    expect((await storedRow(id))?.voice_seconds).toBe(CAP);
  });

  it("rolls over a stale or NULL voice_date", async () => {
    const stale = freshDevice();
    await seedDevice(stale, YESTERDAY, 300);
    expect(await reserveVoiceSeconds(env.DB, stale, TODAY, 120, CAP, CREATED_AT)).toBe(true);
    expect(await storedRow(stale)).toEqual({ voice_date: TODAY, voice_seconds: 120 });

    const empty = freshDevice();
    await seedDevice(empty, null, 0);
    expect(await reserveVoiceSeconds(env.DB, empty, TODAY, 120, CAP, CREATED_AT)).toBe(true);
    expect(await storedRow(empty)).toEqual({ voice_date: TODAY, voice_seconds: 120 });
  });

  it("does not overwrite created_at of an existing device", async () => {
    const id = freshDevice();
    await seedDevice(id, null, 0);
    await reserveVoiceSeconds(env.DB, id, TODAY, 5, CAP, "2030-01-01T00:00:00.000Z");
    const row = await env.DB.prepare("SELECT created_at FROM devices WHERE device_hash = ?1")
      .bind(id)
      .first<{ created_at: string }>();
    expect(row?.created_at).toBe(CREATED_AT);
  });

  it("keeps devices independent", async () => {
    const a = freshDevice();
    const b = freshDevice();
    await reserveVoiceSeconds(env.DB, a, TODAY, 100, CAP, CREATED_AT);
    expect(await getVoiceSecondsUsed(env.DB, b, TODAY)).toBe(0);
  });
});

describe("settleVoiceSeconds()", () => {
  it("swaps the hold for the billed seconds", async () => {
    const id = freshDevice();
    await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT);
    expect(await settleVoiceSeconds(env.DB, id, TODAY, 120, 30)).toBe(30);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 30 });
  });

  it("refunds the hold when 0 is billed", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, 40);
    await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT);
    expect(await settleVoiceSeconds(env.DB, id, TODAY, 120, 0)).toBe(40);
  });

  it("keeps another request's hold intact", async () => {
    const id = freshDevice();
    await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT);
    await reserveVoiceSeconds(env.DB, id, TODAY, 120, CAP, CREATED_AT);
    expect(await settleVoiceSeconds(env.DB, id, TODAY, 120, 30)).toBe(150);
    expect(await settleVoiceSeconds(env.DB, id, TODAY, 120, 50)).toBe(80);
  });

  it("does nothing once the day has rolled over", async () => {
    const id = freshDevice();
    await seedDevice(id, YESTERDAY, 120);
    expect(await settleVoiceSeconds(env.DB, id, TODAY, 120, 30)).toBe(0);
    expect(await storedRow(id)).toEqual({ voice_date: YESTERDAY, voice_seconds: 120 });
  });
});
