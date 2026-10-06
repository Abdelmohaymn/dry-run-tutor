# Feature Specification: Lean Backend — Device Identity, Minimal Server Data, Server-Picked Daily Problem

**Feature Branch**: `006-lean-backend`

**Created**: 2026-10-06

**Status**: Draft

**Input**: User description: "lean backend per specs/006-lean-backend/plan.md."

## Context

Today the server stores far more than it needs: per-call usage records, an
analytics event stream, web-demo sessions, and several overlapping counter
tables keyed by a random per-install id. A reinstall mints a new id, so a
reinstall also mints a new free trial. The app also downloads the whole
problem catalogue and picks the day's problem itself.

This feature narrows the server to one job — enforcing the free limits — and
moves the choice of the daily problem to the server. Learner data (history,
verdicts, streak) already lives on the phone and stays there.

Out of scope: server-side speech-to-text and any per-device voice allowance.
That conflicts with Constitution Principle VII and needs its own amendment
first.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A reinstall does not reset the free trial (Priority: P1)

A learner uses their free trial session, uninstalls the app, and installs it
again on the same phone. The app recognises the phone and does not offer a
second free trial. Everything else (bring-your-own-key, the warm-up problem)
works as before.

**Why this priority**: The free trial is paid for by the developer. Each
reinstall granting a fresh trial is an open cost leak, and closing it is the
main reason for this feature.

**Independent Test**: On one device, complete the trial, clear the app's data
or reinstall, register again, and confirm the trial is reported as used.

**Acceptance Scenarios**:

1. **Given** a phone whose trial is used, **When** the app is reinstalled and registers again, **Then** the server returns the same device identity and reports the trial as used.
2. **Given** a phone that has never registered, **When** the app registers, **Then** a new device record is created and the trial is available.
3. **Given** two different phones, **When** both register, **Then** each gets its own identity and its own trial.
4. **Given** a registration, **When** the server stores the device, **Then** only a one-way hash of the phone's identifier is kept, never the raw identifier.

---

### User Story 2 - The server picks today's problem (Priority: P1)

A learner opens the app. The app asks the server for today's problem and
shows it. The app never receives tomorrow's problem or the rest of the
catalogue.

**Why this priority**: Picking on the server lets the developer change the
rotation or pull a bad problem without an app release, and stops the app
from carrying the full catalogue. It also produces the per-day activity row
that replaces the analytics stream for measuring Day-7 retention.

**Independent Test**: Request today's problem for a given date and confirm the
expected problem comes back; request a date two days ahead and confirm it is
refused.

**Acceptance Scenarios**:

1. **Given** a problem scheduled for exactly today, **When** the app asks for today's problem, **Then** that problem is returned.
2. **Given** no problem scheduled for today and an active rotation setting, **When** the app asks, **Then** the problem the rotation points to is returned.
3. **Given** no schedule and no rotation, **When** the app asks, **Then** a problem is chosen deterministically from the unscheduled pool, so every device gets the same one that day.
4. **Given** a problem that has been withdrawn (killed), **When** the server picks, **Then** that problem is never returned.
5. **Given** a requested date more than one day from the server's date, **When** the app asks, **Then** the request is refused.
6. **Given** the phone is offline, **When** the app opens, **Then** it shows the problem it already fetched for that date, or the existing "no problem today" state if it has none.
7. **Given** any successful fetch, **Then** the server records that this device was active on that date.

---

### User Story 3 - The warm-up problem is available without registering (Priority: P2)

A first-time learner gets the warm-up (practice) problem before registering
or entering a key.

**Why this priority**: Onboarding depends on it, but it is a small, separate
path from the daily problem.

**Independent Test**: Request the practice problem with no device identity and
confirm its public half is returned.

**Acceptance Scenarios**:

1. **Given** no device identity, **When** the app asks for the practice problem, **Then** its public half is returned.
2. **Given** a daily-problem request, **Then** the practice problem is never chosen as the day's problem.

---

### User Story 4 - Free limits keep working on the smaller data model (Priority: P1)

Turn caps, the hint ladder, one judge per session, the solution-request
safeguard, the per-network trial cap, the lifetime warm-up cap, and the
provider daily budget all behave exactly as they do today.

**Why this priority**: A regression here either walls real learners or lets
the developer's budget run out. Behaviour must not change, only where it is
stored.

**Independent Test**: Run the existing cap scenarios (turn cap reached, refund
on provider failure, second judge refused, hint ladder order, network cap
reached) against the new model and confirm identical outcomes.

**Acceptance Scenarios**:

