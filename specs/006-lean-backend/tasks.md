---

description: "Task list for 006 Lean Backend"
---

# Tasks: Lean Backend — Device Identity, Minimal Server Data, Server-Picked Daily Problem

**Input**: Design documents from `specs/006-lean-backend/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/ (worker-api.md, network-key.md, app-client.md), quickstart.md

**Tests**: Included. The plan and quickstart.md §2–§3 define an exact test map; every test task below comes from it.

**Organization**: Tasks are grouped by user story. Each task cites its plan step (W1–W5, A1–A3) so it can be traced back to plan.md §Execution Order. This file regroups those steps by story; the order of task IDs here is the execution order. Each plan step's gate still applies at the checkpoint named in the phase.

**Before you start**: read plan.md §"Implementer guardrails" (10 rules). They apply to every task.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on an unfinished task)
- **[Story]**: US1–US6 from spec.md
- Paths: Worker under `worker/`, app under `lib/`, `test/`, `integration_test/`, Android under `android/app/src/main/kotlin/app/dryrun/`

## Gate commands (quickstart.md §1)

- Worker: `cd worker && npm run typecheck && npm test`
- App: `flutter analyze` (must print "No issues found!") and `LD_LIBRARY_PATH=/tmp/shim flutter test`
- Worker sweep: `grep -rnE "turn_counter|trial_consumed|trial_budget|runtime_config|writeUsage|writeEvent|FROM usage|FROM events|install_uuid" worker/src worker/test` → prints nothing
- App sweep: `grep -rnE "AnalyticsClient|EventName|BufferedEvents|EventDao|sendEvents|prefetchManifest|ManifestDto|contentManifestUrl|RotationConfig|_pendingUuidKey" lib test integration_test` → prints nothing

---

## Phase 1: Setup

**Purpose**: Toolchain ready, baseline green before any change.

- [X] T001 Install Worker deps with `cd worker && npm ci`; create the sqlite shim `mkdir -p /tmp/shim && ln -sfn /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/shim/libsqlite3.so` (quickstart.md §0)
- [X] T002 Run both gate commands on the untouched branch and record that they pass; if either fails, stop and report (the failure is pre-existing, not part of this feature)

---

## Phase 2: Foundational (blocking)

**Purpose**: The D1 migration and the pure network-key helper. Every later Worker task depends on them.

**⚠ Expected red**: after T003 most Worker tests fail (old table names, `usage`/`events` dropped). The full Worker suite goes green only at the end of Phase 4 (US4). Until then, run only the test files named in each checkpoint.

- [X] T003 Create `worker/migrations/0006_lean_backend.sql` with the exact SQL in plan.md §W1 (rename `runtime_config`→`config`, `trial_budget`→`provider_day`; create `devices` + index `devices_trial_ip` and `device_day`; drop `usage`, `events`, `web_demo_session`, `trial_consumed`, `turn_counter`). Do not touch migrations 0001–0005 (W1.1)
- [X] T004 [P] Create `worker/src/lib/network-key.ts` exporting `networkKey(ip: string): string`, implementing rules 1–7 of contracts/network-key.md exactly (pure, synchronous, never throws) (W1.3)
- [X] T005 [P] Create `worker/test/unit/network-key.test.ts` with every input→output vector in contracts/network-key.md §Test vectors (14 rows). Leave the two `hashIp` assertions for T014 (W1.6)

**Checkpoint**: `cd worker && npm run typecheck && npx vitest run --project unit test/unit/network-key.test.ts` green.

---

## Phase 3: User Story 1 — A reinstall does not reset the free trial (P1) 🎯 MVP

**Goal**: The same phone always gets the same identity and the same `devices` row; old uuid tokens are refused; the app registers with its Android ID.

**Independent test**: `POST /v1/install` twice with the same `device_id` → identical `install_id`; a `devices` row exists holding only the hash. On the phone: complete the taster, reinstall, start the taster → `TRIAL_CONSUMED` (quickstart.md §4 #2, #8).

### Worker (plan W1)

- [X] T006 [US1] In `worker/src/lib/install-id.ts` replace `UUID_V4_RE` with `DEVICE_HASH_RE = /^[0-9a-f]{64}$/` and use it wherever the old regex was used; update the header comment and doc comments (`<uuidv4>` → `<device_hash>`) (W1.2)
- [X] T007 [US1] Rewrite `worker/src/routes/install.ts` per contracts/worker-api.md §POST /v1/install: rate limit `INSTALL_RL.limit({ key: networkKey(ip) })` first; Zod `.strict()` body `{ platform: z.literal("android"), device_id: z.string().trim().toLowerCase().min(1).max(128) }` → 400 `BAD_REQUEST` on any mismatch; `deviceHash` = hex of all 32 bytes of HMAC-SHA256(`INSTALL_HMAC_SECRET`, `"android:" + device_id`) via `crypto.subtle` (same `importKey` shape as `hashIp` in `lib/trial-pool.ts`); `INSERT OR IGNORE INTO devices (device_hash, created_at) VALUES (?1, ?2)` with `nowIso()`; respond `{ install_id: signInstallId(deviceHash, secret) }`. Never log or echo the raw `device_id` (W1.4)
- [X] T008 [P] [US1] In `worker/src/types.ts` update the `Variables.installId` comment: it now holds the 64-hex device hash (keep the name — research.md R-3) (W1.5)
- [X] T009 [US1] In `worker/test/contract/helpers.ts` change `mintInstallId()` to POST `{ platform: "android", device_id: crypto.randomUUID().replace(/-/g, "").slice(0, 16) }`; add `mintInstallIdFor(deviceId: string)`; replace `runtime_config` → `config` in `setRepairConfig`/`setWebConfig` (W1.6, quickstart.md §2)
- [X] T010 [P] [US1] Rewrite `worker/test/unit/install-id.test.ts`: 64-hex fixture instead of `SOME_UUID`; add "a legacy `<uuidv4>.<sig>` signed with the right secret is rejected" (W1.6)
- [X] T011 [P] [US1] Rewrite `worker/test/contract/install.test.ts` with the cases in quickstart.md §2 (200 shape `^[0-9a-f]{64}\.[A-Za-z0-9_-]+$`; same id twice → identical; `"ABC123"` vs `"abc123"` → identical; different ids → different; empty/missing `device_id`, `platform: "ios"`, extra key, legacy `{install_uuid}` → 400; `devices` row with `created_at`; raw id absent from `SELECT * FROM devices`; 429 case unchanged) (W1.6)

**Checkpoint (W1 gate)**: `npm run typecheck && npx vitest run --project unit test/unit/install-id.test.ts test/unit/network-key.test.ts && npx vitest run --project contract test/contract/install.test.ts` green. Commit.

### App (plan A1)

- [ ] T012 [P] [US1] Create `android/app/src/main/kotlin/app/dryrun/DeviceIdChannel.kt` (shape of `TrustedTimeChannel.kt`; channel `app.dryrun/device_id`, method `androidId` → `Settings.Secure.getString(contentResolver, ANDROID_ID)`, else `notImplemented()`), and wire it in `MainActivity.kt` (field, `attach` in `configureFlutterEngine`, `detach` in `cleanUpFlutterEngine`) per contracts/app-client.md §1 (A1)
- [ ] T013 [P] [US1] Create `lib/core/device/device_id_platform.dart` (`DeviceIdPlatform` interface + `MethodChannelDeviceIdPlatform`, 5 s timeout, `PlatformException`/`MissingPluginException`/`TimeoutException`/blank → `null`) per contracts/app-client.md §1; create `test/fakes/fake_device_id_platform.dart` (`FakeDeviceIdPlatform({this.id = 'abc123def4567890'})`); add `'device_id'` to the channel list in `test/unit/brand_test.dart:59-76` (A1)
- [ ] T014 [US1] Change `lib/core/network/dto/install_dto.dart`: `InstallRequestDto{String platform; String deviceId}` (snake case); in `lib/core/network/relay_client.dart` change `install(String installUuid)` → `install(String deviceId)` sending `InstallRequestDto(platform: 'android', deviceId: deviceId)`; run `dart run build_runner build --delete-conflicting-outputs` (contracts/app-client.md §3) (A1)
- [ ] T015 [US1] Rewrite `ensureIdentity()` in `lib/features/onboarding/data/install_repository_impl.dart` per contracts/app-client.md §2: constructor takes `required DeviceIdPlatform deviceIdPlatform` instead of `Uuid? uuid`; delete `_pendingUuidKey` and all its uses; store `installUuid` = `response.installId.split('.').first`; null Android ID → `Err(RelayError.badRequest())` with no relay call. Update the registration in `lib/core/di/service_locator.dart` (register `DeviceIdPlatform` next to `TrustedTimePlatform` at `:62-64`; pass `deviceIdPlatform: sl<DeviceIdPlatform>()`, drop `uuid:`) (A1)
- [ ] T016 [US1] In `lib/core/db/app_database.dart` bump `schemaVersion` 5 → 6 and add the v6 upgrade step with only `DELETE FROM install_identity` for now (data-model.md §B1/§B4; the `DROP TABLE` line is added in T054) (A1)
- [ ] T017 [P] [US1] Create `test/unit/install_repository_test.dart`: (a) no row → `relayClient.install('abc123def4567890')` called, stored `installUuid` = part before `.`; (b) existing row → no relay call; (c) platform returns null → `Err(RelayError.badRequest())`, no relay call (contracts/app-client.md §2) (A1)
- [ ] T018 [US1] Update `test/db/migration_test.dart`: `schemaVersion` assertion (`:30-34`) → 6; add a "v5 → v6" case that seeds an `install_identity` row, runs `db.migration.onUpgrade(Migrator(db), 5, 6)`, asserts `install_identity` is empty and a seeded completed session is intact (`_expectSessionIntact`); rename "v1 → v5" to "v1 → v6". The `buffered_events` half of the case is added in T056 (data-model.md §B4) (A1)

**Checkpoint (A1 gate)**: app `flutter analyze` + `flutter test` green. Commit.

---

## Phase 4: User Story 4 — Free limits keep working on the smaller data model (P1)

**Goal**: Every cap behaves exactly as before, now stored in `devices`, `device_day`, `provider_day`; the `usage` and `events` writes are gone. Per-network caps count IPv6 by /64.

**Independent test**: the full Worker suite (cap, refund, judge-once, hint ladder, network cap, provider budget) passes unchanged in outcome; the new IPv6 case and the reinstall case pass.

### Port the tables (plan W2)

- [X] T019 [US4] In `worker/src/lib/trial-pool.ts` make `hashIp()` (≈ `:358`) hash `` `ip:${networkKey(ip)}` ``; append the two `hashIp` equalities from contracts/network-key.md to `worker/test/unit/network-key.test.ts` (W1.3)
- [X] T020 [US4] In `worker/src/lib/runtime-config.ts`: `FROM runtime_config` → `FROM config`; make `content_manifest_url` `z.string().url().optional()` with the comment `// Legacy: served only so pre-006 apps can still parse /v1/config and reach the update wall. Read by nothing.` Do not remove it from the stored config or the response (guardrail 6) (W2, data-model.md Part C)
- [X] T021 [US4] Port all six functions in `worker/src/lib/turn-cap.ts` per data-model.md Part C: `turn_counter`→`device_day`, `install_id`→`device_hash`, every `ON CONFLICT(...)` → `ON CONFLICT(device_hash, date, problem_id)`, qualifier `turn_counter.`→`device_day.` (guardrail 2) (W2)
- [X] T022 [US4] Port every statement in `worker/src/lib/trial-pool.ts` per data-model.md Part C, row by row (`selectMember`, `reserveEstimate`, `settleTrialBudget`, `releaseEstimate`, `setCooldown`, `getTrialConsumed`, `bumpPracticeTurn`, `releasePracticeTurn`, `markTrialStarted`, `ipSessionGateOk`, `releaseTrialStart`, `markTrialCompleted`, `countSessionsStartedToday`). `TrialConsumedRow.startedAt` becomes `string | null`. `releaseTrialStart` must UPDATE, never DELETE (guardrail 3) (W2)
- [X] T023 [P] [US4] Rename tables in Worker tests that only need renames (quickstart.md §2): `trial_budget`→`provider_day` in `worker/test/unit/trial-pool*.test.ts` and `trial-exhausted.test.ts`; `runtime_config`→`config` in `web-cors.test.ts`, `chat.guards`, `chat.wrapup-lever`, `config.*-lever`, `config.killed`, `trial-judge-retry` tests; `worker/test/harness/lib/live-client.ts` (`runtime_config`→`config`, install body → `{ platform: "android", device_id: … }`) (W2)
- [X] T024 [P] [US4] Rewrite `worker/test/contract/trial-ip-limit.test.ts` `seedSessions` to `INSERT INTO devices (device_hash, created_at, trial_started_at, trial_problem_id, trial_date, trial_ip_hash) VALUES (?1, ?2, ?2, 'vp-0001', ?3, ?4)` with a random 64-hex hash; the two `trial_consumed` reads → `devices.trial_ip_hash`; add the IPv6 case: 15 sessions under `hashIp("2a02:c7c:1234:5678::1")`, a new device from `2a02:c7c:1234:5678::99` → 429 `TRIAL_IP_LIMIT`, from `2a02:c7c:1234:9999::1` → 200 (W2, quickstart.md §2)
- [X] T025 [P] [US4] Update `worker/test/contract/trial.practice.test.ts` (`trial_consumed` reads → `devices` with `trial_` columns; `DELETE FROM turn_counter WHERE install_id` → `DELETE FROM device_day WHERE device_hash`) and `worker/test/contract/repair.no-turn.test.ts` (`turn_counter`/`install_id` → `device_day`/`device_hash`) (W2)
- [X] T026 [P] [US4] Update `worker/test/unit/trial-isolation.test.ts` first case to forbid `"provider_day"`, `"trial_started_at"`, `"trial_problem_id"`, `"trial_completed_at"`, `"trial_ip_hash"` outside the three trial files (W2)

