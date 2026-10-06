# Quickstart — validating 006 Lean Backend

How to prove the feature works, phase by phase. Contracts:
[worker-api.md](contracts/worker-api.md), [network-key.md](contracts/network-key.md),
[app-client.md](contracts/app-client.md). Tables: [data-model.md](data-model.md).

## 0. Prerequisites

- Node per `worker/package.json`; `cd worker && npm ci`.
- Flutter 3.41.3 (system `flutter`, same as CI). Not fvm.
- Drift tests on this host need the sqlite shim (README.md:52-57):
  `mkdir -p /tmp/shim && ln -sfn /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 /tmp/shim/libsqlite3.so`
- After any change to a `@JsonSerializable`/Drift/freezed file:
  `dart run build_runner build --delete-conflicting-outputs` (generated files are committed).

## 1. Gate commands (run after every phase)

```bash
# Worker
cd worker && npm run typecheck && npm test

# App
flutter analyze                       # must print "No issues found!"
LD_LIBRARY_PATH=/tmp/shim flutter test
```

Leftover-reference sweeps (each must print nothing):

```bash
# Worker, after W2/W3
grep -rnE "turn_counter|trial_consumed|trial_budget|runtime_config|writeUsage|writeEvent|FROM usage|FROM events|install_uuid" worker/src worker/test
# App, after A2/A3
grep -rnE "AnalyticsClient|EventName|BufferedEvents|EventDao|sendEvents|prefetchManifest|ManifestDto|contentManifestUrl|RotationConfig|_pendingUuidKey" lib test integration_test
```

(`worker/migrations/000[1-5]_*.sql` legitimately keep the old names; the sweep excludes them by only scanning `src` and `test`.)

## 2. Worker test map

### Delete

| File | Why |
|---|---|
| `test/unit/usage.test.ts` | `usage` gone |
| `test/contract/usage-record.test.ts` | `usage` gone |
| `test/contract/event.test.ts` | route gone |
| `test/contract/web-event.test.ts` | route gone |
| `test/contract/manifest.test.ts` | route gone — move its "no private key name or editorial text in the body" assertions into `daily.test.ts` and `practice.test.ts` |

### Rewrite in place

| File | Change |
|---|---|
| `test/contract/helpers.ts` | `mintInstallId()` posts `{ platform: "android", device_id: <random 16 hex> }` (e.g. `crypto.randomUUID().replace(/-/g, "").slice(0, 16)`). Add `mintInstallIdFor(deviceId: string)`. Replace `runtime_config` → `config` in `setRepairConfig`/`setWebConfig` |
| `test/contract/install.test.ts` | New body. Cases: 200 shape `^[0-9a-f]{64}\.[A-Za-z0-9_-]+$`; same `device_id` twice → identical `install_id`; `"ABC123"` and `"abc123"` → identical; different ids → different; empty / missing `device_id`, `platform: "ios"`, extra key, legacy `{install_uuid}` → 400; `devices` row exists with `created_at`; raw id not present anywhere in `SELECT * FROM devices`; 429 case unchanged |
| `test/unit/install-id.test.ts` | Use a 64-hex fixture instead of `SOME_UUID`; add "a legacy `<uuidv4>.<sig>` signed with the right secret is rejected" |
| `test/contract/judge.override.test.ts` | **Keep** the verdict-overwrite assertions (`:69-71`); delete the `events` query + assertions (`:73-86`) |
| `test/contract/config.rotation-lever.test.ts` | Keep the three "refuses a malformed …" cases (config still validates `rotation`). Replace the "served verbatim" cases with: "rotation is never served by /v1/config, even when set". Pointer behaviour moves to `daily.test.ts` |
| `test/contract/chat.per-key-routing.test.ts` `:151-155` | Replace the `usage` query: capture the outbound judge request body in the gemini `fetchMock` reply callback (pattern: `helpers.ts` `sendTurnCapturingSystemPrompt`) and assert its `model === "gemini-flash-latest"` |
| `test/contract/trial.test.ts` `:110-120` | Replace the `usage` query: assert `provider_day` has a row for `groq` today with `tokens_spent > 0` |
| `test/contract/chat.key-check.test.ts` `:56-57` | Delete the `usage` assertion; the `turn_index` assertions above it already prove the key check spent no turn |
| `test/contract/repair.levers.test.ts` | `usageCountFor` → count intercepted repair-model calls via `fetchMock` instead (a call counter in the reply callback) |
| `test/contract/repair.guards.test.ts` | `repairUsageRow` / `leak_blocked` assertions → delete them; keep the response-body assertions (`repaired`, `changed`), which already prove the guard |
| `test/contract/finish-offer.test.ts` `:120`, `:141` | Delete the two `usage` count assertions; keep the `meta.ready_to_finish` and `provider_day` budget (`890`) assertions; `trial_budget` → `provider_day` |
| `test/unit/condense.test.ts` | Drop the 6th `usageContext` argument from every `condense(...)` call; delete the two tests that only assert `usage` rows (`:102-121` "writes nothing to D1…", `:123-143` "writes exactly one `condense` usage row…") |
| `test/unit/condense.linear.test.ts` | Drop the 6th argument |
| `test/unit/no-content-persisted.test.ts` | `TABLES = ["config", "devices", "device_day", "provider_day", "notify_signup"]`; delete the `/v1/event` call (`:91-95`); add a `/v1/daily` call to the session |
| `test/unit/trial-isolation.test.ts` | First case: forbid `"provider_day"`, `"trial_started_at"`, `"trial_problem_id"`, `"trial_completed_at"`, `"trial_ip_hash"` outside the three trial files |
| `test/unit/config-consumers.test.ts` | No change needed — `content_manifest_url` is still an app-only lever served verbatim. Re-run to confirm |
| `test/contract/trial-ip-limit.test.ts` | `seedSessions`: `INSERT INTO devices (device_hash, created_at, trial_started_at, trial_problem_id, trial_date, trial_ip_hash) VALUES (?1, ?2, ?2, 'vp-0001', ?3, ?4)` with a random 64-hex hash; the two `trial_consumed` reads → `devices.trial_ip_hash`. **Add** the IPv6 case (below) |
| `test/contract/trial.practice.test.ts` | `trial_consumed` reads → `devices` with `trial_` column names; `DELETE FROM turn_counter WHERE install_id` → `DELETE FROM device_day WHERE device_hash` |
| `test/contract/repair.no-turn.test.ts` | `turn_counter`/`install_id` → `device_day`/`device_hash` |
| `test/unit/trial-pool*.test.ts`, `trial-exhausted.test.ts` | `trial_budget` → `provider_day` |
| `test/unit/web-cors.test.ts`, `chat.guards`, `chat.wrapup-lever`, `config.*-lever`, `config.killed`, `trial-judge-retry` | `runtime_config` → `config` |
| `test/harness/lib/live-client.ts` | `runtime_config` → `config`; install body → `{ platform: "android", device_id: … }` |

