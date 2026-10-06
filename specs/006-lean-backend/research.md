# Research — 006 Lean Backend

Every decision below was checked against the code on `006-lean-backend`
(2026-10-06). File:line references are to that tree.

## R-1 Device identifier: `Settings.Secure.ANDROID_ID`

- **Decision**: Register with `ANDROID_ID`, read natively through a
  MethodChannel. Server stores `HMAC-SHA256(INSTALL_HMAC_SECRET, "android:" + id)`.
- **Rationale**: Since Android 8.0 (API 26) `ANDROID_ID` is scoped per
  (app-signing key, user, device) and **survives uninstall/reinstall and
  "clear data"**; it changes only on factory reset or a signing-key change.
  That is exactly the "same phone, same trial" property FR-003 needs. It
  needs no permission. Play policy allows it for fraud prevention when
  declared under Data safety → "Device or other IDs" (FR-025).
- **Consequences**:
  - Debug and release builds are signed with different keys, so on one phone
    they get different ids. Dev and prod use different D1 databases anyway.
  - `device_id` is self-reported; a script can send random ids. Bound by
    the per-network trial cap, `INSTALL_RL`, and the `provider_day` budget
    (spec Assumptions). Play Integrity is the follow-up if this is abused.
  - Normalise before hashing: `trim()` + lower-case (Zod in `routes/install.ts`),
    so `"ABC"` and `"abc"` are one device.
- **Alternatives rejected**: random UUID (today; resets on reinstall — the
  bug being fixed); `Build.SERIAL`/IMEI (need privileged permissions, banned
  by Play); Play Integrity / Firebase Installation ID (new SDK — Constitution
  Quality Gates forbid third-party SDKs except advertising; also more work).

## R-2 Hash and token format

- **Decision**: `device_hash` = 64 lowercase hex of the HMAC above. The
  token keeps today's format and header: `X-Install-Id: <device_hash>.<base64url HMAC(device_hash)>`.
  Only the regex in `lib/install-id.ts:6` changes (`UUID_V4_RE` → `/^[0-9a-f]{64}$/`).
- **Rationale**: Smallest change: `signInstallId`/`verifyInstallId`,
  `middleware/install-auth.ts`, and every `installId.split(".")[0]` in tests
  keep working. One secret, domain-separated inputs (`"android:"…`, `"ip:"…`,
  bare 64-hex for the signature), so no input of one kind can equal another.
- **Old tokens**: a `<uuidv4>.<sig>` fails the new regex → `400 BAD_REQUEST`
  (FR-005). Old apps are walled by `min_supported_version` (R-9).
