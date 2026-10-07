-- Sessions each device started today (trial.ip_daily_session_cap and
-- trial.daily_session_cap).
--
-- Both caps used to count `devices` rows, one per device. Since 0008 a device
-- can start several sessions in a day, and each start re-points the same row,
-- so a device counted once however many it started. These two columns count
-- the starts themselves: the caps now SUM trial_day_sessions over today's rows.
--
-- Kept apart from trial_date on purpose: releaseTrialStart() clears the slot
-- (trial_date included) when the provider never answered, and that must not
-- also wipe the sessions this device already started earlier today.
-- Cap-enforcing only: a date and a count, never content.
ALTER TABLE devices ADD COLUMN trial_day_date TEXT;
ALTER TABLE devices ADD COLUMN trial_day_sessions INTEGER NOT NULL DEFAULT 0;

UPDATE devices SET trial_day_date = trial_date, trial_day_sessions = 1
 WHERE trial_problem_id IS NOT NULL AND trial_date IS NOT NULL;

DROP INDEX IF EXISTS devices_trial_ip;
CREATE INDEX devices_trial_ip_day ON devices (trial_ip_hash, trial_day_date);
CREATE INDEX devices_trial_day ON devices (trial_day_date);
