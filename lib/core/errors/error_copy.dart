import '../l10n/generated/app_localizations.dart';
import 'relay_error.dart';

/// What the next-action control on an error surface actually does. This is
/// closed and structural — decided by the [RelayError] variant, not read
/// off any text — because a screen has to *act*, not just display a
/// string (contracts/error-copy.md, "Next action the screen offers").
enum ErrorNextAction {
  /// `RATE_LIMITED`: nothing to tap. The same turn resumes automatically
  /// when the wait elapses.
  automaticRetry,

  /// `INVALID_KEY`: re-enter the key, conversation preserved.
  reEnterKey,

  /// `QUOTA_EXHAUSTED`: wait for the reset, or replace the key.
  waitOrReplaceKey,

  /// `UNCLEAR_RETRY`: retried once automatically; a second failure leaves
  /// the session pending with the assessment queued.
  retryOnceThenQueue,

  /// `TURN_CAP_REACHED`: end the session and see the assessment, or pull
  /// a hint.
  endSessionOrPullHint,

  /// `TRIAL_CONSUMED` / `TRIAL_UNAVAILABLE`: straight into key entry.
  goToKeyEntry,

  /// `SESSION_ALREADY_JUDGED` (repeat judge): show the assessment already
  /// held. Nothing for the learner to do.
  showExistingAssessment,

  /// `SESSION_ALREADY_JUDGED` (turn after verdict): review the
  /// assessment, or the reveal.
  reviewClosedSession,

  /// `EMPTY_TURN`: re-record, or type.
  reRecordOrType,

  /// `PROBLEM_KILLED`: a different problem is presented; usually
  /// invisible.
  problemSwapped,

  /// `BAD_REQUEST`: retry; update the app if it persists.
  retryOrUpdateApp,

  /// `transport`: a Try again button. Waiting for the outbox to drain on
  /// reconnect left the learner stuck on the notice (found on device), so
  /// the learner retries when they are back online.
  retryWhenOnline,
}

/// The learner-facing message and the structural next action for one
/// [RelayError] variant.
class ErrorCopy {
  const ErrorCopy({required this.message, required this.nextAction, required this.code});

  final String message;
  final ErrorNextAction nextAction;

  /// The catalogue code ([RelayErrorCode.code]), shown in small print under
  /// [message] so a support request names the exact failure.
  final String code;
}

/// Resolves every [RelayError] variant to its [ErrorCopy].
///
/// This `switch` has no `default:` branch. That is deliberate: the eleven
/// catalogue codes plus `transport` are closed, and a twelfth variant
/// added to [RelayError] without a matching ARB key and next action must
/// fail the build here rather than fall through to a generic message
/// (SC-008, FR-044). `test/unit/error_copy_test.dart` walks the same union
/// to assert every branch resolves to a distinct, non-empty key.
ErrorCopy resolveErrorCopy(AppLocalizations l10n, RelayError error) {
  final (String message, ErrorNextAction nextAction) = _resolve(l10n, error);
  return ErrorCopy(message: message, nextAction: nextAction, code: error.code);
}

(String, ErrorNextAction) _resolve(AppLocalizations l10n, RelayError error) {
  return switch (error) {
    RateLimited() => (
        l10n.errRateLimited,
        ErrorNextAction.automaticRetry,
      ),
    InvalidKey() => (
        l10n.errInvalidKey,
        ErrorNextAction.reEnterKey,
      ),
    QuotaExhausted() => (
        l10n.errQuotaExhausted,
        ErrorNextAction.waitOrReplaceKey,
      ),
    UnclearRetry() => (
        l10n.errUnclearRetry,
        ErrorNextAction.retryOnceThenQueue,
      ),
    TurnCapReached() => (
        l10n.errTurnCapReached,
        ErrorNextAction.endSessionOrPullHint,
      ),
    TrialConsumed() => (
        l10n.errTrialConsumed,
        ErrorNextAction.goToKeyEntry,
      ),
    SessionAlreadyJudged(:final ctx) => switch (ctx) {
        JudgedContext.repeatJudge => (
            l10n.errAlreadyJudgedRepeat,
            ErrorNextAction.showExistingAssessment,
          ),
        JudgedContext.turnAfterVerdict => (
            l10n.errSessionClosed,
            ErrorNextAction.reviewClosedSession,
          ),
      },
    EmptyTurn() => (
        l10n.errEmptyTurn,
        ErrorNextAction.reRecordOrType,
      ),
    TrialUnavailable() => (
        l10n.errTrialUnavailable,
        ErrorNextAction.goToKeyEntry,
      ),
    TrialIpLimited() => (
        l10n.errTrialIpLimited,
        ErrorNextAction.goToKeyEntry,
      ),
    ProblemKilled() => (
        l10n.errProblemKilled,
        ErrorNextAction.problemSwapped,
      ),
    BadRequest() => (
        l10n.errBadRequest,
        ErrorNextAction.retryOrUpdateApp,
      ),
    TransportFailure() => (
        l10n.errOfflineQueued,
        ErrorNextAction.retryWhenOnline,
      ),
  };
}
