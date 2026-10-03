import 'package:freezed_annotation/freezed_annotation.dart';

part 'relay_error.freezed.dart';

/// The eleven-code relay error catalogue as a type, plus `transport` for a
/// request that never reached the relay at all (data-model.md §12).
///
/// **`retryable` is deliberately not a field.** Retry behaviour is a
/// property of the variant, decided by an exhaustive `switch` at the one
/// place that needs it (the outbox drain policy), so a future catalogue
/// change cannot silently alter drain behaviour by flipping a boolean off
/// the wire. The union has no `default:` branch anywhere it is switched on
/// — a twelfth code is a compile error, not a generic dialog.
@freezed
sealed class RelayError with _$RelayError {
  /// The provider is being paced. `retryAfter` is the exact wait; the
  /// same turn resumes at the same point once it elapses. Not presented as
  /// an error (FR-045a).
  const factory RelayError.rateLimited({required Duration retryAfter}) = RateLimited;

  /// The stored key was rejected by the provider. Re-entry preserves the
  /// conversation (FR-005c).
  const factory RelayError.invalidKey() = InvalidKey;

  /// The learner's own daily allowance with the provider is spent. Resets;
  /// no charge occurred or can occur (FR-008d).
  const factory RelayError.quotaExhausted() = QuotaExhausted;

  /// The request did not come back cleanly. Retried once, then the
  /// session stays pending with the assessment queued.
  const factory RelayError.unclearRetry() = UnclearRetry;

  /// The conversation has reached today's length. A normal ending — hints
  /// and end-session remain available (FR-023, FR-028).
  const factory RelayError.turnCapReached() = TurnCapReached;

  /// The one-per-install free taster has been used. Routes straight into
  /// key entry (FR-007).
  const factory RelayError.trialConsumed() = TrialConsumed;

  /// Raised for two different situations the catalogue does not
  /// distinguish on the wire — a repeat `/v1/judge` call, and any further
  /// turn or hint pull after a verdict. [ctx] is what tells the two apart
  /// (research.md R-012, contracts/error-copy.md).
  const factory RelayError.sessionAlreadyJudged({required JudgedContext ctx}) =
      SessionAlreadyJudged;

  /// Below `min_turn_chars`. Rejected before the provider; no turn spent.
  const factory RelayError.emptyTurn() = EmptyTurn;

  /// The free taster is at capacity today, for everyone — not this
  /// install's allowance. Routes straight into key entry; must never
  /// borrow `QUOTA_EXHAUSTED` or `UNCLEAR_RETRY` copy.
  const factory RelayError.trialUnavailable() = TrialUnavailable;

  /// Today's problem has been withdrawn server-side. A different problem
  /// is presented in its place (FR-040).
  const factory RelayError.problemKilled({required String problemId}) = ProblemKilled;

  /// Something on the app's side of the request is wrong. Never echoes a
  /// field from the request.
  const factory RelayError.badRequest() = BadRequest;

  /// The request never reached the relay at all — no connectivity, a
  /// timeout before any response, a DNS failure. Not a catalogue code;
  /// this is what puts a row in the outbox instead of a message on a
  /// screen (FR-042).
  const factory RelayError.transport() = TransportFailure;
}

/// Which of the two situations raised `SESSION_ALREADY_JUDGED`. A learner
/// who double-tapped needs nothing at all; a learner speaking after the
/// verdict needs to be told the session is closed. One code, two meanings,
/// two ARB keys (contracts/error-copy.md).
enum JudgedContext {
  /// A repeat `/v1/judge` call for a session already assessed. Idempotent
  /// and invisible — show the assessment already held.
  repeatJudge,

  /// A turn or hint pull attempted after the verdict was delivered.
  turnAfterVerdict,
}

/// The catalogue name of each variant, shown under every error message so
/// a learner or tester can quote the exact failure when they get in touch.
/// `transport` has no wire code, so it gets its own.
extension RelayErrorCode on RelayError {
  String get code => switch (this) {
        RateLimited() => 'RATE_LIMITED',
        InvalidKey() => 'INVALID_KEY',
        QuotaExhausted() => 'QUOTA_EXHAUSTED',
        UnclearRetry() => 'UNCLEAR_RETRY',
        TurnCapReached() => 'TURN_CAP_REACHED',
        TrialConsumed() => 'TRIAL_CONSUMED',
        SessionAlreadyJudged() => 'SESSION_ALREADY_JUDGED',
        EmptyTurn() => 'EMPTY_TURN',
        TrialUnavailable() => 'TRIAL_UNAVAILABLE',
        ProblemKilled() => 'PROBLEM_KILLED',
        BadRequest() => 'BAD_REQUEST',
        TransportFailure() => 'NETWORK',
      };
}
