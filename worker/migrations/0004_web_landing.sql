-- The landing page needs two tables of its own. Neither belongs to the app's
-- install-scoped tables: the site has no install ID.
--
-- notify_signup holds "tell me when it's on my store" emails, keyed on the
-- pair so the same address can ask for both stores without duplicating.
--
-- web_demo_session tracks the site's own live-demo budget: one row per demo,
-- capped per day, deleted after 30 days (worker/src/routes/web-demo.ts).
CREATE TABLE notify_signup (
  email      TEXT NOT NULL,
  store      TEXT NOT NULL CHECK (store IN ('play', 'app_store')),
  created_at TEXT NOT NULL,
  PRIMARY KEY (email, store)
);
CREATE TABLE web_demo_session (
  demo_id          TEXT PRIMARY KEY,
  date             TEXT NOT NULL,
  started_at       TEXT NOT NULL,
  turns            INTEGER NOT NULL DEFAULT 0,
  finished_at      TEXT,
  verdict          TEXT,
  matched_approach TEXT
);
CREATE INDEX web_demo_session_date ON web_demo_session (date);
