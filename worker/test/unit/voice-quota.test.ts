import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import {
  chargeVoiceSeconds,
  getVoiceSecondsUsed,
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

describe("chargeVoiceSeconds()", () => {
  it("creates the device row on first charge and returns the charged seconds", async () => {
    const id = freshDevice();
    const total = await chargeVoiceSeconds(env.DB, id, TODAY, 30, CAP, CREATED_AT);
    expect(total).toBe(30);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 30 });
    expect(await getVoiceSecondsUsed(env.DB, id, TODAY)).toBe(30);
  });

  it("accumulates across charges on the same day, RETURNING the new total each time", async () => {
    const id = freshDevice();
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 30, CAP, CREATED_AT)).toBe(30);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 45, CAP, CREATED_AT)).toBe(75);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 5, CAP, CREATED_AT)).toBe(80);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 80 });
  });

  it("accumulates onto an existing row that has a voice count for today", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, 100);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 20, CAP, CREATED_AT)).toBe(120);
  });

  it("never exceeds the cap on an existing row", async () => {
    const id = freshDevice();
    await seedDevice(id, TODAY, 290);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 60, CAP, CREATED_AT)).toBe(CAP);
    expect((await storedRow(id))?.voice_seconds).toBe(CAP);
    // Already at the cap: another charge stays at the cap.
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 10, CAP, CREATED_AT)).toBe(CAP);
    expect(voiceSecondsLeft(CAP, await getVoiceSecondsUsed(env.DB, id, TODAY))).toBe(0);
  });

  it("never exceeds the cap on the first charge for a new device", async () => {
    const id = freshDevice();
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 500, CAP, CREATED_AT)).toBe(CAP);
    expect((await storedRow(id))?.voice_seconds).toBe(CAP);
  });

  it("rolls over on a new day: resets the old count and charges fresh", async () => {
    const id = freshDevice();
    await seedDevice(id, YESTERDAY, 280);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 15, CAP, CREATED_AT)).toBe(15);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 15 });
  });

  it("rolls over a NULL voice_date row", async () => {
    const id = freshDevice();
    await seedDevice(id, null, 0);
    expect(await chargeVoiceSeconds(env.DB, id, TODAY, 12, CAP, CREATED_AT)).toBe(12);
    expect(await storedRow(id)).toEqual({ voice_date: TODAY, voice_seconds: 12 });
  });

  it("does not overwrite created_at of an existing device", async () => {
    const id = freshDevice();
    await seedDevice(id, null, 0);
    await chargeVoiceSeconds(env.DB, id, TODAY, 5, CAP, "2030-01-01T00:00:00.000Z");
    const row = await env.DB.prepare("SELECT created_at FROM devices WHERE device_hash = ?1")
      .bind(id)
      .first<{ created_at: string }>();
    expect(row?.created_at).toBe(CREATED_AT);
  });

  it("keeps devices independent", async () => {
    const a = freshDevice();
    const b = freshDevice();
    await chargeVoiceSeconds(env.DB, a, TODAY, 100, CAP, CREATED_AT);
    expect(await getVoiceSecondsUsed(env.DB, b, TODAY)).toBe(0);
  });
});
