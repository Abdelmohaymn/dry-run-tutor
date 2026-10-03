-- data-model.md §A4. Six tables. No column anywhere holds a learner key or
-- message content. `(install_id, problem_id, date)` in turn_counter is the
-- session identity for this feature.

CREATE TABLE usage (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id    TEXT    NOT NULL,
  date          TEXT    NOT NULL,          -- YYYY-MM-DD, UTC
  endpoint      TEXT    NOT NULL,          -- chat | judge | condense | hint | trial_chat | trial_judge
  problem_id    TEXT    NOT NULL,
  turn_index    INTEGER NOT NULL,          -- from turn_counter, not the payload
  model         TEXT    NOT NULL,
  provider      TEXT    NOT NULL,
  input_tokens  INTEGER NOT NULL,
  output_tokens INTEGER NOT NULL,
  latency_ms    INTEGER NOT NULL,
  leak_blocked  INTEGER NOT NULL DEFAULT 0,
  verdict_overridden INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT    NOT NULL
);
CREATE INDEX usage_by_install_date ON usage(install_id, date);

CREATE TABLE turn_counter (                -- the verifiable session state (R-005)
  install_id        TEXT NOT NULL,
  problem_id        TEXT NOT NULL,
  date              TEXT NOT NULL,
  turns             INTEGER NOT NULL DEFAULT 0,
  solution_requests INTEGER NOT NULL DEFAULT 0,  -- server-derived, never the payload (§B2.2)
  hints_revealed    INTEGER NOT NULL DEFAULT 0,  -- learner-pulled hint rungs (§B7)
  judged_at         TEXT,                        -- set once by /v1/judge; a second call is refused
  PRIMARY KEY (install_id, problem_id, date)
);

CREATE TABLE trial_consumed (
  install_id   TEXT PRIMARY KEY,
  started_at   TEXT NOT NULL,   -- written on the FIRST /v1/trial call for this install
  completed_at TEXT             -- written when mode=judge returns; NULL = session in flight
);

CREATE TABLE trial_budget (              -- operator spend per pool member per day (FR-031d, R-011)
  date         TEXT    NOT NULL,         -- YYYY-MM-DD, UTC
  provider_id  TEXT    NOT NULL,         -- cfg.trial.pool[].id
  tokens_spent INTEGER NOT NULL DEFAULT 0,
  cooldown_until TEXT,                   -- set by a 429 from this member; NULL = available
  PRIMARY KEY (date, provider_id)
);

CREATE TABLE events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  install_id TEXT NOT NULL,
  name       TEXT NOT NULL,
  props_json TEXT NOT NULL,               -- validated: no PII, no message content
  client_ts  TEXT NOT NULL,
  server_ts  TEXT NOT NULL
);
CREATE INDEX events_by_install ON events(install_id, server_ts);

CREATE TABLE runtime_config (
  id      INTEGER PRIMARY KEY CHECK (id = 1),   -- exactly one row
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

-- Seed the single runtime_config row with the `default` values from
-- contracts/config.schema.json.
--
-- `content_manifest_url` is the one field here that is PER-ENVIRONMENT: it must
-- name the worker's OWN host, and the client refuses any other (FR-004,
-- HostAllowlistInterceptor). The value below is the prod worker, because prod
-- is the only database still to be created from this migration. The dev row
-- was hand-edited in D1 long ago and is not reproduced by re-running this.
-- After deploying to any new environment, UPDATE this field to that host or
-- the app strands every install on /withdrawn.
INSERT INTO runtime_config (id, payload, updated_at) VALUES (
  1,
  '{"min_supported_version":"1.0.0","killed_problem_ids":[],"content_manifest_url":"https://dry-run-tutor.example.workers.dev/v1/content/manifest.json","chat":{"turn_cap":15,"wrap_up_at_turn":12,"min_turn_chars":1},"model":"openai/gpt-oss-120b","provider":"groq","trial":{"turn_cap":6,"ground_truth_tier":"A","condense":false,"daily_session_cap":0,"pool":[{"id":"groq","secret_binding":"TRIAL_KEY_GROQ","base_url":"https://api.groq.com/openai/v1","model":"openai/gpt-oss-120b","daily_token_budget":180000,"structured_output":true,"enabled":true,"cooldown_ms":60000}]},"trim":{"verbatim_turns":6,"narrow_after_turn":3,"narrow_margin":0.15,"condense_model":"openai/gpt-oss-120b"}}',
  datetime('now')
);
