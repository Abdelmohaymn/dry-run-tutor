# Data Model — 006 Lean Backend

Two stores change: the Worker's D1 database (Part A) and the app's Drift
database (Part B). Part C maps every old D1 statement to its new one, so the
port is mechanical.

---

## Part A — D1 (Worker)

After migration `worker/migrations/0006_lean_backend.sql`, D1 holds exactly
five tables (SC-002):

| Table | Purpose | Rows |
|---|---|---|
| `config` | Remote config, one row | 1 |
| `devices` | One row per phone: D7 cohort day, trial state, lifetime warm-up turns, daily voice seconds used (cap-enforcing only; migration 0007) | 1 per device |
| `device_day` | Per device × UTC day × problem counters; existence = "active that day" | ≤ 2 per device per active day |
| `provider_day` | Operator spend per trial-pool member per UTC day | ≤ pool size per day |
| `notify_signup` | Landing-site launch emails | unchanged |

### A1. `config` (renamed from `runtime_config`)

Columns unchanged: `id INTEGER PRIMARY KEY CHECK (id = 1)`, `payload TEXT NOT NULL`,
`updated_at TEXT NOT NULL`.

Payload changes (validated by `runtimeConfigSchema`, which is `.strict()`):

- `content_manifest_url` — **kept** in D1 and still served by `GET /v1/config`,
  but made `.optional()` in the Worker schema and read by nothing. Old apps
  require it to parse config and reach the update wall (contracts/worker-api.md
  §GET /v1/config). The migration does not touch the payload.
- `rotation` — **kept** in the schema and in D1 (the server now reads it in
  `routes/daily.ts`), but **stripped** from the `GET /v1/config` response
  the same way `web` already is.
- `web` — schema unchanged in the Worker (`allowed_origins`, `notify_enabled`).
  Only `contracts/config.schema.json` loses the demo-only fields
  (`enabled`, `demo_turn_cap`, `daily_demo_cap`, `max_pool_share`).

### A2. `devices` (new; replaces `trial_consumed`)

```sql
CREATE TABLE devices (
  device_hash        TEXT PRIMARY KEY,               -- 64 lowercase hex, HMAC of the Android ID
  created_at         TEXT NOT NULL,                  -- ISO-8601 UTC; first /v1/install; D7 cohort day
  trial_started_at   TEXT,                           -- ISO-8601; set by markTrialStarted, NULL = taster not claimed
  trial_problem_id   TEXT,                           -- vp-NNNN the taster is pinned to
  trial_date         TEXT,                           -- YYYY-MM-DD UTC the taster is pinned to
  trial_completed_at TEXT,                           -- ISO-8601; set after a successful trial judge
  trial_ip_hash      TEXT,                           -- hashIp(networkKey(ip)); per-network cap
  practice_turns     INTEGER NOT NULL DEFAULT 0,     -- lifetime warm-up turns
  voice_date         TEXT,                           -- YYYY-MM-DD UTC the voice_seconds belong to (migration 0007)
  voice_seconds      INTEGER NOT NULL DEFAULT 0      -- speech-to-text seconds used on voice_date (migration 0007)
);
CREATE INDEX devices_trial_ip ON devices (trial_ip_hash, trial_date);
```

The two voice columns were added later by `worker/migrations/0007_voice_seconds.sql`
(`ALTER TABLE devices ADD COLUMN ...`, so they sit after `practice_turns` in a
migrated database). They are **cap-enforcing only**: a count of seconds and the
UTC date it belongs to, enforcing the per-device daily speech-to-text cap.

- `voice_date` NULL or different from today's UTC date means 0 seconds used.
  The first clip of a new day overwrites both columns, so there is no cron and
  no reset job.
- No transcript and no audio is ever stored in D1 (or logged, or put in an
  error body).

Migration `0008_trial_sessions_done.sql` added `trial_sessions_done INTEGER NOT NULL DEFAULT 0` (cap-enforcing only). The `trial_*` columns hold the **current** free session; this counts the sessions already retired out of them. A device has claimed `trial_sessions_done` plus one if the slot names a problem (or is a closed pre-0002 row). A different problem or day may take over the slot while that count is below `trial.sessions_per_device` (default 1, so the original one-taster rule). No content is stored.

Field mapping from `trial_consumed`:

