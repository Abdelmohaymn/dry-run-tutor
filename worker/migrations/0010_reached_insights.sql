-- The insight keys the progress check (finish-check.ts, prompt v2) found the
-- learner has stated this session, as a JSON array. The leak filter stops
-- blocking an insight's never_say words once its key is here
-- (specs/review-tutor-judge-findings.md F4). Insight keys only, never
-- learner text: leak-filter enforcement state, like solution_requests.
ALTER TABLE device_day ADD COLUMN reached_keys TEXT;
