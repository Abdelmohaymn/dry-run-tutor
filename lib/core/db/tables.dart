import 'package:drift/drift.dart';

import 'converters.dart';

/// The install's own identity. One row, ever. Minted once on device
/// (`installUuid`) and confirmed by the relay (`installId`, sent as
/// `X-Install-Id` on every authenticated call). Never re-minted on failure
/// — see `InstallRepository.ensureIdentity()` (FR-001).
///
/// Named `InstallIdentityRow` on the Dart side (`@DataClassName`) so the
/// generated row type never collides with the pure-Dart domain entity of
/// the same name from data-model.md §9.
@DataClassName('InstallIdentityRow')
class InstallIdentity extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get installUuid => text()();
  TextColumn get installId => text()();
  DateTimeColumn get mintedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The problem cache — the public half only. Mirrors
/// `problem.schema.json#/$defs/PublicHalf` field for field and nothing
/// else: reference approaches, key insights, wrong turns, follow-ups, and
/// editorials are server-side only (Constitution VI).
class CachedProblems extends Table {
  TextColumn get problemId => text()();
  IntColumn get schemaVersion => integer()();
  TextColumn get title => text().withLength(max: 60)();
  TextColumn get ramp => text()();
  IntColumn get difficulty => integer().nullable()();
  TextColumn get tags => text().map(const StringListConverter())();
  TextColumn get source => text()();
  TextColumn get statement => text()();
  TextColumn get constraints => text().map(const StringListConverter())();

  /// `PublicHalf.examples`, held as the manifest's own JSON rather than
  /// through a converter: the shape is a list of objects, not the list of
  /// strings `StringListConverter` covers, and encoding it here would put
  /// a `features/` domain type inside `core/db`. Nullable — the field is
  /// optional in the manifest, and every row written before schema v2 has
  /// none.
  TextColumn get examplesJson => text().nullable()();
  IntColumn get estSpeakSeconds => integer()();
  TextColumn get collections => text().map(const StringListConverter())();
  TextColumn get glossaryTerms => text().map(const StringListConverter())();
  IntColumn get hintCount => integer()();
  TextColumn get manifestDate => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {problemId};
}

