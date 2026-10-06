# 006 — Lean backend: device identity, 5-table D1, server-picked daily problem

Status: planned, not started. Written 2026-10-06.

## Goal

Store in D1 only what the server needs to enforce limits. Learner data
(history, verdicts, streak, analytics) stays on the phone. Identify a device
by ANDROID_ID so a reinstall no longer gets a new free trial. The server, not
the app, picks the daily problem, and only that problem is sent.

Out of scope: server-side speech-to-text (Groq / Cloudflare Whisper). It
conflicts with Constitution VII ("This App Never Handles Audio") and needs an
amendment first. So `voice_seconds` is NOT added here; it lands with that
feature.

## Decisions

| Decision | Choice |
|---|---|
| Identity | `device_hash = HMAC(INSTALL_HMAC_SECRET, "android:" + ANDROID_ID)`. Raw id never stored. Android only (Constitution: "Flutter, Android only"), so no iOS id yet |
| Token | Existing signed format, now over the device hash: `<device_hash>.<sig>`. Header stays `X-Install-Id` to limit churn |
| Tables kept | `config`, `devices`, `device_day`, `provider_day`, `notify_signup` |
| Tables dropped | `usage`, `events`, `web_demo_session`, `trial_consumed`, `turn_counter`, `trial_budget` (last three merged into the new ones) |
| D7 retention | Measured from `devices.created_at` + `device_day` rows (written on each `/v1/daily` fetch). Replaces `events` for the decision metric |
| Daily problem | `GET /v1/daily?date=` returns one problem. Manifest route removed |
| Old data | Exported to JSON, then dropped. Not migrated (keyed by install_id, which has no device mapping) |
| Network key | IPv4: full address. IPv6: the /64 prefix. Behind mobile carrier NAT (Vodafone, Orange) thousands of phones share one IPv4, but on IPv6 each phone gets its own /64, so the trial cap becomes close to per-device there |

## 1. Schema (migration `0006_lean_backend.sql`)

```sql
ALTER TABLE runtime_config RENAME TO config;

CREATE TABLE devices (
  device_hash        TEXT PRIMARY KEY,
  created_at         TEXT NOT NULL,       -- D7 cohort day
  trial_started_at   TEXT,                -- NULL = trial unused
  trial_problem_id   TEXT,
  trial_date         TEXT,
  trial_completed_at TEXT,
  trial_ip_hash      TEXT,                -- per-network trial cap
  practice_turns     INTEGER NOT NULL DEFAULT 0  -- lifetime warm-up cap
);
CREATE INDEX devices_trial_ip ON devices (trial_ip_hash, trial_date);

CREATE TABLE device_day (
  device_hash       TEXT NOT NULL,
  date              TEXT NOT NULL,        -- UTC YYYY-MM-DD
  problem_id        TEXT NOT NULL,
  turns             INTEGER NOT NULL DEFAULT 0,
  solution_requests INTEGER NOT NULL DEFAULT 0,  -- server-side anti-forgery counter
  hints_revealed    INTEGER NOT NULL DEFAULT 0,  -- server owns the hint ladder
  judged_at         TEXT,                        -- one judge per session
  PRIMARY KEY (device_hash, date, problem_id)
);

ALTER TABLE trial_budget RENAME TO provider_day;

DROP TABLE usage;
DROP TABLE events;
DROP TABLE web_demo_session;
DROP TABLE trial_consumed;
DROP TABLE turn_counter;

-- The config schema is .strict(): drop the removed keys in the same step,
-- or every request fails to parse the row.
UPDATE config SET payload = json_remove(payload, '$.content_manifest_url'),
                  updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now')
 WHERE id = 1;
```

Why `problem_id` stays in the `device_day` key: the warm-up problem (`vp-0000`)
and the day's problem can both run on the same day, and keyed learners can
open a past problem from the review screen.

D7 query (documented in the plan, run by hand):

```sql
SELECT COUNT(DISTINCT d.device_hash) * 1.0 / COUNT(DISTINCT v.device_hash)
FROM devices v
LEFT JOIN device_day d
  ON d.device_hash = v.device_hash
 AND d.date = date(v.created_at, '+7 days')
WHERE date(v.created_at) = :cohort_day;
```

Write budget: ~2 rows per turn (`device_day`, `provider_day`) + 1 per daily
fetch. ~32 writes per 15-turn session, ~3,000 sessions/day inside the D1 free
100K writes/day.

## 2. Worker changes

### Phase A — identity (~2 h)
- `routes/install.ts`: body `{ platform: "android", device_id: string }`.
  Compute `device_hash`, `INSERT OR IGNORE INTO devices (device_hash, created_at)`,
  return the signed token. Keep `INSTALL_RL`.
