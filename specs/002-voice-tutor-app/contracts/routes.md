# Contract — routes and the screen inventory

**Feature**: 002-voice-tutor-app | UI reference: `docs/ui-prototype.html` (one directory above this repo)

`go_router` with typed routes. **20 screens** (21 until `/age-gate` was removed on 2026-09-05): the prototype's 12, plus the 8 the spec names as
needing to be built in the same language.

The router carries three guards, and they carry real requirements — putting them in the router rather
than in each screen is what makes them unbypassable.

---

## Guards, in order

```
1. seedGuard     no cached config AND no cached problem  →  /seeding
2. updateGuard   build < config.min_supported_version    →  /update
3. welcomeGuard  welcome carousel not yet seen               →  /welcome
4. practiceGuard walkthrough taken but not yet finished    →  /welcome/practice
```

**`seedGuard` implements FR-047.** One connection is required at first launch *only*. It fires when
there is no cached config **and** no cached problem — after a single success, every later launch with
no network goes straight to today's problem (FR-047 scenario 2a). It never fires on a config *failure*
when a cache exists, which is FR-046's fail-open.

**`updateGuard` is evaluated only against a config the app has.** An unreachable config never
produces an update wall — `design.md` §8 calls a force-update screen that cannot be dismissed because
the network is down a one-star review, and it is right.

**`ageGuard` was removed on 2026-09-05** along with `/age-gate`, FR-008 and SC-018 — see spec.md's
2026-09-05 clarification for the accepted risk. `welcomeGuard` took its slot and its shape: a router
redirect rather than a per-screen check, so "every entry point" stays a finite, enumerable list.
Settings is exempt from both guards, so a learner in a strange state can always reach wipe-all.

**`practiceGuard` covers the gap `welcomeGuard` leaves.** The welcome is marked seen the moment the
carousel hands off to the walkthrough, so `welcomeGuard` will never route back there — which left a
learner who closed the app mid-walkthrough reopening into today's real problem, the one thing the
walkthrough exists to stand in front of. The flag is set on the way *in* and cleared by either exit
(finishing, or the skip action in the walkthrough's app bar), so it never outlives the screen. It
shares `welcomeGuard`'s exempt set: settings stays reachable, and the walkthrough is an offer rather
than a gate.

---

## Routes

| Path | Screen | Prototype | Requirements |
|---|---|---|---|
| `/seeding` | First-launch waiting screen | **new** | FR-047a/b — designed state, auto-retry, no error dialog, no blank screen (SC-022) |
| `/update` | Force update | **new** | FR-048 — direct route to Play |
| `/` | The daily loop | **1** | FR-035 — opens straight onto the problem. No menu, no list, no archive. Problem collapses to a card; chat owns the screen |
| `/session/record` | Speaking | **2** | FR-013a — live waveform, elapsed timer, 90s cap, warning at 15s left |
| `/session/review` | Transcript review | **3** | Principle V, FR-012, FR-012a/b — **mandatory**, tap-to-fix glossary chips, re-record as a peer of send |
| `/session/mic-rationale` | Mic rationale | **9** | FR-014, FR-011c — shown at first record, never at launch; names the platform as the recogniser and never claims audio stays on the device |
| `/session/recognition-unavailable` | Recognition unavailable | **new** | FR-011a — why, language-pack route, keyboard as interim only |
| `/session/confirm-solution` | Second-ask warning | — | FR-021 — the only route from which a second solution request can be sent |
| `/session/verdict` | Verdict | **6** | FR-030, FR-031 — hedged chip, insight ticks and misses, dispute one tap away and always present |
| `/session/reveal` | Reveal | **7** | FR-032 — the authored editorial. Unreachable without an `Assessments` row |
| `/session/review-day` | Review a completed day | **new** | FR-039 — the current day only, ≤3 taps (SC-013) |
| `/streak` | Streak and share card | **8** | FR-039a/b — contribution heatmap, text-only share card |
| `/keys/wall` | The wall | **10** | FR-005a — leads with "you cannot be charged", shown **only after a completed session** |
| `/keys/entry` | Paste key | **11** | FR-005b/d, FR-008a/e — validated on save, names the chosen provider, states where the key lives. Always **pushed**, never `go`n: back returns to the conversation, never out of the app |
| ~~`/keys/rate-limited`~~ | Removed 2026-09-25 | 12 | Replaced by a popup over the conversation (`widgets/rate_limit_dialog.dart`) that names the key's per-minute limit and closes itself on the automatic resend |
| `/settings` | Settings | **new** | FR-006, FR-048a, FR-039f |
| `/settings/key` | Key management | **new** | FR-006 — view, replace, delete |
| `/settings/reminder` | Reminder time | **new** | FR-048a — one local daily reminder, defaults to morning |
| `/settings/wipe` | Delete all data | **new** | FR-039f — one action, clear warning that the streak ends |
| `/withdrawn` | Withdrawn-problem fallback | **new** | FR-040 — a different problem, not a broken one. Usually invisible: a swap, not a screen |

**Offline and queued states are not routes.** They are states within `/` and `/session/*` — a failed
send is a retryable bubble *in the conversation* (FR-042), not a screen the learner is sent to. Making
them routes would be exactly the "lost thought" the requirement forbids.

---

## What the router is not allowed to reach

**No route resolves to a past day.** There is no `/session/:id`, no `/history`, no `/archive`, and no
parameterised path that could name a retained session other than today's (FR-039d). `/streak`'s
heatmap is built from a set of dates, so a square has no id to route with (see
[repositories.md](./repositories.md)). SC-013's second half — "no past day is reachable from any
screen" — is verified by enumerating the route table, which is only possible because the table is
finite and the DAO exposes no method that would populate such a screen.

**`/session/review` has no bypass.** `sendTurn` is called from exactly one place, and that place is
reachable only from this route. There is no setting, no long-press, and no "don't show again" —
Principle V says not skippable, not auto-confirmed, not hidden behind a setting, and a route with one
inbound edge is how that is enforced rather than remembered.

**`/session/reveal` requires an `Assessments` row.** FR-032: none of the editorial before the
assessment has been delivered. A redirect, not a conditional widget.

---

## Deep link

One, for the share card (FR-039b): `dryrun://p/<problem_id>`. It opens **today's problem if and
only if it is that problem**, and otherwise opens today's problem plainly. It is deliberately not a
way into a past day — a deep link that could open an old problem would be the archive arriving
through the back door.

## Composition-root rule

`sl<T>()` appears in `main()` and in `BlocProvider(create:)` at the route that owns the Cubit.
Nowhere else — enforced by the `no_service_locator_outside_root` custom lint. `BlocProvider` at the
route keeps Cubit lifecycle tied to the route, so a pop closes it; the *session* survives the pop
because it lives in Drift, not in the Cubit (data-model §3).