| `trial_consumed` | `devices` |
|---|---|
| `install_id` | `device_hash` |
| `started_at` | `trial_started_at` (now nullable — see State below) |
| `problem_id` | `trial_problem_id` |
| `date` | `trial_date` |
| `completed_at` | `trial_completed_at` |
| `ip_hash` | `trial_ip_hash` |
| `practice_turns` | `practice_turns` |
| — | `created_at` (new) |

Validation:

- `device_hash` matches `/^[0-9a-f]{64}$/`. It is computed by the Worker and
  never accepted from a client as-is.
- The raw Android ID is never stored, logged, or put in an error (FR-002).

State of the taster (same rules as today, new columns):

```
                 ┌──────────────── practice turns may be spent in any state ──────────────┐
  (row created by /v1/install)
  UNCLAIMED  trial_problem_id IS NULL AND trial_completed_at IS NULL
     │ markTrialStarted (first trial call that reaches a provider)
     ▼
  IN FLIGHT  trial_problem_id = P, trial_date = D, trial_completed_at IS NULL
     │ markTrialCompleted (successful trial judge)       │ releaseTrialStart (provider never answered,
     ▼                                                    │ guarded on trial_started_at) → back to UNCLAIMED
  COMPLETED  trial_completed_at IS NOT NULL
```

- A call is "the session in flight" only if it names the same `P` on the
  same UTC `D` and `trial_completed_at IS NULL` (`isSameTrialSession`, unchanged).
- `releaseTrialStart` now **clears** the four trial columns instead of
  deleting the row. The device row must survive: it holds `created_at`
  and `practice_turns`. Side effect, deliberate: a failed first taster call
  no longer wipes `practice_turns` (the old DELETE did). That is stricter by
  at most `trial.practice_turn_cap` turns, never looser.

### A3. `device_day` (new; replaces `turn_counter`)

```sql
CREATE TABLE device_day (
  device_hash       TEXT    NOT NULL,
  date              TEXT    NOT NULL,                -- YYYY-MM-DD UTC
  problem_id        TEXT    NOT NULL,
  turns             INTEGER NOT NULL DEFAULT 0,
  solution_requests INTEGER NOT NULL DEFAULT 0,
  hints_revealed    INTEGER NOT NULL DEFAULT 0,
  judged_at         TEXT,
  PRIMARY KEY (device_hash, date, problem_id)
);
```

- Same counters and semantics as `turn_counter`. Only the key column name
  (`install_id` → `device_hash`) and the key column order change.
- **Every** `ON CONFLICT(...)` clause must list exactly
  `(device_hash, date, problem_id)` — SQLite requires the conflict target to
  match the primary key columns (order inside the list does not matter, but
  the set must).
- Written by: `reserveTurn`, `claimJudge`, `revealNextHint` (upserts),
  `refundTurn`, `releaseJudgeClaim` (updates), and `GET /v1/daily` (insert-or-ignore
  with all counters 0 — the D7 activity signal).
- `problem_id` stays in the key because the warm-up (`vp-0000`) and the
  day's problem can both run on one day, and a keyed learner can reopen a
  past problem from review. Each keeps separate counters.

### A4. `provider_day` (renamed from `trial_budget`)

Columns unchanged: `date`, `provider_id`, `tokens_spent`, `cooldown_until`,
`PRIMARY KEY (date, provider_id)`. Every statement in `lib/trial-pool.ts`
changes only its table name — including the `trial_budget.tokens_spent`
qualifier inside the `ON CONFLICT ... DO UPDATE` clause.

### A5. `notify_signup`

Unchanged.

### A6. Dropped

`usage`, `events`, `web_demo_session`, `trial_consumed`, `turn_counter`.
Their indexes go with them (`usage_by_install_date`, `events_by_install`,
`web_demo_session_date`, `idx_trial_consumed_ip_date`). Production data is
exported first (plan.md §Rollout), never migrated (FR-011).

### A7. D7 retention (FR-022, SC-005)

Run by hand against prod (`wrangler d1 execute ... --command`):

```sql
SELECT COUNT(DISTINCT d.device_hash) * 1.0 / COUNT(DISTINCT v.device_hash) AS d7
FROM devices v
LEFT JOIN device_day d
  ON d.device_hash = v.device_hash
 AND d.date = date(v.created_at, '+7 days')
WHERE date(v.created_at) = :cohort_day;   -- e.g. '2026-10-20'
```

