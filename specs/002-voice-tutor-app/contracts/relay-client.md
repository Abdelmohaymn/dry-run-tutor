# Contract — the relay client

**Feature**: 002-voice-tutor-app | Consumes [feature 001's frozen contract](../../001-proxy-content-contract/contracts/openapi.yaml)

This is the 001 contract restated as the *client's* obligations. It adds nothing to the wire format
and changes nothing about it. Where the app has a choice, the choice is recorded; where it has none,
the requirement is cited.

**One host, and that is enforced.** `HostAllowlistInterceptor` rejects any request whose host is not
the configured relay before it reaches the socket (FR-004, Principle VI). Base URL:
`https://dry-run-tutor.dryrun-app.workers.dev` (`lib/core/config/relay.dart`).

---

## Headers

| Header | Sent on | Rule |
|---|---|---|
| `X-Install-Id` | `/v1/chat`, `/v1/judge`, `/v1/repair`, `/v1/trial`, `/v1/daily` — not `/v1/config` or `/v1/practice` | `<device_hash>.<base64url HMAC>` (64 lowercase hex, a dot, the signature) from `/v1/install`, stored in Drift (§1) |
| `X-User-Key` | `/v1/chat`, `/v1/judge` | Read from secure storage per request, never cached in a field, never logged. **Absent on `/v1/trial`** — that path spends the operator's credential |
| `X-Provider` | `/v1/chat`, `/v1/judge` | The provider the stored key belongs to. Must be a member of `config.keyed_providers`. **Never sent on `/v1/trial`** — that path ignores it and pool selection is the pool's decision |
| `Content-Type` | POST bodies | `application/json` |
| `Accept` | `/v1/chat`, `/v1/trial` mode=chat | `text/event-stream` |

**A stored provider id that has dropped out of `keyed_providers` must be caught at config load and
re-prompted, not sent.** An unoffered value is `BAD_REQUEST`, never a silent fallback — the header
exists precisely to stop a credential being relayed to a host it does not belong to.

**The app never holds a provider base URL.** It names a provider identity; the relay resolves the
host from a table compiled into the Worker. If a URL for `api.groq.com` or
`generativelanguage.googleapis.com` ever appears in `lib/`, that is the bug this design exists to
prevent.

---

## `POST /v1/install`

Called exactly once, at first launch, before anything else.

```
→ { "platform": "android", "device_id": "<Settings.Secure.ANDROID_ID>" }
← { "install_id": "<64 hex device hash>.Yk8sQ2p…" }
```

- The `device_id` comes from the `app.dryrun/device_id` platform channel
  (`DeviceIdPlatform.androidId()`). The relay stores only a keyed one-way hash of it and returns the
  same `install_id` for the same device every time, so a reinstall recovers the same identity and
  cannot farm a second taster. The raw id is **never** written to Drift, preferences, or a log.
- A missing Android ID is `RelayError.badRequest()`; no request is made.
- **On failure, first launch stays on the seeding screen and retries** (FR-047a/b). There is no
  locally minted identifier to re-mint, so a retry is just the same call again.
- `InstallIdentity.installUuid` is now the part of `install_id` before the dot.

## `GET /v1/config`

Called at launch and on resume-after-a-while. **Fails open, always** (FR-046, Principle X.3).

- Success → replace `CachedConfig` verbatim, keep the `ETag`.
- Any failure (unreachable, timeout, non-200, unparseable) → use `CachedConfig` and continue to a
  usable state within 3s (SC-007).
- **No cached row and no network** → the only case that blocks, and it blocks on a *designed waiting
  screen* that retries as connectivity changes and enters the app the moment the seed lands
  (FR-047, FR-047a/b). Never an error dialog, never a blank screen, never a bare retry button.
- `min_supported_version` above the installed build → blocking update prompt with a direct route to
  Play (FR-048). Evaluated only against a config the app actually has; an unreachable config never
  produces an update wall.

**Read from it, and compile none of it in:** `chat.turn_cap`, `chat.wrap_up_at_turn`,
`chat.min_turn_chars`, `trial.turn_cap`, `keyed_providers`, `killed_problem_ids`,
`min_supported_version`. `model`, `provider`, `providers`, `trim`, and
`trial.pool` are server business and are **not** read; `rotation` is read by the Worker and never
sent; `content_manifest_url` is legacy (the Worker still serves it only so pre-006 apps can parse
`/v1/config`) and the app ignores it — FR-008c forbids exposing model names or
routing state, and reading them would invite it.

## `GET /v1/daily?date=YYYY-MM-DD`

`RelayClient.daily(installId:, date:)`. Install-auth. The **server** picks the day's problem (an
authored problem for exactly `date`, else the evergreen pool by `rotation` or `dayNumber % pool`);
the app no longer prefetches a manifest or runs its own rotation.

```
← { "date": "2026-10-06", "problem": <PublicHalf> }
```

- `DailyResponseDto { date, problem: PublicHalfDto }`; `PublicHalfDto` still rejects unknown keys.
- `cache-control: private, no-store`. `date` is the trusted local day; the server refuses a date
  more than one day from its own UTC date with `BAD_REQUEST`.
- `409 PROBLEM_KILLED` (every candidate withdrawn) → `RelayError.problemKilled`, surfaced as the
  existing "no problem" state (FR-020, FR-040). Offline → `RelayError.transport()`.
- The result is cached in `CachedProblems` with `manifestDate = date`, so a day already fetched is
  served from the cache without a call.

## `GET /v1/practice`