- **Alternatives rejected**: renaming the header to `X-Device-Token` (touches
  the app's interceptor and every contract test for no behaviour gain);
  sending the bare hash with no signature (a client could then present any
  other device's hash it learned).

## R-3 Keep TypeScript names, change SQL names

- **Decision**: `Variables.installId`, `TurnCounterKey.installId`, every
  `installId` parameter, and the JSON field `install_id` keep their names.
  Only tables and columns are renamed.
- **Rationale**: ~40 files reference `installId`. Renaming them is pure churn
  and a large surface for a missed spot. A comment on `Variables.installId`
  (`types.ts:21-26`) records that it now holds the device hash.

## R-4 Five tables, and how `trial_consumed` folds into `devices`

- **Decision**: As in data-model.md. `trial_consumed` columns move onto
  `devices` with a `trial_` prefix; `releaseTrialStart` becomes an UPDATE
  that clears them.
- **Rationale**: The `devices` row must exist from `/v1/install` (it holds
  `created_at`, the D7 cohort day). The old code relied on "no row" =
  "never touched the trial". With an always-present row, `getTrialConsumed`
  returns a row whose `problemId` and `completedAt` are `null`, and
  `isTasterUnclaimed()` (`trial-pool.ts:282`) is `true` for it — so
  `routes/trial.ts:139` takes the same "new session" branch it took for `null`.
  `practiceTurnsUsed()` returns 0 for both. Behaviour is identical (FR-012).
- **Upserts, not plain UPDATEs**: `bumpPracticeTurn` and `markTrialStarted`
  stay `INSERT … ON CONFLICT(device_hash) DO UPDATE`, so a device row that is
  somehow missing (e.g. a test that writes a token directly) is created
  rather than silently not counted.
- **`startedAt` type**: `TrialConsumedRow.startedAt` becomes `string | null`.
  Nothing in `src/` reads it (`grep -n "startedAt" worker/src/lib/trial-pool.ts worker/src/routes/trial.ts`
  shows only the timestamp parameters, not the row field).

## R-5 Removing `usage`: what replaces it

- **Decision**: Delete `lib/usage.ts` and every `writeUsage` call. Remove
  the parameters that existed only to feed it:
  - `ChatTurnDeps.usageEndpoint`, `.condenseUsageEndpoint`, `.finishCheckUsageEndpoint` (`chat-core.ts:43,44,67`) and the `"usageEndpoint"` entry in `runHintTurn`'s `Pick<>` (`chat-core.ts:133`).
  - `JudgeDeps.usageEndpoint` (`judge-core.ts:27`).
  - `condense()`'s 6th parameter `usageContext` and the `CondenseUsageContext` interface (`condense.ts:35-42,54`).
  - `runFinishCheck()`'s 4th parameter `ctx` and `FinishCheckContext` (`finish-check.ts:21-28,71`).
  - `PracticeTurnOptions.usageId` is renamed `installId` (`practice-turn.ts:20`) — it still feeds `turn-cap` keys.
- **Rationale**: Trial budget settlement reads usage from the provider
  result (`settleTrialBudget(...)` calls in `trial.ts:208,240,284` and
  `practice-turn.ts:61`), not from the table, so nothing that enforces a
  limit reads `usage`. Leaving dead parameters would invite the implementer
  to keep threading them.
- **⚠ Do NOT delete any `await ….stream.usage()` call** in `chat-core.ts`
  (`firstUsage` ≈ L285, `secondUsage` ≈ L303) or `practice-turn.ts`. On the
  trial path `usage()` is the wrapper that runs `settleTrialBudget()`
  (`trial.ts:206-210`, `practice-turn.ts:59-63`). Deleting the call silently
  leaves the 1,600-token estimate in `provider_day` instead of the real
  figure, and `finish-offer.test.ts`'s exact budget assertion (`890`) fails.
  Keep the `await`; you may drop the variable it is assigned to.
- **Locals that become unused** after deleting the writes (TypeScript
  `strict` does not flag unused locals, but delete them anyway for clarity):
  `latencyMs`/`startedAt` in `condense.ts`, `startedAt` in `finish-check.ts`,
  `startedAt` in the key-check branch of `chat-core.ts` (≈ L86),
  `startedAt`/`inputTokens`/`outputTokens`/`providerId`/`model` accumulation
  in `runConversationalTurn` (≈ L283-310, keep the `usage()` awaits per the
  warning above), `latencyMs`/`inputTokens`/`outputTokens` and the
  `verdictOverridden, from, to` destructure in `judge-core.ts`.
  Keep `leakBlocked` in chat-core — it feeds the meta frame.
- **Tests that used `usage` as evidence** switch to evidence that still
  exists — see quickstart.md §Worker test map.

## R-6 Removing `events`

- **Decision**: Delete `lib/events.ts`, `routes/event.ts`, `routes/web-event.ts`,
  the `writeEvent` block in `judge-core.ts:115-122`, the event schemas in
  `lib/schemas.ts` (lines 98–153: the comment, `EVENT_NAMES`, `eventPropsSchema`,
  `eventItemSchema`, `eventBatchSchema`, `EventBatch`; only `routes/event.ts`
  imports them). Keep `WEB_EVENT_RL`
  (used by `routes/notify.ts`) and `middleware/web-cors.ts`.
- **Lost measurements**: input-mode split (Principle I) and hint-pull rate
  (Principle X). The spec's Dependencies section requires the constitution
  amendment to drop or replace them. **Not this feature's call** — see
  plan.md Constitution Check, gate G-1.
- **Landing site**: it may still POST to `/v1/web-event`. After this change
  that returns 404. The site must ignore failures of that call (it is
  fire-and-forget analytics) or drop it. Flag to the owner; the site lives
  outside this repo.

## R-7 Server-picked daily problem

- **Decision**: `GET /v1/daily?date=` with a pure `pickDaily()`
  (contracts/worker-api.md). Pool order = id ascending; fallback =
  `dayNumber(date) % pool.length`.
- **Behaviour change, intended (spec US2 AS-3)**: with no pointer, the app
  today walks **this install's** un-attempted problems
  (`daily_repository_impl.dart:58-62`). The server cannot see local history,
  so every device now gets the same problem by day number. `isRepeat`
  remains a local fact computed by the app from `completedProblemIds()`.
- **Pointer port**: byte-for-byte the app's `_pointerPick`
  (`daily_repository_impl.dart:88-103`): unknown start id → index 0;
  unparseable anchor → 0 elapsed; anchor in the future → clamp 0.
- **Date window ±1 day**: the app sends its trusted UTC date (Constitution IX).
  ±1 absorbs midnight skew between trusted time and the Worker clock. +2 is
  refused (SC-004). Server uses the **requested** date for both the pick and
  the `device_day` row.
- **All withdrawn → `409 PROBLEM_KILLED`**: reuses an existing catalogue code
  (`errors.ts:15`) rather than adding one. The app maps it to its existing
  `NoProblemAvailableException` → `/withdrawn`.
- **Offline (FR-020)**: the app caches what it fetched. No look-ahead
  prefetch: a fetch for tomorrow would write a `device_day` row for a day the
  learner may never open, corrupting D7. Chat needs the network every turn
  anyway (Constitution VIII accepts that), so offline on a new day shows the
  existing no-problem state.
- **Kill mid-day**: if today's cached problem appears in
  `config.killedProblemIds`, the app refetches instead of serving the cache.
- **Alternatives rejected**: keep the manifest and only add `/v1/daily`
  (spec FR-019 requires the manifest gone); sign the pick and let the app
  verify (no threat model needs it).

## R-8 IPv6 /64 network key

- **Decision**: contracts/network-key.md. Applied inside `hashIp()` (so
  every caller and existing test seed keeps calling `hashIp(ip, secret)`)
  and to the `INSTALL_RL` key.
- **Rationale**: an IPv6 subscriber is delegated at least a /64; counting the
  full address lets one phone rotate addresses freely. IPv4 behind carrier
  NAT is unchanged and stays a known limitation (spec Assumptions).
- **Rate-limit key**: Cloudflare's rate-limit binding takes any string key,
  so `networkKey(ip)` is a drop-in.

## R-9 Cut-over

- **Decision**: rollout order in plan.md §Rollout: export prod → dev
  run-through → app live on Play → apply `0006` + deploy prod Worker →
  raise `min_supported_version` within the same minute.
- **Rationale**: `/v1/config` keeps working for old apps across the cut, so
  the "Update required" wall still reaches them (SC-008). Their
  chat/trial/judge calls fail with `400 BAD_REQUEST` for the seconds between
  deploy and the config write.
- **Config stays parseable by old apps**: the original plan removed
  `content_manifest_url` from the stored config. That breaks the cut-over:
  pre-006 apps declare it `required` in `ConfigDto`
  (`lib/core/network/dto/config_dto.dart:96`), so a payload without it fails
  their parse, they fall back to the cached config, and the raised
  `min_supported_version` never reaches them. Decision: keep the key in D1
  and in the `/v1/config` response, optional in the Worker schema, read by
  nothing; the new app drops it from its DTO. This also removes the
  "strict schema rejects stale payload → total outage" risk entirely
  (SC-007). Verify with `curl https://<prod>/v1/config` after deploy anyway.
- **Existing users**: every device gets one fresh taster at cut-over (old
  rows are keyed by random uuids that map to no device). Accepted in the spec.

## R-10 Migration mechanics (D1 / SQLite)

- `ALTER TABLE … RENAME TO …` is supported by D1 and carries data, indexes
  and the `CHECK` constraint.
- `wrangler d1 migrations apply` wraps each file in a transaction; a failure
  rolls the whole file back.
- `DROP TABLE` drops the table's indexes with it.
- Tests: `test/apply-migrations.ts` applies every file in `worker/migrations/`
  in order, so `0006` runs in every unit/contract test automatically.
  Nothing in `vitest.config.ts` needs to change.

## R-11 What stays deliberately unchanged

- `/v1/chat`, `/v1/judge`, `/v1/trial`, `/v1/repair` still accept any
  manifest `problem_id`. Enforcing "only today's problem" server-side is
  out of scope (keyed learners reopen past problems from review).
- `getPublicManifest()` stays — routes resolve ids against it; only the route
  that served it whole is removed.
- Learner data (history, verdicts, streak) stays on the device (memory:
  minimal backend data).