### A8. Write budget (SC-003)

- Keyed 15-turn session: 1 `device_day` insert (daily fetch) + 15 `device_day`
  upserts (turns) + 1 judge claim ≈ **17 writes**.
- Trial session (`trial.turn_cap` = 6): per turn 1 `device_day` + 1
  `provider_day` reserve + 1 settle = 3, so 18; plus judge (claim, reserve,
  settle, `trial_completed_at`) and the first `markTrialStarted` ≈ **24 writes**.
- Both stay under the 32-write ceiling in SC-003: 100K free writes/day ÷ 32 ≈
  3,100 sessions/day.

---

## Part B — Drift (app)

`lib/core/db/app_database.dart` goes from `schemaVersion` **5 → 6**.

### B1. `install_identity` — rows cleared, columns unchanged

- v6 upgrade step: `DELETE FROM install_identity`. Every updated app then
  registers once with its Android ID (FR-006); an old `<uuid>.<sig>` token
  would be refused by the new Worker anyway.
- Columns stay (`id`, `installUuid`, `installId`, `mintedAt`) so no table
  rebuild is needed. `installUuid` now stores the **device hash**
  (`response.installId.split('.').first`), never the raw Android ID. The
  domain `InstallIdentity.installUuid` keeps its name (no reader outside
  tests and fakes).
- `wipeAllExceptInstallIdentity()` still keeps this row — the hash is the
  same after a wipe anyway.

### B2. `buffered_events` — dropped

- Remove `BufferedEvents` from `lib/core/db/tables.dart` (lines 217–226) and
  from the `tables:` list in `@DriftDatabase` (`app_database.dart:27-51`);
  remove `EventDao` from `daos:` and delete `lib/core/db/dao/event_dao.dart`
  (+ its `.g.dart`).
- v6 upgrade step: `DROP TABLE IF EXISTS buffered_events` (raw SQL — the table class no longer exists, and IF EXISTS keeps fresh installs safe).
- Remove the `bufferedEvents` delete from `wipeAllExceptInstallIdentity()`
  (`app_database.dart:122-134`).

### B3. `cached_problems` — no schema change, one meaning change

- `manifestDate` now means **"the UTC date `/v1/daily` served this problem
  for"** (for an authored dated problem that is the same value as before).
  The practice problem is stored with `manifestDate = null`.
- New DAO method in `lib/core/db/dao/problem_dao.dart`:
  `Future<CachedProblem?> byManifestDate(String date)` →
  `(select(cachedProblems)..where((t) => t.manifestDate.equals(date))..limit(1)).getSingleOrNull()`.
- Rows are never deleted (as today); past problems stay readable by `byId`
  for the review screen.

### B4. v6 upgrade step (exact)

```dart
if (from < 6 && to >= 6) {
  await m.database.customStatement('DELETE FROM install_identity');
  await m.database.customStatement('DROP TABLE IF EXISTS buffered_events');
}
```

`test/db/migration_test.dart`: bump the `schemaVersion` assertion (`:30-34`)
to 6 and add a "v5 → v6" case: seed an `install_identity` row and a raw
`CREATE TABLE buffered_events (...)` + one row, run
`db.migration.onUpgrade(Migrator(db), 5, 6)`, assert `install_identity` is
empty and `SELECT name FROM sqlite_master WHERE name = 'buffered_events'`
returns nothing, and a seeded completed session is intact
(`_expectSessionIntact`). Update the "v1 → v5" case to "v1 → v6".

---

## Part C — Statement map (Worker)

Use this table to port every SQL statement. Parameter numbers (`?1`…) stay
as they are today; only names change.

