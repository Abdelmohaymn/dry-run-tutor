/**
 * Per-device daily voice-seconds quota (server-side speech-to-text).
 *
 * The running total lives on the `devices` row (`voice_date`, `voice_seconds`,
 * migration 0007). A `voice_date` that is NULL or not today means 0 seconds
 * used, so no cron or reset job is needed. Cap-enforcing data only: no
 * transcript and no audio is ever stored.
 */

interface VoiceRow {
  voice_date: string | null;
  voice_seconds: number;
}

/** Seconds this device has already spent today (UTC). 0 for no row or a stale date. */
export async function getVoiceSecondsUsed(
  db: D1Database,
  deviceHash: string,
  today: string,
): Promise<number> {
  const row = await db
    .prepare("SELECT voice_date, voice_seconds FROM devices WHERE device_hash = ?1")
    .bind(deviceHash)
    .first<VoiceRow>();
  if (!row || row.voice_date !== today) return 0;
  return row.voice_seconds;
}

/** Seconds still available today, never negative. */
export function voiceSecondsLeft(cap: number, used: number): number {
  return Math.max(0, cap - used);
}

/**
 * Holds `seconds` of today's allowance before the Groq call, creating the
 * device row if needed and resetting the count when the stored date is not
 * today. The check and the hold are one statement, so requests that arrive
 * together cannot all pass on the same "seconds left" reading. Returns false,
 * holding nothing, when the device has no seconds left.
 *
 * The total is not clamped here: a held amount may push it past `cap` until
 * {@link settleVoiceSeconds} swaps it for the measured length.
 */
export async function reserveVoiceSeconds(
  db: D1Database,
  deviceHash: string,
  today: string,
  seconds: number,
  cap: number,
  createdAt: string,
): Promise<boolean> {
  const row = await db
    .prepare(
      `INSERT INTO devices (device_hash, created_at, voice_date, voice_seconds)
       VALUES (?1, ?5, ?2, ?3)
       ON CONFLICT(device_hash) DO UPDATE SET
         voice_seconds = CASE WHEN devices.voice_date = ?2 THEN devices.voice_seconds ELSE 0 END + ?3,
         voice_date    = ?2
       WHERE CASE WHEN devices.voice_date = ?2 THEN devices.voice_seconds ELSE 0 END < ?4
       RETURNING voice_seconds`,
    )
    .bind(deviceHash, today, seconds, cap, createdAt)
    .first<{ voice_seconds: number }>();
  return row !== null;
}

/**
 * Replaces a hold from {@link reserveVoiceSeconds} with the seconds actually
 * billed (0 refunds it). Does nothing if the day has rolled over since the
 * hold. Returns the new `voice_seconds`, never negative.
 */
export async function settleVoiceSeconds(
  db: D1Database,
  deviceHash: string,
  today: string,
  reserved: number,
  billable: number,
): Promise<number> {
  const row = await db
    .prepare(
      `UPDATE devices SET voice_seconds = MAX(0, voice_seconds - ?3 + ?4)
       WHERE device_hash = ?1 AND voice_date = ?2
       RETURNING voice_seconds`,
    )
    .bind(deviceHash, today, reserved, billable)
    .first<{ voice_seconds: number }>();
  return row?.voice_seconds ?? 0;
}
