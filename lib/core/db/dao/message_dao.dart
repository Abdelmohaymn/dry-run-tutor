import 'package:drift/drift.dart';

import '../app_database.dart';
import '../converters.dart';
import '../tables.dart';

part 'message_dao.g.dart';

/// Data access for the conversation. Ordering is always by `seq`, the
/// strict order a turn was appended in.
@DriftAccessor(tables: [Messages])
class MessageDao extends DatabaseAccessor<AppDatabase> with _$MessageDaoMixin {
  MessageDao(super.db);

  /// The full rendered conversation — every row, regardless of
  /// `coveredBySummary`. The *request* builder reads a narrower view; see
  /// [uncoveredForSession].
  Future<List<MessageRow>> forSession(String sessionId) {
    return (select(messages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();
  }

  /// Streams the conversation so token-by-token painting (FR-018) and
  /// later reopenings both read from the same source of truth.
  Stream<List<MessageRow>> watchForSession(String sessionId) {
    return (select(messages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .watch();
  }

  /// Only `kind: turn` rows not yet folded into `Sessions.summary` — what
  /// a `/v1/chat` request replays alongside `summary` itself (FR-020).
  /// A turn that failed and was never retried is not part of the
  /// conversation the tutor had; a retried one is back to `sending` before
  /// its request is built.
  Future<List<MessageRow>> uncoveredForSession(String sessionId) {
    return (select(messages)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.coveredBySummary.equals(false) &
                t.kind.equalsValue(MessageKind.turn) &
                t.delivery.equalsValue(Delivery.failedRetryable).not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();
  }

  /// The learner's own turns already folded into `Sessions.summary`,
  /// oldest first. Sent as `earlier_learner_turns` so the relay still
  /// counts words the learner said before the last summary.
  Future<List<String>> coveredLearnerTurns(String sessionId) async {
    final List<MessageRow> rows = await (select(messages)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.coveredBySummary.equals(true) &
                t.role.equalsValue(TurnRole.user) &
                t.kind.equalsValue(MessageKind.turn) &
                t.delivery.equalsValue(Delivery.failedRetryable).not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.seq)]))
        .get();
    return rows.map((MessageRow m) => m.body).toList();
  }

  /// The next strict-order sequence number for a session.
  Future<int> nextSeq(String sessionId) async {
    final MessageRow? last = await (select(messages)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.desc(t.seq)])
          ..limit(1))
        .getSingleOrNull();
    return (last?.seq ?? -1) + 1;
  }

  /// A single row by id — used to fold a completed turn's delivery state
  /// and, in a later phase, the outbox's retry bookkeeping.
  Future<MessageRow?> byId(String id) {
    return (select(messages)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> insertMessage(MessagesCompanion entry) {
    return into(messages).insert(entry);
  }

  Future<void> deleteForSession(String sessionId) {
    return (delete(messages)..where((t) => t.sessionId.equals(sessionId))).go();
  }

  Future<bool> updateMessage(MessageRow row) {
    return update(messages).replace(row);
  }

  /// Flips just the delivery state of one row — the common case (sending
  /// → sent, or sending → failedRetryable on a transport failure) that
  /// does not need a full row replace.
  Future<void> markDelivery(String id, Delivery delivery) {
    return (update(messages)..where((t) => t.id.equals(id)))
        .write(MessagesCompanion(delivery: Value(delivery)));
  }

  /// Folds exactly these rows into the new `summary` a `meta` frame just
  /// returned: the leading `summary_covers` of the turns that request
  /// replayed. Marking everything through the reply instead dropped the
  /// turns the relay had kept verbatim (found on device 2026-09-25).
  Future<void> markCoveredBySummary(List<String> ids) {
    if (ids.isEmpty) return Future<void>.value();
    return (update(messages)..where((t) => t.id.isIn(ids)))
        .write(const MessagesCompanion(coveredBySummary: Value(true)));
  }
}
