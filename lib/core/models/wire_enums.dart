/// Wire vocabulary shared between Drift's persistence layer
/// (`core/db/tables.dart`) and the pure-Dart domain entities that
/// `features/*/domain/` expose (data-model.md §1–§9, contracts/repositories.md).
///
/// Living outside `core/db` — rather than being declared alongside
/// `StringListConverter` in `core/db/converters.dart`, which imports
/// `package:drift/drift.dart` — is what lets a domain interface reference
/// `TurnRole` or `InputMode` without pulling Drift into a layer that
/// contracts/repositories.md requires stay pure Dart. `core/db/converters.dart`
/// re-exports this file so every existing Drift import keeps working
/// unchanged.
library;

/// `session.path` — `trial` (no key, spends the operator's credential) or
/// `keyed` (the learner's own key). See data-model.md §3.
enum SessionPath { trial, keyed }

/// `session.status` — the three-state lifecycle. The streak is credited on
/// the `chatting -> pendingJudge` transition (FR-036, Principle IV), before
/// any judge request exists.
enum SessionStatus { chatting, pendingJudge, complete }

/// The app's own wire vocabulary for who sent a message — never the
/// provider's `user`/`assistant`. That translation is confined server-side.
enum TurnRole { user, tutor }

/// What kind of thing a message row actually is. Only `turn` rows are
/// replayed as conversation context; `hintRung` is authored text shown
/// verbatim; `fallbackRedirect` is rendered when `meta.leak_blocked` is
/// true; `ladderExhausted` is the fixed closing line; `example` is an
/// authored worked example, revealed one at a time on the learner's own
/// ask, exactly like a hint rung and just as local (it never reaches the
/// relay — the examples ship inside the cached public half).
///
/// Appended, never reordered: `textEnum` persists the NAME, so a new
/// value at the end leaves every stored row readable.
enum MessageKind { turn, hintRung, fallbackRedirect, ladderExhausted, example }

/// Delivery state of a message. `failedRetryable` is FR-042's retryable
/// bubble — the text is never lost and the allowance is never spent.
enum Delivery { local, sending, sent, failedRetryable }

/// Whether a turn arrived by voice or by the "or type instead" path.
/// `chat_turn_sent.input_mode` is Principle I's own falsification test.
enum InputMode { voice, text }

/// What an outbox row is queued to send.
enum OutboxKind { chatTurn, judge }

/// `Assessment.matchedApproach` verdict tier — `none` is a designed state,
/// not an error (Principle II).
enum MatchedVerdict { optimal, acceptable, suboptimal, wrong, none }

/// The post-override verdict the server actually returned. The app displays
/// this; it never re-derives it (Principle II).
enum Verdict { strongPass, pass, borderline, fail, unclear }