| File · function | Old | New |
|---|---|---|
| `lib/runtime-config.ts` · `getRuntimeConfig` | `FROM runtime_config` | `FROM config` |
| `lib/turn-cap.ts` · all six functions | `turn_counter`, `install_id`, `ON CONFLICT(install_id, problem_id, date)`, qualifier `turn_counter.` | `device_day`, `device_hash`, `ON CONFLICT(device_hash, date, problem_id)`, qualifier `device_day.` |
| `lib/trial-pool.ts` · `selectMember`, `reserveEstimate`, `settleTrialBudget`, `releaseEstimate`, `setCooldown` | `trial_budget` (also as `trial_budget.tokens_spent`) | `provider_day` (also `provider_day.tokens_spent`) |
| `lib/trial-pool.ts` · `getTrialConsumed` | `SELECT started_at, completed_at, problem_id, date, practice_turns FROM trial_consumed WHERE install_id = ?1` | `SELECT trial_started_at, trial_completed_at, trial_problem_id, trial_date, practice_turns FROM devices WHERE device_hash = ?1` (map back to the same `TrialConsumedRow` field names; `startedAt` becomes `string \| null`) |
| `lib/trial-pool.ts` · `bumpPracticeTurn` | `INSERT INTO trial_consumed (install_id, started_at, practice_turns) VALUES (?1, ?2, 1) ON CONFLICT(install_id) DO UPDATE SET practice_turns = practice_turns + 1` | `INSERT INTO devices (device_hash, created_at, practice_turns) VALUES (?1, ?2, 1) ON CONFLICT(device_hash) DO UPDATE SET practice_turns = devices.practice_turns + 1` (`?2` is still the caller's timestamp; it only lands in `created_at` if the row was somehow missing) |
| `lib/trial-pool.ts` · `releasePracticeTurn` | `UPDATE trial_consumed SET practice_turns = MAX(0, practice_turns - 1) WHERE install_id = ?1` | `UPDATE devices SET practice_turns = MAX(0, practice_turns - 1) WHERE device_hash = ?1` |
| `lib/trial-pool.ts` · `markTrialStarted` | `INSERT INTO trial_consumed (install_id, started_at, problem_id, date, ip_hash) VALUES (?1..?5) ON CONFLICT(install_id) DO UPDATE SET started_at=?2, problem_id=?3, date=?4, ip_hash=?5 WHERE trial_consumed.problem_id IS NULL AND trial_consumed.completed_at IS NULL` | `INSERT INTO devices (device_hash, created_at, trial_started_at, trial_problem_id, trial_date, trial_ip_hash) VALUES (?1, ?2, ?2, ?3, ?4, ?5) ON CONFLICT(device_hash) DO UPDATE SET trial_started_at=?2, trial_problem_id=?3, trial_date=?4, trial_ip_hash=?5 WHERE devices.trial_problem_id IS NULL AND devices.trial_completed_at IS NULL` |
| `lib/trial-pool.ts` · `ipSessionGateOk` | `FROM trial_consumed WHERE ip_hash = ?1 AND date = ?2` | `FROM devices WHERE trial_ip_hash = ?1 AND trial_date = ?2` |
| `lib/trial-pool.ts` · `releaseTrialStart` | `DELETE FROM trial_consumed WHERE install_id = ?1 AND started_at = ?2 AND completed_at IS NULL` | `UPDATE devices SET trial_started_at = NULL, trial_problem_id = NULL, trial_date = NULL, trial_ip_hash = NULL WHERE device_hash = ?1 AND trial_started_at = ?2 AND trial_completed_at IS NULL` |
| `lib/trial-pool.ts` · `markTrialCompleted` | `UPDATE trial_consumed SET completed_at = ?2 WHERE install_id = ?1` | `UPDATE devices SET trial_completed_at = ?2 WHERE device_hash = ?1` |
| `lib/trial-pool.ts` · `countSessionsStartedToday` | `FROM trial_consumed WHERE started_at LIKE ?1 AND problem_id IS NOT NULL` | `FROM devices WHERE trial_started_at LIKE ?1 AND trial_problem_id IS NOT NULL` |
| `routes/install.ts` | (none) | `INSERT OR IGNORE INTO devices (device_hash, created_at) VALUES (?1, ?2)` |
| `routes/daily.ts` | (none) | `INSERT OR IGNORE INTO device_day (device_hash, date, problem_id) VALUES (?1, ?2, ?3)` |
| `lib/usage.ts`, `lib/events.ts` | `INSERT INTO usage …`, `INSERT INTO events …` | file deleted |

TypeScript identifiers deliberately **keep** their names to limit churn:
`Variables.installId`, `TurnCounterKey.installId`, `installId` parameters in
`trial-pool.ts`, and the `X-Install-Id` header. They now carry the 64-hex
device hash. Only SQL text and column names change.
