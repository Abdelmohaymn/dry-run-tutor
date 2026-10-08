import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters.dart';
import '../tables.dart';

part 'session_dao.g.dart';

/// Data access for `Sessions` and, because a draft belongs to exactly one
/// session, `Drafts`.
///
/// **`todaysSession()` and nothing that returns a past session's body.**
/// FR-039d forbids any read path back into a completed day; every read
/// method here is scoped to "the row for this day" or "the row for this
/// id the caller already holds from a today query" — there is no
/// `allSessions()`, no `history()`, and no method a screen could use to
/// browse retained sessions.
@DriftAccessor(tables: [Sessions, Drafts])
class SessionDao extends DatabaseAccessor<AppDatabase> with _$SessionDaoMixin {
  SessionDao(super.db);

  /// The most recently opened session for a trusted-time day, if it exists.
  /// A day may contain multiple problem sessions, while the optional problem
  /// filter narrows this to the requested problem.
  ///
  /// The walkthrough is excluded explicitly: it is a real session on a
  /// real problem, taken on some day, and this reads with
  /// The newest row is resumed when no problem is explicitly requested.
  Future<SessionRow?> todaysSession(String day, {String? problemId}) async {
    final query = select(sessions)
      ..where((t) => t.day.equals(day) & t.isPractice.equals(false));
    if (problemId != null) {
      query.where((t) => t.problemId.equals(problemId));
    }
    query
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
      ..limit(1);
    final List<SessionRow> rows = await query.get();
    return rows.firstOrNull;
  }

  /// The walkthrough's own session for [day], if one is already open —
  /// what lets a learner who closed the app mid-walkthrough come back to
  /// the conversation they had rather than a blank one.
  Future<SessionRow?> practiceSession(String day) {
    return (select(sessions)
          ..where((t) => t.day.equals(day) & t.isPractice.equals(true)))
        .getSingleOrNull();
  }

  /// A row the caller already knows the id of — used by `promoteToKeyed`
  /// and `endSession` to read-modify-write without a second `(day)` query.
  Future<SessionRow?> byId(String id) {
    return (select(sessions)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Streams one session by id, for the review screen and message list to
  /// react to counter updates without re-querying by day.
  Stream<SessionRow?> watchById(String id) {
    return (select(
      sessions,
    )..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Streams today's session so the UI reflects `meta`-driven counter
  /// updates as they are persisted.
  Stream<SessionRow?> watchTodaysSession(String day) {
    return (select(sessions)
          ..where((t) => t.day.equals(day) & t.isPractice.equals(false))
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .watchSingleOrNull();
  }

  /// Inserts a freshly-opened session and returns its id.
  Future<String> insertSession(SessionsCompanion entry) async {
    await into(sessions).insert(entry);
    return entry.id.value;
  }

  /// Persists any change to a session row the caller already holds — the
  /// `meta` frame parser's counter update, `promoteToKeyed`'s path flip,
  /// `endSession`'s status transition, or a dispute flag. Never used to
  /// discover a row; always used to update one already in hand.
  Future<bool> updateSession(SessionRow row) {
    return update(sessions).replace(row);
  }

  /// The unsent draft for a session, if any (FR-016, FR-024).
  Future<DraftRow?> draftFor(String sessionId) {
    return (select(
      drafts,
    )..where((t) => t.sessionId.equals(sessionId))).getSingleOrNull();
  }

  /// Debounced write on every composer edit.
  Future<void> upsertDraft(DraftsCompanion entry) {
    return into(drafts).insertOnConflictUpdate(entry);
  }

  /// Deleted on send or on re-record (FR-012b).
  Future<void> deleteDraft(String sessionId) {
    return (delete(drafts)..where((t) => t.sessionId.equals(sessionId))).go();
  }

  Future<void> deleteSession(String sessionId) {
    return (delete(sessions)..where((t) => t.id.equals(sessionId))).go();
  }

  /// Problem ids this install has ever completed or ended a session on —
  /// ids only, like `StreakDao.completedDates()`'s dates only, so a
  /// repeat-pool pick has nothing here it could route into a past
  /// session's body with (FR-039d). `DailyRepositoryImpl`'s only reason to
  /// look backward at all: preferring an unattempted problem over a
  /// repeat.
  Future<Set<String>> completedProblemIds() async {
    final List<SessionRow> rows = await (select(
      sessions,
    )..where((t) => t.status.equalsValue(SessionStatus.chatting).not())).get();
    return rows.map((SessionRow r) => r.problemId).toSet();
  }
}
