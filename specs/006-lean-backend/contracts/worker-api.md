# Contract — Worker HTTP API changes (006)

Delta against `specs/001-proxy-content-contract/contracts/openapi.yaml`.
Every error uses the existing envelope from `lib/errors.ts`
(`{ "error": { "code", "message", "retryable" } }`). **No new error code is
added**; the catalogue stays closed.

## Summary

| Route | Change |
|---|---|
| `POST /v1/install` | New request body; response shape unchanged; now writes `devices` |
| `GET /v1/daily?date=YYYY-MM-DD` | **New**, install-auth |
| `GET /v1/practice` | **New**, no auth |
| `GET /v1/config` | Response no longer contains `rotation`. `content_manifest_url` is **still served** (legacy, see below) |
| `GET /v1/content/manifest.json` | **Removed** (404 from Hono's default) |
| `POST /v1/event` | **Removed** |
| `POST /v1/web-event` | **Removed** |
| `/v1/chat`, `/v1/judge`, `/v1/repair`, `/v1/trial` | Unchanged wire format. They accept the new token only |
| `POST /v1/notify`, `GET /privacy` | Unchanged route; privacy wording changes |

---

## POST /v1/install

Rate limit first (unchanged order): `INSTALL_RL.limit({ key: networkKey(ip) })`
where `ip = CF-Connecting-IP ?? "unknown"`. Refused → `429 RATE_LIMITED`.

Request (`application/json`, Zod `.strict()`):

```json
{ "platform": "android", "device_id": "9f2c4e1a7b3d5f60" }
```

| Field | Rule |
|---|---|
| `platform` | `z.literal("android")` |
| `device_id` | `z.string().trim().toLowerCase().min(1).max(128)` — the `Settings.Secure.ANDROID_ID` value |

Any other shape, an extra key, or an empty `device_id` → `400 BAD_REQUEST`.

Processing:

1. `deviceHash = hex(HMAC-SHA256(INSTALL_HMAC_SECRET, "android:" + device_id))`
   → 64 lowercase hex chars. (`device_id` is already trimmed + lowercased by Zod.)
2. `INSERT OR IGNORE INTO devices (device_hash, created_at) VALUES (?1, ?2)`
   with `?2 = nowIso()`. A reinstall hits the existing row and changes nothing.
3. `install_id = signInstallId(deviceHash, INSTALL_HMAC_SECRET)` →
   `"<deviceHash>.<base64url sig>"`.

Response `200` — unchanged shape:

```json
{ "install_id": "<64 hex>.<base64url>" }
```

The app keeps no local trial flag; a reinstalled phone learns the taster is
spent from `/v1/trial` → `409 TRIAL_CONSUMED`, exactly as today (US1 AS-1).

Same `device_id` → same `install_id`, every time (deterministic HMAC).

## Token verification (install-auth, unchanged header)

`X-Install-Id: <64 lowercase hex>.<base64url HMAC-SHA256 over the hex>`.

- `lib/install-id.ts`: replace `UUID_V4_RE` with `DEVICE_HASH_RE = /^[0-9a-f]{64}$/`.
- A legacy `<uuidv4>.<sig>` token fails the regex → `400 BAD_REQUEST` (FR-005).
- `c.get("installId")` now returns the 64-hex device hash.

## GET /v1/daily

Mounted behind `installAuth` (`app.use("/v1/daily", installAuth)`).

Query: `date` — required, `^\d{4}-\d{2}-\d{2}$`, and a real calendar day
(`new Date(date + "T00:00:00Z").toISOString().slice(0, 10) === date`).

Window: let `today = utcDate()`. Refuse with `400 BAD_REQUEST` when
`|dayNumber(date) − dayNumber(today)| > 1`, where
`dayNumber(d) = Math.floor(Date.parse(d + "T00:00:00Z") / 86_400_000)`.
(One day either side absorbs device/server midnight skew; two days ahead is
always refused — SC-004.)

Selection — a **pure** function `pickDaily(problems, cfg, date)` in a new
`worker/src/lib/daily-pick.ts`, returning a `PublicHalf` or `null`:

1. `eligible` = manifest problems where
   `!cfg.killed_problem_ids.includes(p.id)` AND
   `!(p.collections ?? []).includes(PRACTICE_COLLECTION)`.
2. If some `p` in `eligible` has `p.date === date` → return it (first such).
3. `pool` = `eligible.filter(p => p.date === undefined)`, sorted by `id`
   ascending (plain string compare; ids are `vp-NNNN`). Empty → return `null`.
4. If `cfg.rotation` is present → **pointer pick** (exact port of the app's
   `_pointerPick`, `lib/features/daily/data/daily_repository_impl.dart:88-103`):
   - `startIndex = pool.findIndex(p => p.id === cfg.rotation.start_problem_id)`; if `< 0` use `0`.
   - `elapsed = dayNumber(date) − dayNumber(cfg.rotation.anchor_date)`; if
     either parse is `NaN` use `0`; if `elapsed < 0` use `0`.
   - return `pool[(startIndex + elapsed) % pool.length]`.
5. Else → `pool[dayNumber(date) % pool.length]`.

Route:

- `null` from `pickDaily` → `409 PROBLEM_KILLED` (every candidate withdrawn;
  the app already routes this to `/withdrawn`).
- Otherwise `INSERT OR IGNORE INTO device_day (device_hash, date, problem_id)
  VALUES (?1, ?2, ?3)` with the **requested** `date` and the picked id —
  the D7 activity row (FR-017). Then respond.

Response `200`, `cache-control: private, no-store`:

```json
{ "date": "2026-10-06", "problem": { /* PublicHalf, exactly as in the built manifest */ } }
```

`problem` is the manifest entry verbatim (`schema_version`, `id`, optional
`date`, `title`, `ramp`, `difficulty`, `tags`, `source`, `statement`,
`constraints`, `examples`, `est_speak_seconds`, `collections`,
`glossary_terms`, `hint_count`). No private field is reachable: the
manifest is already public-only (`assertNoPrivateLeak` at build time).

## GET /v1/practice

No auth. No D1 access.

- Pick the first problem (id-sorted) whose `collections` contains
  `PRACTICE_COLLECTION` and whose id is **not** in `cfg.killed_problem_ids`.
  (This needs `getRuntimeConfig` — one D1 read.)
- None → `409 PROBLEM_KILLED`.
- `200`, `cache-control: public, max-age=3600`:

```json
{ "problem": { /* PublicHalf */ } }
```

## GET /v1/config

`routes/config.ts`: strip `rotation` as well as `web`:

```ts
const { web: _web, rotation: _rotation, ...appCfg } = cfg;
```

**`content_manifest_url` stays in the stored config and in this response.**
Old apps parse `/v1/config` with a `ConfigDto` whose `contentManifestUrl`
is `required` (`lib/core/network/dto/config_dto.dart:96`). If the key
disappears, their parse fails, they fall back to the cached config, and
they **never see the raised `min_supported_version`** — the update wall
(SC-008) would silently not appear. So:

- Worker schema: `content_manifest_url: z.string().url().optional()` (was required),
  with a comment `// Legacy: served only so pre-006 apps can still parse /v1/config and reach the update wall. Read by nothing.`
- Migration `0006` does **not** touch the payload.
- The new app drops the field from its `ConfigDto` (json_serializable ignores
  unknown keys by default), so it is harmless.
- Removing it for good is a follow-up once no pre-006 install remains.

## Removed routes

Delete the file **and** its import + mount in `worker/src/index.ts`:

| Route | File | `index.ts` lines today |
|---|---|---|
| `/v1/content/manifest.json` | `routes/manifest.ts` | import L12, mount L33 |
| `/v1/event` | `routes/event.ts` | import L15, `use` L35, mount L36 |
| `/v1/web-event` | `routes/web-event.ts` | import L17, comment L37, `use` L38, mount L39 |

`WEB_EVENT_RL` binding stays (`routes/notify.ts` uses it). `webCors`
middleware stays (`/v1/notify` uses it). `eventBatchSchema`, `EVENT_NAMES`
and the event item/props schemas in `lib/schemas.ts` are deleted (no other
importer — verify with `grep -rn "eventBatchSchema\|EVENT_NAMES" worker/src`).

## Privacy page (`routes/privacy.ts`)

- Row "An install identifier": Data → `A hashed device identifier`; Why →
  `Enforces the free limits — one free taster per phone, daily turn caps`;
  Where → `Our relay. Only a one-way keyed hash of Android's per-app device ID is stored, never the ID itself; it is not linked to you`.
- Delete the row "App interaction events".
- "On our website" → delete the `<p><strong>Counts.</strong> …</p>` paragraph
  (the web-event route is gone).
- "Keeping and deleting data" → replace the last sentence with:
  `The hashed device identifier and the per-day counters on our relay are not tied to your identity and cannot be traced back to you.`
- Bump `LAST_UPDATED`.
