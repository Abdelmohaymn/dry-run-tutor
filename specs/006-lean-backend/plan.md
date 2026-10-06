# Implementation Plan: Lean Backend — Device Identity, Minimal Server Data, Server-Picked Daily Problem

**Branch**: `006-lean-backend` | **Date**: 2026-10-06 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-lean-backend/spec.md`

**Implementer**: Claude Sonnet 5.5. This plan is written to be executed
literally. Every design choice is already made; where something looks open,
the answer is in the linked artifact. Do not redesign. If reality contradicts
this plan (a line moved, a test asserts something unexpected), stop and
report rather than improvise.

## Summary

Shrink D1 to the five tables that enforce free limits (`config`, `devices`,
`device_day`, `provider_day`, `notify_signup`). Identify a phone by a keyed
hash of `ANDROID_ID`, so a reinstall keeps its spent taster. Move the
daily-problem pick from the app to a new `GET /v1/daily`, and serve the
warm-up from `GET /v1/practice`. Delete the usage log, the analytics event
stream (server and app), the manifest route and the web-event route.

Two corrections to the hand-written plan of commit `cb8d74d`, both found in
code during research:

1. **`content_manifest_url` must stay in `/v1/config`.** Old apps declare it
   `required` (`lib/core/network/dto/config_dto.dart:96`); removing it would
   make them fail to parse config and never see the update wall (research.md R-9).
2. **`judge.override.test.ts` and `config.rotation-lever.test.ts` are trimmed,
   not deleted** — they still guard live behaviour (quickstart.md §2).

## Technical Context

**Language/Version**: TypeScript 5.9 (Cloudflare Worker, Hono 4, Zod 4); Dart / Flutter 3.41.3; Kotlin (one new MethodChannel)

**Primary Dependencies**: Worker — `hono`, `zod`, `@cloudflare/vitest-pool-workers`. App — `flutter_bloc`, `get_it`, `drift`, `dio`, `json_serializable`, `freezed`. **No new dependency** on either side

**Storage**: Cloudflare D1 (migration `0006_lean_backend.sql`); Drift on device (`schemaVersion` 5 → 6)

**Testing**: Worker — `npm run typecheck && npm test` (vitest `unit` + `contract`). App — `flutter analyze` (zero issues; unused locals/imports are errors) and `LD_LIBRARY_PATH=/tmp/shim flutter test`

**Target Platform**: Cloudflare Workers (dev + prod envs); Android (minSdk 24)

**Project Type**: Mobile app + API (`lib/` + `worker/`)

**Performance Goals**: ≤ 32 D1 writes per session (SC-003); `/v1/daily` = 1 config read + 1 insert-or-ignore

**Constraints**: D1 free tier (100K writes/day); zero developer cost (Constitution X); raw Android ID never stored or logged; old apps must still parse `/v1/config`

**Scale/Scope**: ~45 Worker files touched (≈ 20 src, ≈ 35 tests), ~50 app files (most are analytics-injection removals in tests)

## Constitution Check

*GATE: evaluated before Phase 0 and re-checked after Phase 1. Constitution v3.0.0 (amended 2026-10-06 for this feature).*

| # | Principle / rule | Status | Note |
|---|---|---|---|
| G-1 | Quality Gates: "Analytics … sent to our own `POST /v1/event`"; X.8 "analytics stay on our own `POST /v1/event`"; I "the `input_mode` split MUST stay watchable"; X "Hint-pull rate and D7 are compared against their pre-advertising baselines" | **Pass (amended v3.0.0)** | Was a violation under v2.0.0. Owner approved the amendment 2026-10-06: Quality Gates now say "Day-7 is measured from a hashed device id and per-day activity rows (`devices` + `device_day`); there is no event stream"; X.8 says there is no product-analytics stream; the input-mode split (I) and hint-pull rate (X) are dropped. Synced to `.specify/memory/constitution.md`; the owner still copies it to the external `docs/constitution.md` |
| G-2 | Governance: D7 decision rule | Pass, argued | Justified by cost, not D7: each reinstall currently mints a new taster on the developer's key (open-ended cost, Principle X "zero developer cost"). D7 stays a single query (data-model.md §A7) |
| G-3 | VI Ground truth never leaves the server | Pass | `/v1/daily` and `/v1/practice` return the public half verbatim from the build-time public manifest |
| G-4 | VII App never handles audio | Pass | Untouched. Server STT / `voice_seconds` explicitly out of scope |
| G-5 | VIII Offline never punishes | Pass with note | Same-day offline reads the cached problem. A new day offline shows the existing no-problem state; chat needs the network per turn anyway (accepted in VIII). No look-ahead fetch, because it would fake D7 rows (research.md R-7) |
| G-6 | IX Trusted time | Pass | App sends `TrustedTimeSource.today()`; Worker accepts ±1 day |
| G-7 | X.1–X.3 cost levers server-side | Pass | Rotation becomes fully server-side; kill switch honoured by the server pick |
| G-8 | Locked stack | Pass | Native MethodChannel (pattern of `trusted_time`), no SDK; repositories constructor-injected; `sl<T>()` only in `service_locator.dart`/`main()`/`BlocProvider(create:)` |
| G-9 | Quality Gates: remote kill switch, fail-open config | Pass | Killed problems never picked; config stays parseable by old and new apps |

Post-design re-check: no violations. G-1 passes under constitution v3.0.0.

## Project Structure

### Documentation (this feature)

```text
specs/006-lean-backend/
├── plan.md              # This file
├── research.md          # Decisions R-1 … R-11
├── data-model.md        # D1 tables, Drift v6, old→new SQL statement map
├── quickstart.md        # Gate commands, Worker + app test maps, e2e scenarios, rollout
├── contracts/
│   ├── worker-api.md    # /v1/install, /v1/daily, /v1/practice, /v1/config, removals, privacy copy
│   ├── network-key.md   # networkKey() rules + test vectors
│   └── app-client.md    # MethodChannel, repositories, RelayClient, analytics removal list
└── tasks.md             # /speckit-tasks output (not created here)
```

### Source Code (repository root)

```text
worker/
├── migrations/0006_lean_backend.sql          # NEW
├── src/
│   ├── index.ts                              # mounts: +daily +practice, −manifest −event −web-event
│   ├── types.ts                              # comment: installId now holds the device hash
│   ├── lib/
│   │   ├── network-key.ts                    # NEW
│   │   ├── daily-pick.ts                     # NEW (pure)
│   │   ├── install-id.ts                     # regex → 64-hex
│   │   ├── turn-cap.ts                       # turn_counter → device_day
│   │   ├── trial-pool.ts                     # trial_consumed → devices, trial_budget → provider_day, hashIp(networkKey)
│   │   ├── runtime-config.ts                 # FROM config; content_manifest_url optional
│   │   ├── chat-core.ts, judge-core.ts, condense.ts, finish-check.ts, practice-turn.ts   # usage/event writes out
│   │   ├── schemas.ts                        # event schemas out
│   │   ├── usage.ts, events.ts               # DELETED
│   └── routes/
│       ├── install.ts                        # new body, devices insert, networkKey rate limit
│       ├── daily.ts, practice.ts             # NEW
│       ├── config.ts                         # strip rotation
│       ├── chat.ts, judge.ts, trial.ts, repair.ts   # drop usage params
│       ├── privacy.ts                        # copy
│       └── manifest.ts, event.ts, web-event.ts   # DELETED
└── test/ (see quickstart.md §2)

