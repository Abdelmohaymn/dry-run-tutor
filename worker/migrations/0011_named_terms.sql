-- The never_say terms the progress check (finish-check.ts, prompt v3) found
-- the learner has referred to this session, in any form (an abbreviation, a
-- speech-recognition mangling, another language), as a JSON array. The leak
-- filter stops blocking a term once it is here (docs/tutor-focus-issues.md,
-- 2026-10-11). Authored terms copied from content, never learner text:
-- leak-filter enforcement state, like reached_keys.
ALTER TABLE device_day ADD COLUMN named_terms TEXT;
