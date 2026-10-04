# dry-run-worker

The tutor & assessment relay (Cloudflare Worker). See `specs/001-proxy-content-contract/` for the full spec, plan, and task list.

## Local setup

```sh
cd worker
npm install
npm run build:content                              # content/problems/*.json -> src/generated/*
npx wrangler d1 migrations apply dry-run-dev --local --env dev
npm run dev                                         # picks up worker/.dev.vars — http://localhost:8787
```

`worker/.dev.vars` is committed with **placeholder** values only (`INSTALL_HMAC_SECRET`, `TRIAL_KEY_GROQ`) — enough for `npm test` (provider stubbed) but not for a real call. For a live `wrangler dev` session against a real provider, put your own values in an env-suffixed override instead of editing the tracked file: `worker/.dev.vars.dev` (gitignored), same `KEY="value"` shape, then run `wrangler dev --env dev` so it's picked up. Never commit a real key.

Offline checks (no key, no network — the gate that runs on every PR):

```sh
npm run typecheck
npm run validate:content
npm run verify:examples  # each problem's reference solution vs its public examples
npm test              # unit + contract, provider stubbed
```

Adding a problem: follow `content/AUTHORING.md`, and run `npm run check:content` (validate, verify examples, build).

`npm run test:harness` additionally needs a real `GROQ_API_KEY` and the full three-problem content set; see `specs/001-proxy-content-contract/quickstart.md` §7.

## Replaying a tutor turn (`npm run replay:tutor`)

Reproduces one tutor turn from a real conversation against live Groq and reports, per run, what the leak filter did with the draft: `CLEAN`, `REWRITTEN` (the one retry with the blocked words named), `CUT TO CLEAN LEAD`, or `FALLBACK`. Needs a real key and spends real tokens:

```sh
GROQ_API_KEY=gsk_... npm run replay:tutor -- tools/replay-samples/pair-sum-full-answer.json --runs 8
```

The file is a JSON array of `{"role": "user" | "tutor", "text"}` turns ending on the learner's, the same shape as `messages` on `POST /v1/chat`. Options: `--problem` (default `vp-0001`), `--runs`, `--gap` (seconds between calls; a free key hits Groq's tokens-per-minute limit fast), `--model`. The runtime_config values it builds the prompt with are constants at the top of `tools/replay-tutor.ts`.

## Client fail-open obligation (GET /v1/config)

`GET /v1/config` gates app launch. If it is unreachable — network error, timeout, non-2xx — **the client MUST fall back to its last cached response** rather than blocking. Config must never be able to lock a learner out (Constitution X.3). This is a client-side requirement; the Worker's only job is to serve the current levers with a `Cache-Control` and `ETag` header so the client has something to cache in the first place (`worker/src/routes/config.ts`).

## Changing a lever with no redeploy

Every lever lives in the single `runtime_config` row (`contracts/config.schema.json`). Read the current payload, edit the JSON, write it back:

```sh
npx wrangler d1 execute dry-run-dev --local \
  --command "SELECT payload FROM runtime_config WHERE id = 1"

# edit the JSON, then:
npx wrangler d1 execute dry-run-dev --local \
  --command "UPDATE runtime_config SET payload = '<edited JSON>', updated_at = datetime('now') WHERE id = 1"
```

Drop `--local` (and use the `dev`/`prod` D1 database name) to change a deployed environment. `GET /v1/config` reflects the change on its next read (no cache on the server side — see the client fail-open note above for the client's own cache).

Levers, one line each — full detail in `contracts/config.schema.json` and `specs/001-proxy-content-contract/data-model.md` §A5:

| Lever | Effect |
|---|---|
| `chat.turn_cap` | The primary quota lever — turns allowed per session. |
| `chat.wrap_up_at_turn` | Turn index from which the tutor prompt nudges toward a close. |
| `chat.min_turn_chars` | Below this, `EMPTY_TURN` before the provider is called. |
| `model` / `provider` | Which model and which upstream serve chat and judge. |
| `trim.verbatim_turns` / `trim.narrow_after_turn` / `trim.narrow_margin` / `trim.condense_model` | Condensation window and ground-truth narrowing. |
| `killed_problem_ids` | Pull a problem same-day, no release. |
| `rotation.start_problem_id` / `rotation.anchor_date` | The global daily pointer — see below. |
| `ads.enabled` | `false` takes both ad surfaces off every install — see below. |
| `trial.turn_cap` / `trial.ground_truth_tier` / `trial.condense` / `trial.daily_session_cap` / `trial.pool` | The trial funnel's own profile and provider pool. |

## The daily pointer (`rotation`)

`rotation` decides which problem **every** install gets on a given day. Set it and the answer is the same for a year-old install and one made this morning:

```
problem = evergreen_pool_sorted_by_id[ index(start_problem_id) + whole_days_since(anchor_date) ]
```

wrapped around the end of the pool. It advances on its own — set it once, not daily.

Restart everyone at the first problem, one write, no release:

```sh
npx wrangler d1 execute dry-run-prod --remote \
  --command "UPDATE runtime_config SET payload = json_set(payload, '\$.rotation.start_problem_id', 'vp-0000', '\$.rotation.anchor_date', date('now')), updated_at = datetime('now') WHERE id = 1"
```

Devices pick it up within their config cache window; there is no push.

Four things worth knowing before you move it:

- **Omit `rotation` entirely** and each install falls back to walking its own un-attempted problems — the pre-pointer behaviour, still the default in the seeded row.
- **A problem authored for exactly today outranks the pointer.** Dated problems are an explicit override and are not in the rotation pool.
- **A bad pointer is a loud failure, not a quiet one.** A `start_problem_id` or `anchor_date` that fails the schema makes `GET /v1/config` return 502 rather than serving a wrong problem everywhere; a well-formed id that is withdrawn or not yet in the manifest degrades to the top of the pool.
- **The pointer does not erase local history.** A learner who has seen today's problem before still gets `isRepeat` recorded locally (FR-035c) and sees no marker for it (FR-035b).

## The ad kill switch (`ads.enabled`)

Turns off both ad surfaces — the rewarded hint video and the assessment interstitial — on every install, with no release and no store review:

```sh
npx wrangler d1 execute dry-run-prod --remote \
  --command "UPDATE runtime_config SET payload = json_set(payload, '\$.ads.enabled', json('false')), updated_at = datetime('now') WHERE id = 1"
```

Back on: `json('true')`. Installs pick it up on their next launch.

- **This row is the only thing that decides.** There is no compile-time ads switch any more: no `ADS_ENABLED` dart-define, no app-side config file. One place to look, and it is reachable without a release.
- **Off is the default.** Omit `ads`, serve a config written before this key existed, or fail to reach the relay on a first launch, and the answer is no ads. Absent means off, not "ask someone else".
- **It takes a launch to turn ads ON.** `AdsService.initialize()` only starts the SDKs once the config says yes, so a fresh install with ads enabled picks them up after `/seeding` has fetched the config. Turning them OFF needs no init at all and takes effect on the next check.
- **Switching ads off never costs a learner anything.** The hint still arrives when the rewarded video is skipped (FR-004); the assessment opens without the interstitial (FR-009).
- **Mid-session changes wait.** The flag is re-read on every check rather than captured at startup, but a learner already inside a session keeps the surfaces that session started with.

## Two-environment deploy

```sh
npx wrangler deploy --env dev
npx wrangler deploy --env prod
```

Each environment has its own D1 database (`wrangler.jsonc`) and its own secrets (`wrangler secret put INSTALL_HMAC_SECRET --env dev`, one `TRIAL_KEY_*` per enabled pool member).