1. **Given** a session at its turn cap, **When** the learner sends another turn, **Then** it is refused as today.
2. **Given** a provider failure mid-turn, **Then** the reserved turn is refunded as today.
3. **Given** a session already judged, **When** a second judge is requested, **Then** it is refused.
4. **Given** the per-network daily trial cap is reached, **When** another phone on the same network starts a trial, **Then** it is refused.
5. **Given** two phones on the same IPv6 /64 network, **Then** they share one network cap; a phone on a different /64 does not.
6. **Given** an IPv4-mapped IPv6 address, **Then** it is counted as its IPv4 address.

---

### User Story 5 - Nothing about the learner's activity is stored beyond the limits (Priority: P2)

The server keeps no analytics events, no per-call usage log, and no web-demo
sessions. The privacy notice says plainly that a hashed device identifier is
kept to enforce the free limits.

**Why this priority**: Less stored data means less to protect, a simpler
privacy story, and fewer database writes against the free tier.

**Independent Test**: Run a full session and confirm only device, per-day,
provider-budget, config and notify-signup records exist; read the privacy
notice and confirm the wording.

**Acceptance Scenarios**:

1. **Given** a full session (register, fetch, chat, hint, judge), **Then** no event, usage or web-demo record is written anywhere on the server.
2. **Given** the app, **Then** it sends no analytics events.
3. **Given** the privacy notice, **Then** it states that a hashed device identifier is stored to enforce free limits and no longer mentions analytics events.

---

### User Story 6 - Old app versions are moved to the new version cleanly (Priority: P2)

When the new server goes live, learners on the old app see "Update required"
rather than a broken app.

**Why this priority**: The old identity format is rejected by the new server,
so without a clean cut-over old apps fail in confusing ways.

**Independent Test**: Point an old build at the new server with the minimum
version raised and confirm it shows the update wall.

**Acceptance Scenarios**:

1. **Given** an old app and the new server with the minimum version raised, **When** the app launches, **Then** it shows "Update required".
2. **Given** an updated app that previously held an old identity, **When** it launches, **Then** it discards the old identity and registers once with the device identifier.

### Edge Cases

- The phone's identifier is missing or empty: registration is refused with a clear error; the app shows its existing registration-failure state.
- A script sends random identifiers to farm trials: the per-network trial cap, the registration rate limit and the provider daily budget still bound the cost.
- A single IPv6 client rotates addresses inside its own /64: the registration rate limit counts the /64, not the single address.
- A factory reset changes the phone's identifier: the phone is treated as new (accepted).
- The warm-up problem and the day's problem are both used on the same day: their counters are kept separately.
- A keyed learner reopens a past problem from review: its counters are kept separately from today's problem.
- Old apps require the catalogue-location setting to parse config: the server keeps storing and serving it (legacy, read by nothing) so old apps still parse config and reach "Update required"; the new app ignores it.
- Many phones share one IPv4 address behind carrier NAT: they share the network trial cap (known limitation, see Assumptions).

## Requirements *(mandatory)*

### Functional Requirements

**Identity**

- **FR-001**: The app MUST register using the operating system's stable per-device identifier for Android.
- **FR-002**: The server MUST store only a keyed one-way hash of that identifier; the raw identifier MUST NOT be stored or logged.
- **FR-003**: The same identifier MUST always map to the same device record, so trial state survives reinstall and app-data clears.
- **FR-004**: The server MUST return a signed device token, and every limit-enforcing request MUST be authenticated with it.
- **FR-005**: Tokens issued under the old random-id scheme MUST be rejected.
- **FR-006**: An updated app MUST discard any old stored identity and register once with the new scheme.

**Network key**

- **FR-007**: Per-network limits MUST count an IPv4 address as itself and an IPv6 address by its /64 prefix, with compressed forms normalised and IPv4-mapped IPv6 treated as IPv4.
- **FR-008**: The registration rate limit MUST use the same network key.

**Data kept**

- **FR-009**: The server MUST keep only: remote config, device records (creation date, trial state, lifetime warm-up turns), per-device-per-day-per-problem counters (turns, solution requests, hints revealed, judge claim), per-provider daily budget, and notify sign-ups.
- **FR-010**: The server MUST stop writing and MUST remove analytics events, per-call usage records, and web-demo sessions.
- **FR-011**: Existing production data MUST be exported before old tables are removed; it is not migrated into the new model.
- **FR-012**: All current limits (turn cap, refund on failure, one judge per session, hint ladder, solution-request safeguard, per-network trial cap, lifetime warm-up cap, provider daily budget) MUST behave identically to today.

**Daily problem**

