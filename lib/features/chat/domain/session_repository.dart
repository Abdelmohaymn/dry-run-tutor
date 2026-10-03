import '../../../core/errors/result.dart';
import '../../../core/models/wire_enums.dart';
import 'draft.dart';
import 'ended_by.dart';
import 'hint_rung.dart';
import 'message.dart';
import 'session.dart';
import 'turn_event.dart';

/// The chat feature's one repository (contracts/repositories.md). Pure
/// Dart — no `dio`, no Drift, no plugin import, no DTO — so
/// `DailySessionCubit` is constructible in `bloc_test` with a plain fake.
abstract interface class SessionRepository {
  /// Opens today's session if none exists yet, or resumes the one already
  /// open — the trusted-time `(problemId, day)` key (FR-035).
  Future<Session> openOrResumeToday();

  /// Opens the onboarding walkthrough's session, or resumes the one
  /// already open for this day. A real session on a real problem — the
  /// walkthrough is a live conversation, not a script — but flagged
  /// `isPractice`, so it is never what `openOrResumeToday` returns and
  /// never one of the days.
  ///
  /// Returns null when the manifest carries no warm-up, which is a relay
  /// older than this app: the caller falls back rather than failing.
  Future<Session?> openOrResumePractice();

  /// Sends [text] as a turn. Returns a **stream**, not a future, because
  /// FR-018 requires tokens painted as they arrive. Builds the request from
  /// uncovered messages plus `summary`, capped at 40 (FR-020); persists
  /// `meta` verbatim and folds newly-covered messages into a fresh
  /// `summary` when one arrives.
  ///
  /// [solutionRequestCount], when supplied, is sent as the wire's own hint
  /// (Principle III) — the server, not this call, decides whether it
  /// raises the stored count and whether that release ends the session.
  ///
  /// [retryMessageId] resends a turn that is already in the conversation:
  /// the existing row is flipped back to `sending` rather than a second
  /// copy of the learner's words being appended below the first.
  Stream<TurnEvent> sendTurn(
    Session session,
    String text,
    InputMode mode, {
    int? solutionRequestCount,
    String? retryMessageId,
  });

  /// A single `token` frame carrying the next authored rung. No provider
  /// call, `turn_index` unchanged (FR-027).
  Future<Result<HintRung>> pullHint(Session session);

  /// Appends the next unrevealed worked example to the conversation and
  /// returns its 1-based ordinal, or `null` when they have all been shown.
  ///
  /// Unlike [pullHint] this never touches the network at all: examples are
  /// part of the cached public half, so the whole reveal is a local insert.
  /// The revealed count is derived from the `example` rows themselves —
  /// nothing new is stored on the session — so it survives a restart for
  /// the same reason the conversation does.
  Future<int?> revealNextExample(Session session);

  Future<void> saveDraft(Session session, Draft draft);

  /// FR-016, FR-024.
  Future<Draft?> loadDraft(Session session);

  Future<void> deleteDraft(Session session);

  /// FR-007a — one `UPDATE` on `path`, same row, same conversation.
  Future<Session> promoteToKeyed(Session session, String providerId);

  /// Credits the streak in the same transaction that flips the status,
  /// before any judge request exists (FR-036, Principle IV).
  Future<Session> endSession(Session session, EndedBy reason);

  Stream<Session> watch(String sessionId);

  /// The rendered conversation, every row regardless of
  /// `coveredBySummary` — what `message_list.dart` paints (FR-018).
  Stream<List<Message>> watchMessages(String sessionId);
}