android/app/src/main/kotlin/app/dryrun/
├── DeviceIdChannel.kt                        # NEW
└── MainActivity.kt                           # attach/detach

lib/
├── core/device/device_id_platform.dart       # NEW
├── core/analytics/                           # DELETED
├── core/db/{app_database,tables}.dart, dao/problem_dao.dart, dao/event_dao.dart (DELETED)
├── core/network/relay_client.dart, dto/{install,problem,config,event(DELETED)}_dto.dart
├── core/config/{runtime_config,remote_config_repository}.dart
├── core/di/service_locator.dart, core/router/app_router.dart, core/queue/outbox_drain_bloc.dart
├── features/onboarding/data/install_repository_impl.dart
├── features/problem/{domain/problem_repository,data/problem_repository_impl}.dart
├── features/daily/data/daily_repository_impl.dart
├── features/keys/{data/key_repository_impl,presentation/key_entry_cubit,presentation/key_entry_form}.dart
├── features/chat/presentation/{daily_session_cubit,daily_session_shell}.dart
├── features/streak/presentation/share_card.dart, features/assessment/presentation/verdict_screen.dart
├── features/daily/presentation/{withdrawn_screen,review_day_screen}.dart
├── features/onboarding/presentation/{seeding_screen,welcome_screen}.dart
└── main.dart