- **FR-013**: The server MUST provide today's problem for a requested date, choosing in order: the problem scheduled for that date; else the rotation setting; else a deterministic pick from the unscheduled pool by day number.
- **FR-014**: The pool MUST exclude withdrawn problems and the practice problem, and MUST be ordered stably so every device gets the same pick for a date.
- **FR-015**: The server MUST refuse a date more than one day from its own date.
- **FR-016**: The server MUST return only the public half of the chosen problem.
- **FR-017**: Each successful fetch MUST record that the device was active on that date.
- **FR-018**: The server MUST provide the practice problem's public half without authentication.
- **FR-019**: The full-catalogue download MUST be removed, and the rotation setting MUST no longer be sent to the app.
- **FR-020**: Offline, the app MUST show the problem it already has for that date, else the existing "no problem today" state.

**App analytics**

- **FR-021**: The app MUST stop collecting, buffering and sending analytics events, and MUST drop its local event buffer.

**Retention measurement**

- **FR-022**: Day-7 retention MUST be computable from device creation dates and per-day activity records alone.

**Policy and docs**

- **FR-023**: The privacy notice MUST state that a hashed device identifier is kept to enforce free limits, and MUST no longer mention analytics events.
- **FR-024**: The public API contract and config schema MUST be updated to match (new daily and practice endpoints, new registration body, removed event, web-event, catalogue and web-demo parts).
- **FR-025**: The store data-safety declaration MUST list device identifiers for fraud prevention, not shared, and MUST no longer declare app interactions.

**Cut-over**

- **FR-026**: When the new server goes live, the minimum supported app version MUST be raised so old apps show "Update required".

### Key Entities

- **Device**: One phone, identified by the hash of its identifier. Holds when it was first seen (the Day-7 cohort day), its trial state (started, which problem, which date, completed, which network) and its lifetime warm-up turn count.
- **Device day**: One device's activity on one problem on one date. Holds turns used, solution requests, hints revealed and whether it was judged. Its existence for a date is the retention signal.
- **Provider day**: The developer's daily spend budget per model provider (unchanged, renamed).
- **Config**: The single remote-config record (unchanged apart from rotation no longer being sent to the app; the catalogue-location setting is kept as a legacy field for old apps).
- **Notify sign-up**: Unchanged.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of reinstalls on the same phone are recognised as the same device and do not receive a second free trial.
- **SC-002**: The server holds exactly five kinds of record (config, devices, device days, provider days, notify sign-ups) after cut-over.
- **SC-003**: A typical 15-turn session causes about 32 server writes or fewer, so at least 3,000 sessions a day fit inside the database free tier.
- **SC-004**: Every device asking on the same date receives the same daily problem, and no request returns a problem dated two or more days ahead.
- **SC-005**: Day-7 retention for any cohort day can be answered with one query over device and device-day records.
- **SC-006**: Every existing limit scenario produces the same outcome as before the change (no regression in the existing test suite's cap behaviour).
- **SC-007**: Remote config keeps loading without error immediately after cut-over (zero config outage).
- **SC-008**: Learners on old app versions see "Update required" within one launch after cut-over.

## Assumptions

- Android only, per the constitution; no iOS identifier is handled yet.
- The device identifier is self-reported and can be forged by a script; the network cap, registration rate limit and provider budget are accepted as the bound on that abuse. Stronger device attestation is a follow-up.
- Every existing user gets one fresh trial at cut-over, because old records are keyed by the old random id and cannot be mapped to devices.
- Learners on IPv4 behind carrier NAT share one network trial cap; a carrier-specific higher cap is a follow-up if it bites.
- A factory reset that changes the device identifier counts as a new device.
- Dates are UTC calendar days, matching the existing trusted-date handling.
- One deliberate exception to FR-012: when a first trial call fails before any provider answers, the device's lifetime warm-up turn count is now kept instead of being wiped. This is stricter by at most the warm-up turn cap, never looser.
- Offline on a new day the app no longer has that day's problem (it used to cache 14 days ahead). It shows the existing "no problem" state, whose copy currently reads as "withdrawn". Chat needs the network per turn anyway, so no session is lost; a copy fix is a follow-up (it needs a new string).
- The rollout order in the plan (export, dev run-through, Play release live, then server migration and minimum-version raise together) is followed.

## Dependencies

- **Constitution amendment — done (v3.0.0, owner-approved 2026-10-06)**: Quality Gates now say "Day-7 is measured from a hashed device id and per-day activity rows (`devices` + `device_day`); there is no event stream", and Principle X constraint 8 says there is no product-analytics stream. Both lost measurements are dropped: Principle I's spoken-vs-typed split and Principle X's hint-pull-rate baseline. Still owed: the same change in the external `docs/constitution.md`.
- Play Console data-safety update before the new app is published.
