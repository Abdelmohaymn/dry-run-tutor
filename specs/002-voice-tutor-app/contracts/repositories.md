# Contract — domain repository interfaces

**Feature**: 002-voice-tutor-app

One section per feature. Every interface lives in that feature's `domain/`, is **pure Dart** — no
`dio`, no Drift, no plugin import, no DTO — and is the only thing a Cubit is allowed to depend on.
That is what keeps `bloc_test` able to pass a plain fake with no locator setup, which the constitution
names as the point of the rule.

`Result<T>` is a small sealed union (`Ok<T>` | `Err<RelayError>`). No `dartz`, no `fpdart`.

---

## `core/config` — `RemoteConfigRepository`

```dart
Future<RuntimeConfig> load();              // network, then cache; never throws
RuntimeConfig? cached();                   // synchronous, for launch-path decisions
Stream<RuntimeConfig> watch();
```

`load()` **never throws and never returns null when a cache exists** — FR-046's fail-open is a
property of the signature, not of a `try` block at each call site. Only a first launch with no cached
row can fail to produce a config, and that case is the seeding screen (FR-047a).

## `core/time` — `TrustedTimeSource`

```dart
Future<TrustedInstant> now();              // carries `source` and `isStale`
Future<String> today();                    // YYYY-MM-DD, trusted
```

`DateTime.now()` is banned outside the implementation by the `no_wall_clock` custom lint (Principle
IX). `TrustedInstant.isStale` is what FR-047c and FR-038 branch on: a stale clock never unlocks a new
day and never re-examines a credited one.

## `features/onboarding` — `InstallRepository`

```dart
Future<Result<InstallIdentity>> ensureIdentity();   // mints once, reuses forever
Future<bool> isAgeConfirmed();
Future<void> confirmAge();
```

`ensureIdentity()` is idempotent: it reuses a stored identity, otherwise reads the Android ID through
`DeviceIdPlatform` and calls `POST /v1/install` once. A reinstall recovers the same identity because
the relay derives it from the device. A missing Android ID is `RelayError.badRequest()` and no call
is made — see [relay-client.md](./relay-client.md).

## `features/keys` — `KeyRepository`

```dart
Future<LearnerKey?> read();
Future<Result<void>> saveAndValidate(LearnerKey key);  // probe call, FR-005b
Future<void> delete();
List<String> offeredProviders(RuntimeConfig config);   // == config.keyed_providers, in order
```

`saveAndValidate` **probes before persisting**, so FR-005b's "report the result immediately" is
structural: a key that fails the probe is never stored, and the learner is returned to entry with
what they typed preserved (US2 scenario 5). `read()` returns a `LearnerKey` whose `toString()` is
overridden to redact — the cheapest possible defence against an accidental interpolation into a log
line.

## `features/problem` — `ProblemRepository`

```dart
Future<Problem> fetchDaily(String date);               // GET /v1/daily; caches with manifestDate = date
Future<Problem?> cachedForDate(String date);           // cached by an earlier fetchDaily, or null
Future<void> fetchPractice();                          // GET /v1/practice; caches the warm-up
Future<Problem?> byId(String problemId);
Future<List<Problem>> available(RuntimeConfig config); // cached, not killed, not the warm-up
Future<Problem?> practiceProblem();
Future<bool> hasAnyCached();
```

`fetchDaily` and `fetchPractice` throw `RelayException` on any relay failure. `fetchDaily` needs the
install identity for `X-Install-Id`, so the implementation depends on `InstallRepository`.
`available()` is now used only as the key-check probe's fallback.

## `features/daily` — `DailyRepository`

```dart
Future<DailySelection> forToday();   // (problem, isRepeat), against trusted time
```

The server picks the problem: `forToday()` returns the problem cached for today if it is not in
`killed_problem_ids`, otherwise calls `ProblemRepository.fetchDaily(today)`. Any `RelayException`
(`PROBLEM_KILLED`, or offline with nothing cached) becomes `NoProblemAvailableException`, the existing
"no problem" state (FR-020).