specs/001-proxy-content-contract/contracts/   # openapi.yaml, config.schema.json, event.schema.json (DELETED)
specs/002-voice-tutor-app/contracts/          # analytics-events.md (DELETED), relay-client.md, repositories.md
```

**Structure Decision**: Existing mobile + API layout. No new packages or
modules; two new Worker libs, two new routes, one new Dart platform file,
one new Kotlin file.

## Execution Order (for the implementer)

`tasks.md` regroups these steps by user story (e.g. A1 runs before W2, A3 before A2); **its task order wins** over the order below, and every gate below is still a checkpoint there.

Each phase ends with its gate (quickstart.md §1). **Do not start a phase
until the previous gate is green.** Commit once per phase.

### Worker (≈ 9 h)

**W1 — Migration + identity (≈ 2 h)**

1. Create `worker/migrations/0006_lean_backend.sql` exactly as below.
2. `lib/install-id.ts`: `UUID_V4_RE` → `DEVICE_HASH_RE = /^[0-9a-f]{64}$/`; update the header comment and the doc comments (`<uuidv4>` → `<device_hash>`).
3. `lib/network-key.ts` per contracts/network-key.md; `hashIp()` in `trial-pool.ts:358` hashes `` `ip:${networkKey(ip)}` ``.
4. `routes/install.ts` per contracts/worker-api.md §POST /v1/install. Compute the hash with `crypto.subtle` HMAC (same `importKey` shape as `hashIp`), hex-encode all 32 bytes (not the 16-byte slice `hashIp` uses).
5. `types.ts`: update the `Variables.installId` comment.
6. Tests: `install.test.ts`, `install-id.test.ts`, `helpers.ts` `mintInstallId`, new `network-key.test.ts` (quickstart.md §2).

```sql
-- 006: D1 keeps only what enforces the free limits (specs/006-lean-backend/data-model.md).
-- Old rows are exported before this runs in prod and are NOT migrated: they are
-- keyed by random install uuids that map to no device.
ALTER TABLE runtime_config RENAME TO config;
ALTER TABLE trial_budget RENAME TO provider_day;