- `lib/install-id.ts`: sign / verify a 64-hex device hash instead of a uuidv4.
- `middleware/install-auth.ts`: unchanged apart from the validator.
- New `networkKey(ip)` in `lib/trial-pool.ts` (~30 min): IPv4 unchanged;
  IPv6 expanded (handle `::` and IPv4-mapped `::ffff:a.b.c.d` → treat as
  IPv4) and cut to the first 4 hextets, e.g. `2a02:c7c:1234:5678::/64`.
  - `hashIp()` (`trial-pool.ts:358`) hashes `networkKey(ip)` instead of the
    raw IP, so `trial_ip_hash` and `ip_daily_session_cap` count per /64.
  - `routes/install.ts` keys `INSTALL_RL` on `networkKey(ip)` too.
    Otherwise one IPv6 client can rotate through its own /64 (2^64
    addresses) and skip the install rate limit.

### Phase B — tables (~3 h)
- `lib/turn-cap.ts`: every `turn_counter` statement → `device_day`. Same
  functions, same semantics (`reserveTurn`, `refundTurn`, `claimJudge`,
  `releaseJudgeClaim`, `readCounters`, `revealNextHint`).
- `lib/trial-pool.ts`: `trial_consumed` statements → `devices.trial_*` columns
  (`getTrialConsumed`, `markTrialStarted`, `releaseTrialStart`,
  `markTrialCompleted`, `ipSessionGateOk`, `countSessionsStartedToday`,
  `bumpPracticeTurn`, `releasePracticeTurn`). `trial_budget` → `provider_day`
  (rename only).
- `lib/runtime-config.ts`: `FROM config`; drop `content_manifest_url` from the
  schema.
- Delete `lib/usage.ts` and every `writeUsage` call (chat-core, judge-core,
  condense, finish-check, routes/repair, routes/trial, practice-turn). Trial
  budget settlement already takes usage from the provider result, not from
  the table.
- Delete `lib/events.ts`, `routes/event.ts`, `routes/web-event.ts`, the
  server-side `assessment_verdict_overridden` write in `judge-core.ts:116`,
  and their mounts in `index.ts`. Keep `WEB_EVENT_RL`: `notify.ts` uses it.
- `routes/privacy.ts`: remove the events wording; say a hashed device id is
  kept to enforce the free limits.

### Phase C — daily problem (~2 h)
- New `routes/daily.ts`, `GET /v1/daily?date=YYYY-MM-DD`, behind install-auth:
  1. Reject a `date` more than 1 day from server UTC (no peeking ahead).
  2. Pick: a problem dated exactly `date`; else the `rotation` pointer
     (move `_pointerPick` from the app); else `days_since_epoch % pool`.
     Pool = undated, not killed, not `practice`, id-sorted.
  3. Upsert `device_day (device_hash, date, problem_id)` — the D7 signal.
  4. Return `{ date, problem: <public half> }`, `cache-control: private`.
- New `GET /v1/practice` (no auth, cacheable): the `practice` problem's
  public half.
- Delete `routes/manifest.ts` and its mount. `getPublicManifest()` stays
  internal for id lookups.
- `routes/config.ts`: strip `rotation` from the response (like `web`).

### Phase D — tests (~2 h)
- Update: everything under `test/contract/` and `test/unit/` listed for
  turn_counter, trial_consumed, trial_budget, install, config.
- Update `unit/no-content-persisted.test.ts` TABLES, `unit/trial-isolation.test.ts`
  table names, `unit/config-consumers.test.ts` (drop `content_manifest_url`).
- Delete: `unit/usage.test.ts`, `contract/usage-record.test.ts`,
  `contract/event.test.ts`, `contract/web-event.test.ts`,
  `contract/judge.override.test.ts`, `contract/manifest.test.ts`,
  `contract/config.rotation-lever.test.ts` (replaced below).
- New: `contract/daily.test.ts` (dated pick, pointer pick, killed skip,
  practice excluded, date window, device_day row written),
  `contract/practice.test.ts`, `contract/install.device.test.ts`
  (same device id → same hash, reinstall keeps trial used).
- New `unit/network-key.test.ts`: IPv4 unchanged; two IPv6 addresses in one
  /64 → same key; different /64 → different key; `::` compressed forms;
  IPv4-mapped IPv6 → IPv4 key; `"unknown"` passes through.
- `contract/trial-ip-limit.test.ts`: add a case where two IPv6 callers in the
  same /64 share the cap and a caller in another /64 does not.