**Checkpoint (W2 gate)**: `npm run typecheck` + `npx vitest run --project unit test/unit/turn-cap.test.ts test/unit/trial-pool.test.ts test/unit/trial-pool-runleg.test.ts test/unit/runtime-config.test.ts` + `npx vitest run --project contract test/contract/install.test.ts` green. Commit.

### Remove usage + events writes (plan W3, research.md R-5/R-6)

- [X] T027 [US4] Delete every `writeUsage` call and the parameters that only fed it, per research.md R-5: `ChatTurnDeps.usageEndpoint`, `.condenseUsageEndpoint`, `.finishCheckUsageEndpoint` and the `"usageEndpoint"` entry in `runHintTurn`'s `Pick<>` in `worker/src/lib/chat-core.ts`; `JudgeDeps.usageEndpoint` in `judge-core.ts`; `condense()`'s 6th param + `CondenseUsageContext` in `condense.ts`; `runFinishCheck()`'s 4th param + `FinishCheckContext` in `finish-check.ts`; rename `PracticeTurnOptions.usageId` → `installId` in `practice-turn.ts`. Delete the locals R-5 lists. **Keep every `await ….usage()` call** (guardrail 1) (W3)
- [X] T028 [US4] Update the call sites in `worker/src/routes/chat.ts`, `judge.ts`, `trial.ts`, `repair.ts` to the new signatures from T027; then delete `worker/src/lib/usage.ts` (W3)
- [X] T029 [US4] Delete the `writeEvent` block in `worker/src/lib/judge-core.ts` (≈ `:115-122`) and the now-unused `verdictOverridden, from, to` destructure; delete `worker/src/lib/events.ts`, `worker/src/routes/event.ts`, `worker/src/routes/web-event.ts`; delete `EVENT_NAMES`, `eventPropsSchema`, `eventItemSchema`, `eventBatchSchema`, `EventBatch` and their comment from `worker/src/lib/schemas.ts` (≈ `:98-153`; confirm no other importer with `grep -rn "eventBatchSchema\|EVENT_NAMES" worker/src`); remove the event and web-event imports, `use` and mounts from `worker/src/index.ts`. Keep `WEB_EVENT_RL` and `middleware/web-cors.ts` (W3, research.md R-6)
- [X] T030 [P] [US4] Delete `worker/test/unit/usage.test.ts`, `worker/test/contract/usage-record.test.ts`, `worker/test/contract/event.test.ts`, `worker/test/contract/web-event.test.ts` (W3)
- [X] T031 [P] [US4] In `worker/test/unit/condense.test.ts` drop the 6th argument from every `condense(...)` call and delete the two usage-only tests (`:102-121`, `:123-143`); in `worker/test/unit/condense.linear.test.ts` drop the 6th argument (W3)
- [X] T032 [P] [US4] Replace `usage`-table evidence in contract tests per quickstart.md §2: `chat.per-key-routing.test.ts:151-155` (capture the judge request body in the gemini `fetchMock` reply, assert `model === "gemini-flash-latest"`); `trial.test.ts:110-120` (assert a `provider_day` row for `groq` today with `tokens_spent > 0`); `chat.key-check.test.ts:56-57` (delete the assertion) (W3)
- [X] T033 [P] [US4] Replace `usage`-table evidence in repair/finish tests per quickstart.md §2: `repair.levers.test.ts` (`usageCountFor` → a call counter in the `fetchMock` reply); `repair.guards.test.ts` (delete `repairUsageRow`/`leak_blocked` assertions, keep the body assertions); `finish-offer.test.ts` (delete the two `usage` counts at `:120`, `:141`, keep `meta.ready_to_finish` and the `890` budget assertion, `trial_budget`→`provider_day`) (W3)
- [X] T034 [P] [US4] In `worker/test/contract/judge.override.test.ts` keep the verdict-overwrite assertions (`:69-71`) and delete the `events` query + assertions (`:73-86`). In `worker/test/unit/no-content-persisted.test.ts` set `TABLES = ["config", "devices", "device_day", "provider_day", "notify_signup"]` and delete the `/v1/event` call (`:91-95`) — it must pass at this checkpoint (W3)
- [X] T035 [US4] Create `worker/test/contract/install.device.test.ts`: mint with `mintInstallIdFor(X)` → run a trial chat + judge to completion (copy the flow from `trial.test.ts`) → mint again for X → `/v1/trial` chat returns 409 `TRIAL_CONSUMED`; a different `device_id` still gets a taster (quickstart.md §2 "New"; proves US1 AS-1 end to end)