/// One attempt, one problem, one day. Anchored in Drift rather than in a
/// Cubit so the conversation survives both an app kill (FR-024) and a push
/// to the key-entry route and back (FR-007a) from the same mechanism.
///
/// `turnIndex`, `turnsRemaining`, `hintsRevealed`, `hintsRemaining`, and
/// `sessionEnded` are the last known SERVER truth — written only by the
/// `meta` frame parser, never computed here (FR-019, research.md R-007).
@DataClassName('SessionRow')
@TableIndex(name: 'sessions_problem_day', columns: {#problemId, #day}, unique: true)
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get problemId => text().references(CachedProblems, #problemId)();
  TextColumn get day => text()();
  TextColumn get path => textEnum<SessionPath>()();
  TextColumn get status => textEnum<SessionStatus>()();
  TextColumn get providerId => text().nullable()();
  TextColumn get summary => text().nullable()();
  IntColumn get solutionRequestCount => integer().withDefault(const Constant(0))();
  BoolColumn get isRepeat => boolean().withDefault(const Constant(false))();

  /// The onboarding walkthrough's session. Its own row rather than a
  /// special case elsewhere: the walkthrough is a real conversation on a
  /// real problem, it just is not one of the days. `todaysSession()`
  /// filters on this, because it reads with `getSingleOrNull()` and a
  /// walkthrough taken on the same day as today's problem would otherwise
  /// be a second row for that day — a throw, not a wrong answer.
  BoolColumn get isPractice => boolean().withDefault(const Constant(false))();
  BoolColumn get disputed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get disputedAt => dateTime().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  // --- last known SERVER truth. Never computed here. ---
  IntColumn get turnIndex => integer().withDefault(const Constant(0))();
  IntColumn get turnsRemaining => integer().nullable()();
  IntColumn get hintsRevealed => integer().withDefault(const Constant(0))();
  IntColumn get hintsRemaining => integer().nullable()();
  TextColumn get sessionEnded => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The conversation. `role` is the app's own wire vocabulary — `user` /
/// `tutor`, never the provider's `user`/`assistant`. `coveredBySummary` is
/// what keeps a replay request inside the 40-item ceiling without losing
/// anything the learner can scroll back to (FR-020).
@DataClassName('MessageRow')
@TableIndex(name: 'messages_session_seq', columns: {#sessionId, #seq}, unique: true)
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  IntColumn get seq => integer()();
  TextColumn get role => textEnum<TurnRole>()();
  // Named `body` on the Dart side because a column getter literally named
  // `text` shadows Table's own `text()` column-builder method and breaks
  // drift_dev's static resolver; the underlying SQL column stays `text` to
  // match data-model.md §4's field name.
  TextColumn get body => text().named('text').withLength(min: 1, max: 8000)();
  TextColumn get kind => textEnum<MessageKind>()();
  TextColumn get delivery => textEnum<Delivery>()();
  TextColumn get recognisedDraft => text().nullable()();
  TextColumn get inputMode => textEnum<InputMode>().nullable()();
  BoolColumn get coveredBySummary => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The unsent draft, one per session. FR-016 and FR-024: survives an app
/// restart. Written on every edit (debounced), deleted on send or
/// re-record.
@DataClassName('DraftRow')
class Drafts extends Table {
  TextColumn get sessionId => text().references(Sessions, #id)();
  // See the note on `Messages.body` above — same shadowing issue.
  TextColumn get body => text().named('text')();
  TextColumn get recognised => text().nullable()();
  TextColumn get repaired => text().nullable()();
  TextColumn get inputMode => textEnum<InputMode>()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// The assessment and its editorial. Nothing here is ever constructed
/// client-side (Principle II) — every column is a field of the
/// `/v1/judge` response. `rawJson` keeps the body verbatim for FR-039e's
/// later export. `editorial` is gated behind the router: `/session/reveal`
/// is unreachable without this row existing (FR-032).
@DataClassName('AssessmentRow')
class Assessments extends Table {
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get matchedApproach => text()();
  TextColumn get matchedVerdict => textEnum<MatchedVerdict>()();
  TextColumn get insightsHit => text().map(const StringListConverter())();
  TextColumn get insightsMissed => text().map(const StringListConverter())();
  TextColumn get wrongTurnsTaken => text().map(const StringListConverter())();
  TextColumn get complexityJson => text()();
  TextColumn get verdict => textEnum<Verdict>()();
  RealColumn get confidence => real()();
  TextColumn get feedback => text().withLength(max: 320)();
  TextColumn get editorial => text()();
  IntColumn get revealAtIndex => integer().nullable()();
  TextColumn get rawJson => text()();
  DateTimeColumn get receivedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// The offline queue. Drained strictly in `createdAt` order, serialised per
/// `sessionId` (research.md R-010). `solutionRequestCountAtEnqueue` exists
/// because of Principle III: a replayed row can never carry a higher
/// solution count than the row it replaces, which is what stops the queue
/// from releasing a solution the learner never asked twice for.
class Outbox extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId => text().references(Sessions, #id)();
  TextColumn get kind => textEnum<OutboxKind>()();
  TextColumn get payload => text()();
  IntColumn get solutionRequestCountAtEnqueue => integer()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextEligibleAt => dateTime()();
  TextColumn get lastErrorCode => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// A set of completed days, not a counter. There is nothing to decrement,
/// which is how FR-038 ("never revoke a credited streak") becomes
/// structurally true rather than merely policy. `day` is always the
/// `TrustedTimeSource`'s day, never `DateTime.now()`.
class StreakDays extends Table {
  TextColumn get day => text()();
  DateTimeColumn get creditedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {day};
}

/// The `/v1/config` body, stored verbatim so a key the app does not yet
/// read is never silently dropped on the way through. FR-046's fail-open
/// falls back to this row on any failure.
class CachedConfig extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get json => text()();
  TextColumn get etag => text().nullable()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
