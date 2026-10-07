-- Server-side speech-to-text is capped per device per UTC day, and the cap has
-- to be enforced where the learner cannot reset it, so the running total lives
-- HERE, on the one row that is already per-device.
--
-- Cap-enforcing only: a count of seconds and the UTC date it belongs to. No
-- transcript and no audio is ever stored. voice_date NULL or != today means 0
-- seconds used, so there is no cron and no reset job; the first clip of a new
-- day overwrites both columns.
ALTER TABLE devices ADD COLUMN voice_date    TEXT;
ALTER TABLE devices ADD COLUMN voice_seconds INTEGER NOT NULL DEFAULT 0;