Three requirements collapse into this one method. FR-040 excludes withdrawn problems. FR-035b returns
a repeat with **no marker of any kind** when the library is exhausted — the presentation layer cannot
tell the difference because `DailySelection.isRepeat` is consumed only by the session writer, not by
any widget. FR-035c records the flag locally anyway, so first and later attempts stay
distinguishable in retained data.

## `features/chat` — `SessionRepository`

```dart
Future<Session> openOrResumeToday();
Stream<TurnEvent> sendTurn(Session s, String text, InputMode mode);  // token / meta / error
Future<Result<HintRung>> pullHint(Session s);
Future<void> saveDraft(Session s, Draft d);
Future<void> promoteToKeyed(Session s, String providerId);            // FR-007a
Future<void> endSession(Session s, EndedBy reason);                   // credits the streak
Stream<Session> watch(String sessionId);
```

`sendTurn` returns a **stream**, not a future, because FR-018 requires tokens painted as they arrive.
`endSession` credits the streak in the same transaction that flips the status, before any judge
request exists — which is how Principle IV becomes structural rather than a matter of ordering
discipline. `promoteToKeyed` is the FR-007a handover: one `UPDATE`, same conversation, larger
allowance.

**Nothing in this interface returns a computed counter.** Counters arrive on `TurnEvent.meta` and are
stored verbatim (FR-019).

## `features/voice` — `RecognitionService`

```dart
Future<RecognitionAvailability> availability();   // available | needsLanguagePack | unsupported
Stream<RecognitionEvent> listen();                // partialText | level | finalText | error
Future<void> stop();
Future<void> cancel();
```

**There is no method that returns audio, and no method that writes a file.** That absence is the
implementation of Constitution VII and FR-011, and an import-boundary lint over `features/voice/`
asserts no filesystem or HTTP dependency reaches it. `availability()` drives FR-011a's
language-pack route. `RecognitionEvent.level` is what the waveform renders (`research.md` R-002).

## `features/transcript` — no repository

The review step is pure presentation over a `Draft` plus the problem's `glossaryTerms`. Chips are
built by matching recognised tokens against those terms (FR-012a). Deliberately has no repository:
nothing here talks to anything.

## `features/hints` — folded into `SessionRepository`

A hint is a `/v1/chat` call with `hint_requested: true`, so it belongs to the session, not to a
separate client. Rungs are stored as `Messages` rows with `kind: hintRung` and displayed verbatim
(FR-026).

## `features/assessment` — `AssessmentRepository`

```dart
Future<Result<Assessment>> request(Session s);   // queues on failure, FR-034
Future<Assessment?> forSession(String sessionId);
Future<void> recordDispute(String sessionId);    // local only, FR-031a
```

`recordDispute` sets `disputed`/`disputedAt`. **Nothing leaves the
device** and no consent prompt is shown, because FR-031b forbids asking for consent the app will not
act on.

## `features/streak` — `StreakRepository`

```dart
Future<void> credit(String trustedDay);     // insert-only
Future<Streak> current();                   // computed by walking back from today
Future<Set<String>> completedDates();       // the heatmap's ONLY input
```

**Insert-only, and there is no decrement.** FR-038 is satisfied because there is nothing to
decrement. `completedDates()` returns dates rather than sessions, which is why a heatmap square
cannot become a link into a past day (FR-039d).

## `features/settings` — `SettingsRepository`

```dart
Future<ReminderTime?> reminder();
Future<void> setReminder(ReminderTime? t);   // local notification, default morning (FR-048a)
Future<void> wipeAllData();                  // FR-039f
```

`wipeAllData()` drops every Drift table, clears secure storage and preferences, and cancels
notifications. It does **not** reset install identity or restore the taster — those are server-side
per install, and the warning says so rather than promising something the app cannot deliver.

## `core/queue` — `OutboxRepository`

```dart
Future<void> enqueue(OutboxItem item);
Future<List<OutboxItem>> due(DateTime trustedNow);
Future<void> markAttempted(String id, RelayError? e);
Future<void> remove(String id);
```

Drained by `OutboxDrainBloc` — the one event-driven `Bloc` in the app — serialised per `sessionId`.
The `solutionRequestCountAtEnqueue` guard lives here (data-model §6): a replayed row can never carry
a higher solution count than the row it replaces, which is what stops the offline queue from
releasing a solution the learner never asked twice for.
