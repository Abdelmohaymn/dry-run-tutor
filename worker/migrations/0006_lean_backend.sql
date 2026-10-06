-- 006: D1 keeps only what enforces the free limits (specs/006-lean-backend/data-model.md).
-- Old rows are exported before this runs in prod and are NOT migrated: they are
-- keyed by random install uuids that map to no device.
ALTER TABLE runtime_config RENAME TO config;
ALTER TABLE trial_budget RENAME TO provider_day;

CREATE TABLE devices (
  device_hash        TEXT PRIMARY KEY,
  created_at         TEXT NOT NULL,
  trial_started_at   TEXT,
  trial_problem_id   TEXT,
  trial_date         TEXT,
  trial_completed_at TEXT,
  trial_ip_hash      TEXT,
  practice_turns     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX devices_trial_ip ON devices (trial_ip_hash, trial_date);

CREATE TABLE device_day (
  device_hash       TEXT    NOT NULL,
  date              TEXT    NOT NULL,
  problem_id        TEXT    NOT NULL,
  turns             INTEGER NOT NULL DEFAULT 0,
  solution_requests INTEGER NOT NULL DEFAULT 0,
  hints_revealed    INTEGER NOT NULL DEFAULT 0,
  judged_at         TEXT,
  PRIMARY KEY (device_hash, date, problem_id)
);

DROP TABLE usage;
DROP TABLE events;
DROP TABLE web_demo_session;
DROP TABLE trial_consumed;
DROP TABLE turn_counter;
