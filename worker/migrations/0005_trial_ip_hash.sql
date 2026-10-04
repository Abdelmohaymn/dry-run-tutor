-- Per-network cap on new trial sessions (trial.ip_daily_session_cap).
--
-- A reinstall mints a fresh install id, so the one-trial-per-install rule
-- alone lets a script start sessions on the operator's pool without limit.
-- Each trial row now records a keyed hash of the caller's IP (never the IP
-- itself), and routes/trial.ts refuses a NEW session once that hash already
-- has ip_daily_session_cap rows for the UTC day. releaseTrialStart() deletes
-- the row of a session the provider never answered, so the count only ever
-- holds sessions that were actually served.
ALTER TABLE trial_consumed ADD COLUMN ip_hash TEXT;
CREATE INDEX idx_trial_consumed_ip_date ON trial_consumed (ip_hash, date);
