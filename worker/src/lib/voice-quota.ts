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
 * Adds `billable` seconds to today's total, creating the device row if needed
 * and resetting the count when the stored date is not today. The total is
 * clamped at `cap`. Returns the new `voice_seconds`.
 */
export async function chargeVoiceSeconds(
  db: D1Database,
  deviceHash: string,
  today: string,
  billable: number,
  cap: number,
  createdAt: string,
): Promise<number> {
  const row = await db
    .prepare(
      `INSERT INTO devices (device_hash, created_at, voice_date, voice_seconds)
       VALUES (?1, ?5, ?2, MIN(?4, ?3))
       ON CONFLICT(device_hash) DO UPDATE SET
         voice_seconds = MIN(?4, CASE WHEN devices.voice_date = ?2 THEN devices.voice_seconds ELSE 0 END + ?3),
         voice_date    = ?2
       RETURNING voice_seconds`,
    )
    .bind(deviceHash, today, billable, cap, createdAt)
    .first<{ voice_seconds: number }>();
  return row?.voice_seconds ?? 0;
}