`RelayClient.practice()`. No auth, no install header. Returns `{ "problem": <PublicHalf> }` — the
warm-up — with `cache-control: public, max-age=3600`; `409 PROBLEM_KILLED` if it was withdrawn.
Cached with `manifestDate = null`. Fetched at launch and by the seeding screen so the warm-up and
the key-check probe work with nothing else cached.

## `POST /v1/chat` — the streamed turn

```
→ { problem_id, messages[], summary?, hint_requested?, solution_request_count? }
← SSE: zero or more `token`, then exactly one `meta`, then `done`
       (an `error` frame may replace the tail at any point)
```

**Request rules.**

- `messages` carries **only the turns not covered by `summary`**, `kind: turn` only, max 40
  (FR-020). `summary` is replayed exactly as the last `meta` returned it.
- `hint_requested: true` returns the next authored rung verbatim as a single `token` frame, makes no
  provider call, and leaves `turn_index` unchanged (FR-027 — a hint costs no turn and no allowance).
- `solution_request_count` is **a hint, not an authority**. The server keeps its own count and this
  value may raise it by at most one per accepted turn. The app sends its own tally and never treats
  the number as meaning anything; FR-021's warning is what the app owes, and it must be shown before
  the second request is sent.
- Below `min_turn_chars` the app declines locally with the same copy the server's `EMPTY_TURN`
  carries (US1 scenario 7 — no turn consumed). The server rejects it again before the provider, so
  the two cannot disagree in a way that costs anything.

**Response rules.** Three, each of which is a test (`research.md` R-004):

1. **Success means "a `meta` frame arrived", not "the status was 200."** `DEPLOY-DEV.md` records
   that an error can arrive inside an already-opened stream depending on timing. Never branch on
   status alone.
2. **A stream that ends without `meta` is `MissingMetaFailure`** → treated as `UNCLEAR_RETRY`. Keep
   the partial text visible, advance nothing, offer retry. There is no local counter to correct
   because there are no local counters.
3. **Paint tokens as they arrive** (FR-018). Buffering and revealing does not satisfy it.

**The `meta` frame is the whole state channel.** `turn_index`, `turns_remaining`, `hints_revealed`,
`hints_remaining`, `session_ended`, `leak_blocked`, and optionally `summary`. Stored as
`ServerCounters` verbatim; nothing derived. `leak_blocked: true` means the reply the learner is
looking at is a fallback redirect — it renders as conversation, never as a glitch.

**Backgrounding mid-stream keeps the subscription alive.** The request is already paid for;
cancelling spends the turn for nothing.

## `POST /v1/judge` — one assessment, once

```
→ { problem_id, conversation[], ended_by, reveal_at_index? }
← Assessment
```

- `ended_by` is `user` | `cap` | `solution`, taken from `meta.session_ended` where the server set it.
- `reveal_at_index` is **required** when `ended_by == "solution"`, so the learner is assessed on what
  they had worked out before asking (FR-033).
- **The streak is already credited before this call is made** (FR-036, Principle IV). A failure here
  queues the row; it never touches the streak.
- Failure is retryable and the retry genuinely works: the server claims the session before calling
  the provider, so a retry after a real failure cannot come back
  `SESSION_ALREADY_JUDGED` (FR-034, US4 scenario 6).

## `POST /v1/trial` — the taster

Same bodies as `/v1/chat` and `/v1/judge`, selected by `mode: chat | judge`. **No `X-User-Key`, no
`X-Provider`.**

- One session per install, enforced server-side. `TRIAL_CONSUMED` (409) → a dialog that explains why
  a key is being asked for, offering key entry; not an error (FR-007).
- `TRIAL_UNAVAILABLE` (503) → *"the free taster is at capacity today — add your key and start now"*
  in the same dialog, offering key entry. **Never** `QUOTA_EXHAUSTED` copy (which claims the learner's own
  allowance is spent — false) and never `UNCLEAR_RETRY` copy (which reads as the product being broken
  on the one screen that decides whether the install survives).
- **429 is not among this path's responses.** A pool member's rate limit is a routing decision the
  relay makes; a learner on the taster never sees another party's rate limit.
- A hint pull on the trial path neither starts nor consumes the taster (US3 scenario 4).
- Runs against `trial.turn_cap`, not `chat.turn_cap`, from the same server counter — which is why the
  handover in the next section works.

## The trial → keyed handover

FR-007a/b, SC-020. When the taster's turns run out mid-conversation and the learner saves a key:

1. `Sessions.path` flips `trial → keyed` — an `UPDATE` on one column, same row, same
   `(problem_id, day)`.
2. Subsequent turns go to `/v1/chat` with `X-User-Key` and `X-Provider`.
3. The same `messages` and `summary` are replayed. **Nothing is re-sent and nothing is re-stated.**
4. The allowance rises because the server compares the same counter against `chat.turn_cap` instead
   of `trial.turn_cap`.
5. **The app says so** (FR-007b) — the learner is told the allowance grew, not silently given more.

---

## Errors, uniformly

Every non-2xx body and every SSE `error` frame carries the same envelope and is parsed by the same
code path into `RelayError` (data-model §12). Eleven codes, closed. The mapping to learner-facing
copy and next action is [error-copy.md](./error-copy.md), and `SC-008` is asserted by a test that
walks the sealed union and requires a distinct, actionable message for every variant.

`retryable` off the wire is informative; what the outbox actually retries is decided by the variant's
type, so a future catalogue change cannot silently alter drain behaviour.