### New

| File | Cases |
|---|---|
| `test/unit/network-key.test.ts` | Every vector in contracts/network-key.md + the two `hashIp` equalities |
| `test/unit/daily-pick.test.ts` | Pure `pickDaily()`: dated problem wins; killed dated problem skipped; practice never picked even if dated; pointer on anchor day / +1 / wrap-around / unknown start id → index 0 / future anchor → clamp / bad anchor date → 0 elapsed; no pointer → `dayNumber % pool`; all killed → `null`. Build small synthetic problem arrays — do not depend on the real manifest size |
| `test/contract/daily.test.ts` | No `X-Install-Id` → 400 `BAD_REQUEST`; legacy token → 400; today → 200 with `{date, problem}`; `cache-control` contains `no-store`; same date from two devices → same `problem.id`; `date` = today+2 → 400; today−2 → 400; today+1 → 200; malformed `date` (`2026-13-01`, `abc`, missing) → 400; `device_day` row exists for (device, date, problem) with all counters 0; second call does not create a second row or reset counters (seed `turns = 3` first); every manifest problem killed via config → 409 `PROBLEM_KILLED`; body contains no private key names / editorial text |
| `test/contract/practice.test.ts` | No header → 200 `{problem}` with `collections` containing `practice`; `cache-control: public, max-age=3600`; practice id killed → 409; no private fields |
| `test/contract/install.device.test.ts` | Reinstall keeps the taster used: mint for `device_id` X → run a trial chat + judge to completion (copy the flow from `trial.test.ts`) → mint again for X → `/v1/trial` chat returns 409 `TRIAL_CONSUMED`. A different `device_id` still gets a taster |
| `trial-ip-limit.test.ts` (added case) | Seed 15 sessions under `hashIp("2a02:c7c:1234:5678::1")`; a new device from `2a02:c7c:1234:5678::99` → 429 `TRIAL_IP_LIMIT`; a new device from `2a02:c7c:1234:9999::1` → 200 |
| `test/contract/config.test.ts` (added case) | `/v1/config` body has no `rotation` and no `web`, and still has `content_manifest_url` |

## 3. App test map

