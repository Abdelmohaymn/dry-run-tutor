-- The onboarding walkthrough becomes a real conversation, and its turns come
-- out of the taster rather than out of a second allowance.
--
-- Practice cannot simply be another problem_id on /v1/trial: 0002 exists
-- precisely because turn_counter is keyed (install_id, problem_id, date), so
-- a second problem hands out a second trial.turn_cap, renewed daily. The
-- count therefore lives HERE, on the one row that is already per-install and
-- has no date in it — a lifetime bound, like the taster it belongs to.
ALTER TABLE trial_consumed ADD COLUMN practice_turns INTEGER NOT NULL DEFAULT 0;

-- A row may now exist because of practice alone, before the taster proper has
-- been claimed: problem_id IS NULL AND completed_at IS NULL means "practice
-- happened, the taster is still available". That state is distinguishable
-- from the pre-0002 rows 0002 closed, which carry completed_at = started_at.