**Checkpoint (W3 gate)**: **full** `cd worker && npm run typecheck && npm test` green + Worker sweep prints nothing. Commit. US1 and US4 now both pass on the Worker.

---

## Phase 5: User Story 2 — The server picks today's problem (P1)

**Goal**: `GET /v1/daily?date=` returns the picked problem's public half and writes the D7 activity row; the app fetches it instead of picking locally; `rotation` is no longer sent to the app.

**Independent test**: today → 200 with the expected problem; today+2 → 400; two devices same date → same id; `device_day` row exists (quickstart.md §4 #3, #4).

### Worker (plan W4)

- [X] T036 [P] [US2] Create `worker/src/lib/daily-pick.ts` exporting pure `pickDaily(problems, cfg, date): PublicHalf | null` and `dayNumber(d)`, implementing steps 1–5 of contracts/worker-api.md §GET /v1/daily exactly (eligible excludes killed and `PRACTICE_COLLECTION`; dated wins; pool id-sorted; pointer pick as a port of the app's `_pointerPick`; else `dayNumber % pool.length`) (W4)
- [X] T037 [P] [US2] Create `worker/test/unit/daily-pick.test.ts` with the cases in quickstart.md §2 "New" (dated wins; killed dated skipped; practice never picked even if dated; pointer anchor day / +1 / wrap-around / unknown start id → 0 / future anchor → clamp / bad anchor → 0 elapsed; no pointer → `dayNumber % pool`; all killed → `null`) using small synthetic arrays (W4)
- [X] T038 [US2] Create `worker/src/routes/daily.ts` per contracts/worker-api.md §GET /v1/daily: validate `date` (regex + real calendar day) and the ±1-day window → 400 `BAD_REQUEST`; `getRuntimeConfig` + `getPublicManifest` → `pickDaily`; `null` → 409 `PROBLEM_KILLED`; `INSERT OR IGNORE INTO device_day (device_hash, date, problem_id) VALUES (?1, ?2, ?3)` with the requested date; 200 `{ date, problem }` with `cache-control: private, no-store`. Mount in `worker/src/index.ts`: `app.use("/v1/daily", installAuth); app.route("/v1/daily", dailyRoute);` (W4)
- [X] T039 [US2] In `worker/src/routes/config.ts` strip rotation too: `const { web: _web, rotation: _rotation, ...appCfg } = cfg;` (W4)
- [X] T040 [P] [US2] Create `worker/test/contract/daily.test.ts` with every case in quickstart.md §2 "New" (no header / legacy token → 400; today 200 + `no-store`; same date two devices → same id; ±2 → 400, +1 → 200; malformed date → 400; `device_day` row with zero counters; second call keeps seeded `turns = 3`; all killed → 409; no private key names / editorial text — take these assertions from `test/contract/manifest.test.ts`) (W4)
- [X] T041 [P] [US2] Rewrite `worker/test/contract/config.rotation-lever.test.ts`: keep the three "refuses a malformed …" cases; replace the "served verbatim" cases with "rotation is never served by /v1/config, even when set" (W4, quickstart.md §2)

**Checkpoint**: full Worker gate green. Commit.

### App (plan A3, daily half)

- [ ] T042 [US2] Add `DailyResponseDto{String date; PublicHalfDto problem}` (`@JsonSerializable(fieldRename: FieldRename.snake)`) to `lib/core/network/dto/problem_dto.dart`; add `Future<DailyResponseDto> daily({required String installId, required String date})` to `lib/core/network/relay_client.dart` (`GET /v1/daily?date=` with `_headers(installId: installId)`, error mapping copied from `manifest()`); add `byManifestDate(String date)` to `lib/core/db/dao/problem_dao.dart` (data-model.md §B3); run `dart run build_runner build --delete-conflicting-outputs` (contracts/app-client.md §3) (A3)
- [ ] T043 [US2] In `lib/features/problem/domain/problem_repository.dart` add `fetchDaily(String date)` and `cachedForDate(String date)` (keep `prefetchManifest` until T061); in `lib/features/problem/data/problem_repository_impl.dart` add constructor param `required InstallRepository installRepository`, extract `_companion(dto, {servedFor, fetchedAt})` from the insert mapping (`:55-78`), implement `fetchDaily` and `cachedForDate` per contracts/app-client.md §4; update the DI registration and direct constructions in `test/unit/leak_blocked_test.dart:104`, `counter_projection_test.dart:84`, `summary_covers_test.dart:99` (A3)
- [ ] T044 [US2] Rewrite `forToday()` in `lib/features/daily/data/daily_repository_impl.dart` per contracts/app-client.md §5 (cache-for-today unless killed → else `fetchDaily(today)` → `RelayException` → `NoProblemAvailableException`); delete `_pointerPick` and the `RotationConfig` import (A3)
- [ ] T045 [US2] Remove `rotation` from the app config: delete `rotation` + `RotationConfigDto` from `lib/core/network/dto/config_dto.dart` and `rotation` + `RotationConfig` + its `fromDto` mapping from `lib/core/config/runtime_config.dart`; in `test/unit/remote_config_test.dart` remove `rotation` from fixtures and delete the rotation round-trip test (`:122-136`); regenerate code (contracts/app-client.md §7, rotation half only) (A3)
- [ ] T046 [US2] Update `test/fakes/fake_problem_repository.dart` and `_ScriptedProblemRepository` in `integration_test/first_launch_seed_test.dart` for the new methods (`fetchDailyResult`, `fetchDailyError`, `cachedByDate` map) (A3, quickstart.md §3)
- [ ] T047 [P] [US2] Rewrite `test/unit/daily_repository_test.dart` per quickstart.md §3 (cached+not killed → no fetch; cached+killed → refetch; no cache → `fetchDaily(today)`; `isRepeat` from `completedProblemIds()`; `problemKilled` / `transport` with no cache → `NoProblemAvailableException`); delete the pointer group (A3)
- [ ] T048 [P] [US2] Create `test/unit/problem_repository_test.dart` with the `fetchDaily` / `cachedForDate` cases from quickstart.md §3 (stores `manifestDate = date`, returns the domain problem, `cachedForDate` finds it) (A3)

**Checkpoint**: app gate green. Commit.

---

## Phase 6: User Story 5 — Nothing about the learner's activity is stored beyond the limits (P2)

**Goal**: The app sends no analytics and drops its event buffer; the server stores only the five tables; the privacy page says so.

**Independent test**: a full session leaves rows only in `config`, `devices`, `device_day`, `provider_day`, `notify_signup` (`no-content-persisted.test.ts`); the privacy page wording matches; the app sweep finds no analytics terms.

### Worker

- [X] T049 [P] [US5] Update `worker/src/routes/privacy.ts` copy per contracts/worker-api.md §Privacy page (install-identifier row → hashed device identifier; delete "App interaction events" row and the website "Counts." paragraph; replace the last sentence of "Keeping and deleting data"; bump `LAST_UPDATED`) (W4)
- [X] T050 [US5] In `worker/test/unit/no-content-persisted.test.ts` add a `/v1/daily` call to the session (the `TABLES` list and `/v1/event` removal were done in T034) (W4, quickstart.md §2)

### App (plan A2) — remove call sites first, then params, then files, then tests; run `flutter analyze` after each task

- [ ] T051 [US5] Delete every analytics `emit` call listed in contracts/app-client.md §8 (30 sites across `daily_session_cubit.dart`, `key_entry_cubit.dart`, `welcome_screen.dart`, `main.dart` (+ `'analytics.has_launched_before'` prefs), `remote_config_repository.dart`, `outbox_drain_bloc.dart`, `review_day_screen.dart`); delete any local that becomes unused (A2)
- [ ] T052 [US5] Remove `ShareCard.onShared` end to end: param/field/call in `lib/features/streak/presentation/share_card.dart`, `recordShare()` in `daily_session_cubit.dart`, `onShared:` in `verdict_screen.dart:268` and `review_day_screen.dart:88`, `onShared: _noop` (and `_noop` if unused) in `test/widget/share_and_retry_test.dart:52` (A2)
- [ ] T053 [US5] Remove the `AnalyticsClient` parameter, field and plumbing at every site listed in contracts/app-client.md §8 (`service_locator.dart`, `main.dart:117`, `app_router.dart`, `daily_session_shell.dart`, `daily_session_cubit.dart`, `welcome_screen.dart`, `review_day_screen.dart`, `key_entry_cubit.dart`, `key_entry_form.dart`, `outbox_drain_bloc.dart`, `remote_config_repository.dart`) (A2)
- [ ] T054 [US5] Drop the event buffer: remove `BufferedEvents` from `lib/core/db/tables.dart` and the `@DriftDatabase` `tables:` list, `EventDao` from `daos:`, the `bufferedEvents` delete in `wipeAllExceptInstallIdentity()`; add `DROP TABLE IF EXISTS buffered_events` to the v6 step in `lib/core/db/app_database.dart` (data-model.md §B2/§B4); delete `lib/core/analytics/`, `lib/core/db/dao/event_dao.dart`, `lib/core/network/dto/event_dto.dart` (+ generated files); delete `sendEvents` from `relay_client.dart`; regenerate code (A2)
- [ ] T055 [US5] Fix tests: delete `test/unit/analytics_contract_test.dart`, `analytics_drain_test.dart`, `analytics_payload_test.dart`, `test/fakes/fake_analytics_client.dart`; remove `analyticsClient: FakeAnalyticsClient()` from every construction (`grep -rln FakeAnalyticsClient test integration_test`); delete `.emitted` assertions (delete a test case if that was its only assertion); in `test/security/no_key_leak_test.dart` drop the `AnalyticsClientImpl` construction (`:192-199`) and `buffered_events` from `_dumpEveryTable` (contracts/app-client.md §8) (A2)
- [ ] T056 [US5] Extend the "v5 → v6" case in `test/db/migration_test.dart`: create a raw `buffered_events` table + one row before the upgrade, assert `SELECT name FROM sqlite_master WHERE name = 'buffered_events'` returns nothing after (data-model.md §B4) (A2)

**Checkpoint (A2 gate)**: app gate green + the analytics terms of the app sweep (`AnalyticsClient|EventName|BufferedEvents|EventDao|sendEvents`) print nothing; Worker gate green. Commit.

---

## Phase 7: User Story 3 — The warm-up problem is available without registering (P2)

**Goal**: `GET /v1/practice` serves the warm-up without auth; the catalogue download is gone from the Worker and the app.

**Independent test**: `curl /v1/practice | jq .problem.id` → `"vp-0000"`; `/v1/content/manifest.json` → 404 (quickstart.md §4 #5, #6).

### Worker (plan W4)

- [X] T057 [US3] Create `worker/src/routes/practice.ts` per contracts/worker-api.md §GET /v1/practice (no auth; first id-sorted problem with `PRACTICE_COLLECTION` not in `killed_problem_ids`; none → 409 `PROBLEM_KILLED`; 200 `{ problem }` with `cache-control: public, max-age=3600`); mount with `app.route("/v1/practice", practiceRoute)` in `worker/src/index.ts` (W4)
- [X] T058 [US3] Delete `worker/src/routes/manifest.ts` and its import + mount in `worker/src/index.ts`; delete `worker/test/contract/manifest.test.ts` (its private-field assertions now live in T040 and T059) (W4)
- [X] T059 [P] [US3] Create `worker/test/contract/practice.test.ts` (no header → 200 with `collections` containing `practice`; `cache-control: public, max-age=3600`; practice id killed → 409; no private fields) (W4)

### App (plan A3, practice half)

- [ ] T060 [US3] Add `PracticeResponseDto{PublicHalfDto problem}` to `lib/core/network/dto/problem_dto.dart` and delete `ManifestDto`; in `relay_client.dart` add `practice()` (`GET /v1/practice`, no install header) and delete `manifest()`; regenerate code (contracts/app-client.md §3) (A3)
- [ ] T061 [US3] In `problem_repository.dart` / `problem_repository_impl.dart`: add `fetchPractice()` (upsert with `servedFor: null`); delete `prefetchManifest()` and `_prefetchWindowDays`; remove the `configRepository` constructor param; update DI and the direct constructions touched in T043 (contracts/app-client.md §4) (A3)
- [ ] T062 [US3] Replace the `prefetchManifest()` call sites per contracts/app-client.md §6: `lib/main.dart:87` and `seeding_screen.dart:183` → `fetchPractice()`; `withdrawn_screen.dart:61` → delete the call and its try/catch; `key_repository_impl.dart` `_anyProbeProblem` → `practiceProblem()` first, then lowest-id of `available(config)`, then the existing `Err(RelayError.transport())` (A3)
- [ ] T063 [US3] Remove `contentManifestUrl` from `ConfigDto` (`config_dto.dart`) and `RuntimeConfig` (`runtime_config.dart`); remove `content_manifest_url` from fixtures in `test/unit/remote_config_test.dart`; regenerate code (contracts/app-client.md §7) (A3)
- [ ] T064 [US3] Update `test/fakes/fake_problem_repository.dart` and `integration_test/first_launch_seed_test.dart` for `fetchPractice` (`fetchPracticeCalls` counter) and the removed `prefetchManifest`; make `test/widget/seeding_screen_test.dart` and `test/widget/onboarding_test.dart` compile against the new fake; add the `fetchPractice` → `practiceProblem()` case to `test/unit/problem_repository_test.dart` (quickstart.md §3) (A3)

**Checkpoint (A3 gate)**: app gate green + **full** app sweep prints nothing; Worker gate green + Worker sweep prints nothing. Commit.

---

## Phase 8: User Story 6 — Old app versions are moved to the new version cleanly (P2)

**Goal**: Old apps can still parse `/v1/config` and reach the update wall; the updated app discards its old identity (done in T016/T018).

**Independent test**: `/v1/config` has `content_manifest_url` and no `rotation`/`web`; an old build against dev with raised `min_supported_version` shows "Update required" (quickstart.md §4 #1, #12).

- [X] T065 [US6] Add a case to `worker/test/contract/config.test.ts`: the `/v1/config` body has no `rotation` and no `web`, and still has `content_manifest_url` (quickstart.md §2)
- [X] T066 [US6] Re-run `worker/test/unit/config-consumers.test.ts` unchanged and confirm it passes (quickstart.md §2: `content_manifest_url` is still an app-only lever served verbatim); if it fails, stop and report

**Checkpoint**: Worker gate green. Commit.

---

## Phase 9: Polish & cross-cutting (plan W5 + rollout)

- [ ] T067 [P] Update `specs/001-proxy-content-contract/contracts/openapi.yaml` per plan.md §W5 (new `/v1/install` body; `X-Install-Id` = `<device_hash>.<sig>`; add `/v1/daily`, `/v1/practice`; remove `/v1/event`, `/v1/web-event`, `/v1/content/manifest.json`, the `/v1/web-demo/*` block and its token scheme) (FR-024)
- [ ] T068 [P] Update `specs/001-proxy-content-contract/contracts/config.schema.json` per plan.md §W5 (drop app-facing `rotation`, documented as server-read; `content_manifest_url` legacy and not `required`; drop `web` demo fields `enabled`, `demo_turn_cap`, `daily_demo_cap`, `max_pool_share`); delete `specs/001-proxy-content-contract/contracts/event.schema.json` (FR-024)
- [ ] T069 [P] Delete `specs/002-voice-tutor-app/contracts/analytics-events.md`; update `relay-client.md` and `repositories.md` in the same folder to match contracts/app-client.md §3–§4 (FR-024)
- [ ] T070 [P] Update `worker/README.md` §"The daily pointer (`rotation`)" (`:69-96`): the pointer is applied by `GET /v1/daily`; omitting `rotation` means `dayNumber % pool`, not per-install walking
- [ ] T071 Run both full gates and both sweeps one last time; all green and empty. Commit
- [ ] T072 Owner: deploy to dev and run quickstart.md §4 scenarios 1–12 (`wrangler d1 migrations apply dry-run-tutor-dev --env dev --remote && wrangler deploy --env dev`)
- [ ] T073 Owner, release blockers before merging to `main` / prod rollout: (a) copy the constitution v3.0.0 amendment (already synced to `.specify/memory/constitution.md`, plan.md G-1) into the external source of record `docs/constitution.md`; (b) update Play Data safety (FR-025: add "Device or other IDs — fraud prevention, not shared"; remove "App interactions"); (c) tell the landing-site owner `/v1/web-event` now returns 404
- [ ] T074 Owner: production rollout per quickstart.md §5 steps 1–6 (export prod D1 first; app live on Play before the migration; raise `min_supported_version` in the same minute as the deploy)

---

## Dependencies & execution order

```
Setup (T001–T002)
  └─ Foundational (T003–T005)
       └─ US1 Worker (T006–T011) ── US1 App (T012–T018)   [app half has no Worker dependency]
            └─ US4 (T019–T035)   ← full Worker suite green here
                 └─ US2 (T036–T048)
                      └─ US5 (T049–T056)   [Worker T050 needs /v1/daily from US2]
                           └─ US3 (T057–T064)   [needs US2's ProblemRepository changes]
                                └─ US6 (T065–T066)
                                     └─ Polish (T067–T074)
```

- **Worker red window**: T003 → T035. Only the per-checkpoint test files are expected green in between.
- **US1 ↔ US4**: US1's end-to-end proof (T035, reinstall → `TRIAL_CONSUMED`) runs in Phase 4, because the trial path writes `usage` until T027–T029.
- **US2 → US3 (app)**: T057–T064 delete `prefetchManifest` and `contentManifestUrl`, which only works after T043–T046 introduced the new repository methods.
- **US5 app (T051–T055)** is independent of US2/US3 app tasks in file terms except `daily_session_cubit.dart` and `service_locator.dart`; do not run it in parallel with T043–T046.

## Parallel opportunities

- Phase 2: T004 ‖ T005
- US1: T008 ‖ T010 ‖ T011 (after T006–T007); T012 ‖ T013 ‖ T017
- US4: T023 ‖ T024 ‖ T025 ‖ T026 (after T020–T022); T030 ‖ T031 ‖ T032 ‖ T033 ‖ T034 (after T027–T029)
- US2: T036 ‖ T037; T040 ‖ T041 (after T038–T039); T047 ‖ T048 (after T046)
- US5: T049 ‖ T051 (Worker vs app)
- US3: T059 alongside T060
- Polish: T067 ‖ T068 ‖ T069 ‖ T070

Example (US4 test rewrites, one agent per file):

```
Task: "T023 rename tables in trial-pool*/config.* tests"
Task: "T024 rewrite trial-ip-limit.test.ts seeds + IPv6 case"
Task: "T025 update trial.practice + repair.no-turn tests"
Task: "T026 update trial-isolation.test.ts"
```

## Implementation strategy

- **MVP = Phases 1–4 (US1 + US4)**: closes the reinstall trial leak on the Worker with every limit intact and the full Worker suite green (~6 h). Not shippable alone: the app's analytics and manifest calls still hit removed routes until US2/US3/US5 land, and the release blockers in T073 apply.
- **Shippable = Phases 1–8** (~14.5 h, plan.md §Estimate), then Polish and the owner-run rollout.
- Commit once per checkpoint. Never start a phase with the previous checkpoint red.