| File | Change |
|---|---|
| `test/unit/daily_repository_test.dart` | Rewrite against `FakeProblemRepository` (or a mocked `RelayClient` under the real `ProblemRepositoryImpl`). Cases: cached for today and not killed → no fetch; cached but killed → refetch; no cache → `fetchDaily(today)` result; `isRepeat` true when id ∈ `completedProblemIds()`; relay `problemKilled` → `NoProblemAvailableException`; relay `transport` with no cache → `NoProblemAvailableException`. Delete the whole pointer group (now server-side, covered by `daily-pick.test.ts`) |
| `test/unit/problem_repository_test.dart` (new) | `fetchDaily` stores `manifestDate = date` and returns the domain problem; `cachedForDate` finds it; `fetchPractice` stores with `manifestDate = null` and `practiceProblem()` finds it |
| `test/unit/install_repository_test.dart` (new) | See contracts/app-client.md §2 |
| `test/db/migration_test.dart` | v5 → v6 case; schemaVersion 6 (data-model.md §B4) |
| `test/unit/remote_config_test.dart` | Drop `content_manifest_url`/`rotation` from fixtures; delete the rotation test |
| `test/fakes/fake_problem_repository.dart` | Implement the new interface: `fetchDailyResult`, `fetchDailyError`, `cachedByDate` map, `fetchPracticeCalls` counter |
| `integration_test/first_launch_seed_test.dart` | `_ScriptedProblemRepository` implements the new interface |
| `test/widget/seeding_screen_test.dart`, `test/widget/onboarding_test.dart` | Compile against the new fake; drop `FakeAnalyticsClient` |
| `test/unit/brand_test.dart` | Add `'device_id'` to the channel list |
| Analytics tests | See contracts/app-client.md §8 |

## 4. End-to-end scenarios (dev Worker + dev build on a phone)

Deploy: `cd worker && npx wrangler d1 migrations apply dry-run-tutor-dev --env dev --remote && npx wrangler deploy --env dev`.

| # | Scenario | Expected | Proves |
|---|---|---|---|
| 1 | `curl -s https://<dev>/v1/config \| jq 'has("rotation"), has("content_manifest_url")'` | `false`, `true` | SC-007, FR-019 |
| 2 | `curl -s -XPOST https://<dev>/v1/install -H 'content-type: application/json' -d '{"platform":"android","device_id":"abc123"}'` twice | same `install_id` both times | FR-003 |
| 3 | `curl -s "https://<dev>/v1/daily?date=$(date -u +%F)" -H "X-Install-Id: <token>"` | 200 `{date, problem}` | US2 |
| 4 | Same with `date=$(date -u -d '+2 day' +%F)` | 400 `BAD_REQUEST` | FR-015, SC-004 |
| 5 | `curl -s https://<dev>/v1/practice \| jq .problem.id` | `"vp-0000"` | US3 |
| 6 | `curl -s -o /dev/null -w '%{http_code}' https://<dev>/v1/content/manifest.json` and `-XPOST /v1/event` | `404`, `404` | FR-010, FR-019 |
| 7 | Phone: fresh install → onboarding → warm-up → today's problem → trial session to verdict | works as before | US4 |
| 8 | Phone: uninstall, reinstall, onboard, start the taster | `TRIAL_CONSUMED` → key wall copy | US1, SC-001 |
| 9 | Phone: airplane mode, reopen app same day | today's problem shown from cache | FR-020 |
| 10 | `npx wrangler d1 execute dry-run-tutor-dev --env dev --remote --command "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE '\_%' ESCAPE '\' AND name NOT LIKE 'sqlite_%' AND name <> 'd1_migrations'"` | exactly `config, devices, device_day, provider_day, notify_signup` | SC-002 |
| 11 | D7 query from data-model.md §A7 with today's date as cohort | runs, returns a number or NULL | FR-022, SC-005 |
| 12 | Old (pre-006) build against dev after `UPDATE config SET payload = json_set(payload, '$.min_supported_version', '<new>') WHERE id = 1` | "Update required" on launch | SC-008 |

## 5. Production rollout (owner runs this)

1. `cd worker && npx wrangler d1 export dry-run-tutor --env prod --remote --output ../backup-$(date -u +%F).sql` — keep it outside git.
2. Scenarios 1–12 pass on dev.
3. Publish the new app on Play; wait until the update is live.
4. `npx wrangler d1 migrations apply dry-run-tutor --env prod --remote && npx wrangler deploy --env prod`.
5. Within the same minute: `npx wrangler d1 execute dry-run-tutor --env prod --remote --command "UPDATE config SET payload = json_set(payload, '$.min_supported_version', '<new version>'), updated_at = strftime('%Y-%m-%dT%H:%M:%SZ','now') WHERE id = 1"`.
6. Scenario 1 against prod, then scenario 10 against prod.