CREATE TABLE devices (
  device_hash        TEXT PRIMARY KEY,
  created_at         TEXT NOT NULL,
  trial_started_at   TEXT,
  trial_problem_id   TEXT,
  trial_date         TEXT,
  trial_completed_at TEXT,
  trial_ip_hash      TEXT,
  practice_turns     INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX devices_trial_ip ON devices (trial_ip_hash, trial_date);

CREATE TABLE device_day (
  device_hash       TEXT    NOT NULL,
  date              TEXT    NOT NULL,
  problem_id        TEXT    NOT NULL,
  turns             INTEGER NOT NULL DEFAULT 0,
  solution_requests INTEGER NOT NULL DEFAULT 0,
  hints_revealed    INTEGER NOT NULL DEFAULT 0,
  judged_at         TEXT,
  PRIMARY KEY (device_hash, date, problem_id)
);

DROP TABLE usage;
DROP TABLE events;
DROP TABLE web_demo_session;
DROP TABLE trial_consumed;
DROP TABLE turn_counter;
```

W1 gate note: after step 1 alone, most tests fail (old table names). That is
expected; W1's gate is `npm run typecheck` plus the W1 test files only:
`npx vitest run --project unit test/unit/install-id.test.ts test/unit/network-key.test.ts && npx vitest run --project contract test/contract/install.test.ts`.
The full suite goes green at the end of W3 (the migration drops `usage`
and `events`, so every chat/judge test fails until W3 removes those writes).

**W2 — Port the tables (≈ 2 h)**

Apply data-model.md Part C row by row: `runtime-config.ts`, `turn-cap.ts`,
`trial-pool.ts`. Make `content_manifest_url` `.optional()` with the legacy
comment (contracts/worker-api.md §GET /v1/config). Rename tables in tests
(quickstart.md §2 "Rewrite in place" rows that only rename). Gate:
`npm run typecheck` + `npx vitest run --project unit test/unit/turn-cap.test.ts test/unit/trial-pool.test.ts test/unit/trial-pool-runleg.test.ts test/unit/runtime-config.test.ts`
+ `npx vitest run --project contract test/contract/install.test.ts` (trial/chat contract tests still write `usage` until W3).

**W3 — Remove usage + events (≈ 2 h)**

research.md R-5 and R-6, in this order: delete `writeUsage` calls and the
now-dead parameters (`chat-core`, `judge-core`, `condense`, `finish-check`,
`practice-turn`, and the call sites in `routes/chat.ts`, `judge.ts`,
`trial.ts`, `repair.ts`), then delete `lib/usage.ts`; delete the `writeEvent`
block, `lib/events.ts`, `routes/event.ts`, `routes/web-event.ts`, the event
schemas, and their `index.ts` lines. Update tests per quickstart.md §2.
Gate: **full** `npm run typecheck && npm test` green + the Worker sweep grep prints nothing.

**W4 — Daily + practice + config (≈ 2 h)**

`lib/daily-pick.ts`, `routes/daily.ts`, `routes/practice.ts`,
`routes/config.ts`, `routes/manifest.ts` deletion, `index.ts` mounts
(`app.use("/v1/daily", installAuth); app.route("/v1/daily", dailyRoute); app.route("/v1/practice", practiceRoute);`),
`routes/privacy.ts` copy. Tests per quickstart.md §2 "New".

**W5 — Docs (≈ 45 min)**

- `specs/001-proxy-content-contract/contracts/openapi.yaml`: `/v1/install` body; `X-Install-Id` description (`<device_hash>.<sig>`); add `/v1/daily`, `/v1/practice`; remove `/v1/event`, `/v1/web-event`, `/v1/content/manifest.json`, the `/v1/web-demo/*` block and its token scheme.
- `config.schema.json`: drop `rotation` from what the app receives (document it as server-read), mark `content_manifest_url` legacy and remove it from `required`, drop the `web` demo fields (`enabled`, `demo_turn_cap`, `daily_demo_cap`, `max_pool_share`).
- Delete `specs/001-proxy-content-contract/contracts/event.schema.json` and `specs/002-voice-tutor-app/contracts/analytics-events.md`; update `relay-client.md` and `repositories.md` there to match contracts/app-client.md.
- `worker/README.md` §"The daily pointer (`rotation`)" (`:69-96`): the pointer is now applied by `GET /v1/daily`; "Omit `rotation`" now means `dayNumber % pool`, not per-install walking.

### App (≈ 5.5 h)

**A1 — Identity (≈ 1.5 h)**: contracts/app-client.md §1–§2, data-model.md
§B1 + §B4 (the `install_identity` half). Gate: analyze + test.

**A2 — Remove analytics (≈ 2 h)**: contracts/app-client.md §8,
data-model.md §B2 + §B4. Remove call sites first, then parameters, then
delete files, then fix tests. Gate: analyze + test + app sweep grep (the
analytics terms).

**A3 — Daily problem (≈ 2 h)**: contracts/app-client.md §3–§7,
data-model.md §B3. Regenerate code. Gate: analyze + test + full app sweep grep.

### Rollout

quickstart.md §4 on dev, then §5 for prod. Blocked on the Play Data safety update (FR-025: declare "Device or other IDs — fraud
prevention, not shared"; remove "App interactions").

## Implementer guardrails (read before W1)

1. **Never delete an `await ….usage()` call** in `chat-core.ts` or `practice-turn.ts`; on the trial path it settles `provider_day` (research.md R-5).
2. **Every `ON CONFLICT` target on `device_day` is `(device_hash, date, problem_id)`.** A target that does not match the primary key is a runtime SQLite error, not a type error — only the tests catch it.
3. **`releaseTrialStart` must UPDATE, never DELETE** the `devices` row (data-model.md §A2).
4. **Keep TS names** (`installId`, `X-Install-Id`, `install_id` JSON field). Only SQL names change (research.md R-3).
5. **Do not touch `worker/migrations/0001`–`0005`.** They are history; the sweep greps skip them.
6. **Do not remove `content_manifest_url` from the stored config or the `/v1/config` response.**
7. **Do not log or persist the raw Android ID** anywhere — not in Drift, prefs, `console.*`, or error messages.
8. **No new error codes, no new dependencies, no new l10n strings.**
9. Flutter: `unused_import`, `unused_local_variable`, `unused_element`, `unused_field`, `dead_code` are **errors**. After each removal, run `flutter analyze` before moving on.
10. Generated `*.g.dart` / `*.freezed.dart` files are committed — regenerate and commit them with the source change.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None. G-1 (removing first-party analytics) was resolved by amending the constitution to v3.0.0 on 2026-10-06 rather than carried as a violation | The event stream was the largest D1 writer and the main privacy liability; D7 is preserved via `devices` + `device_day` | Keeping `/v1/event` would keep the writes, the 26-event client, the buffered-events table and the privacy disclosure the spec exists to remove |

## Estimate

Worker ≈ 9 h, app ≈ 5.5 h, docs ≈ 45 min — about 2 working days for one
implementer including a dev run-through (quickstart.md §4).

## Risks

- **Carrier-grade NAT on IPv4**: phones behind one Vodafone/Orange IPv4 share `ip_daily_session_cap` (15 in prod). /64 fixes IPv6 only. Follow-ups if it bites: a higher cap for carrier ASNs from `request.cf.asn` via remote config (~1 h), or Play Integrity so the device id alone can be trusted (~½ day).
- **Forged device ids**: a script can send random `device_id`s. Bounded by the per-network cap, `INSTALL_RL` (now per /64), and the `provider_day` budget.
- **Every existing user gets one fresh taster** at cut-over (old rows unmappable). Accepted.
- **Landing site** may still POST `/v1/web-event`; it now gets 404. The site must treat that call as fire-and-forget or drop it (outside this repo).
- **Offline on a new day** shows the withdrawn screen's copy. Copy fix is a follow-up.
- **Old apps between deploy and the config write** (rollout step 4→5) get `400` on chat/trial/judge for under a minute; `/v1/config` keeps working so the update wall still lands.
