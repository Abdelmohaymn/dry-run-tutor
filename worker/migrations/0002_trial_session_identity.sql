-- FR-032: "exactly one trial session per install", enforced server-side.
--
-- 0001 recorded only (install_id, started_at, completed_at). completed_at is
-- written by exactly one caller — routes/trial.ts, after a SUCCESSFUL
-- mode=judge — so an ABANDONED session (the common case) left it NULL
-- forever, and the gate read every later call as "the session already in
-- flight": no TRIAL_CONSUMED, and the new-session budget gate skipped
-- entirely. Nothing pinned that session to a problem or a day, while
-- turn_counter is keyed (install_id, problem_id, date), so each new
-- problem_id handed out another trial.turn_cap of turns, and the date
-- rolled them over daily. One install could spend the operator's pool
-- without limit on the one path where the budget gate does not run.
--
-- The session now carries its identity, so "already in flight" means
-- literally that: same install, same problem, same UTC day.
ALTER TABLE trial_consumed ADD COLUMN problem_id TEXT;
ALTER TABLE trial_consumed ADD COLUMN date TEXT;

-- Rows written before this migration carry no session identity and cannot be
-- matched against an incoming call. Close them rather than leave them
-- permanently in flight: an unidentifiable open session is exactly the hole
-- being fixed. This forfeits any genuinely mid-flight trial at deploy time —
-- acceptable because the alternative is an unbounded operator spend, and
-- because a taster is one short session, not work worth preserving.
UPDATE trial_consumed
   SET completed_at = started_at
 WHERE completed_at IS NULL AND problem_id IS NULL;
