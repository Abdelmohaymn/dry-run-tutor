-- The key insights the progress check (finish-check.ts, prompt v4) found the
-- learner reached WITH the tutor's help this session: a tutor line put the
-- idea into words and the learner accepted it. A JSON array of authored
-- insight keys copied from content, never learner or tutor text. They count
-- toward the Finish offer and the judge, never toward the leak filter, so this
-- is separate from reached_keys. Only ever grows, like reached_keys
-- (PLAN_07, 2026-10-12).
ALTER TABLE device_day ADD COLUMN assisted_keys TEXT;