- `helpers.ts`: `mintInstallId` → mint from a device id.

## 3. App changes

### Phase E — identity (~1.5 h)
- New MethodChannel `${AppBrand.channelPrefix}/device_id` returning
  `Settings.Secure.ANDROID_ID` (pattern: `core/time/trusted_time_platform.dart`).
- `install_repository_impl.dart`: send `{platform, device_id}`; drop the
  pending-uuid SharedPreferences dance.
- Drift migration: clear `InstallIdentity` so every updated app re-registers
  once (an old install_id is rejected by the new Worker).

### Phase F — remove analytics (~1.5 h)
- Delete `lib/core/analytics/`, `BufferedEvents` table + `event_dao.dart`
  (drift migration drops the table), `relay_client.sendEvents`,
  `event_dto.dart`.
- Remove the 30 `emit` call sites (21 in `daily_session_cubit.dart`) and the
  `AnalyticsClient` constructor params in router, shell, key entry, share card.
- Delete `analytics_contract_test`, `analytics_drain_test`,
  `analytics_payload_test`, `fake_analytics_client.dart`; drop the injection
  from cubit/widget tests.

### Phase G — daily problem (~2.5 h)
- `relay_client.dart`: `daily(date)` and `practice()`; remove `manifest()`.
- `daily_repository_impl.dart`: `forToday()` = fetch `/v1/daily` with the
  trusted date, upsert into `CachedProblems` (with `manifestDate = date`),
  `isRepeat` from `completedProblemIds()`. Offline: return the cached problem
  for that date, else the existing "no problem" state. Delete `_pointerPick`
  and the evergreen loop.
- `problem_repository_impl.dart`: replace `prefetchManifest` with
  `fetchPractice()`; `available()` and the killed/practice filters go.
  Callers: `main.dart:87`, `seeding_screen.dart:183`, `withdrawn_screen.dart:61`,
  `key_repository_impl.dart:124`.
- Config DTO: drop `content_manifest_url` and `rotation`.
- Tests: rewrite `daily_repository_test.dart` against a fake relay; update
  `remote_config_test.dart`, `onboarding_test.dart`, `seeding_screen_test.dart`,
  `first_launch_seed_test.dart`, `fake_problem_repository.dart`.

## 4. Docs and policy (~45 min)

- `specs/001-proxy-content-contract/contracts/openapi.yaml`: `/v1/install`
  body, add `/v1/daily` + `/v1/practice`, remove `/v1/event`,
  `/v1/web-event`, `/v1/content/manifest.json`, the web-demo block.
- `config.schema.json`: drop `content_manifest_url` and the `web` demo fields.
- Delete `event.schema.json`, `analytics-events.md`; update `relay-client.md`.
- **Constitution amendment (in `docs/constitution.md`, outside this repo, then
  synced):** replace "analytics … sent to our own `POST /v1/event`" with "D7
  is measured from a hashed device id and per-day activity rows; no event
  stream". Needs the owner's sign-off.
- Play Data safety: declare "Device or other IDs — fraud prevention, not
  shared"; remove "App interactions" if declared.

## 5. Rollout

1. Export prod data:
   `npx wrangler d1 export dry-run-tutor --env prod --remote --output backup-2026-10-xx.sql`.
2. Apply `0006` to the dev D1, deploy the dev Worker, run the app against it.
3. Release the new app on Play; wait until it is live.
4. Apply `0006` to prod and deploy the prod Worker.
5. Within the same minute, set `min_supported_version` to the new version in
   prod config. Old apps show "Update required" on next launch.

Old apps between steps 4 and 5 get errors on chat/trial/judge; `/v1/config`
keeps working, so the update wall still appears.

## Estimate

Worker ~9 h, app ~5.5 h, docs ~45 min: about 2 working days including a
dev run-through.

## Risks

- A config payload that still has `content_manifest_url` fails the strict
  schema → total outage. Mitigated by the `json_remove` in the migration;
  verify with `GET /v1/config` right after step 4.
- ANDROID_ID is self-reported: a script can send random ids. The per-IP trial
  cap, `INSTALL_RL` and `provider_day` budget still bound the damage.
- Every existing user gets one fresh trial (old rows are not migrated).
- Carrier NAT on IPv4: users still on IPv4 behind Vodafone/Orange share one
  address, so `ip_daily_session_cap` (15 in prod) can wall real users. /64
  fixes IPv6 only. Follow-ups if it bites: a higher cap for carrier ASNs from
  `request.cf.asn` via remote config (~1 h), or Play Integrity so ANDROID_ID
  can be trusted alone (~half a day).
