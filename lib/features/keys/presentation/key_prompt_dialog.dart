import 'package:flutter/material.dart';

import '../../../core/config/brand.dart';
import '../../../core/errors/relay_error.dart';
import '../../../core/l10n/generated/app_localizations.dart';

/// The three situations that are resolved by the learner putting a
/// provider key in, and which therefore earn a dialog rather than an
/// inline line of text.
///
/// Two of them (`trialConsumed`, `trialUnavailable`) used to route
/// straight to `/keys/entry` with no explanation at all — the learner
/// landed on a password field mid-conversation and had to infer why. The
/// third (`quotaExhausted`) said its piece in a footer under the
/// composer, where it was easy to miss entirely.
enum KeyPromptReason {
  /// `TRIAL_CONSUMED`: the free sessions this device is allowed (`trial.sessions_per_device`) are used. FR-007.
  trialConsumed,

  /// `TRIAL_UNAVAILABLE`: the shared taster is full **for everyone**
  /// today. Must never borrow quota copy — nothing is wrong with this
  /// learner's allowance.
  trialUnavailable,

  /// `TRIAL_IP_LIMIT`: this network has used today's free sessions.
  trialIpLimited,

  /// `QUOTA_EXHAUSTED`: the learner's own key hit its provider limit.
  /// FR-008d.
  quotaExhausted,
}

/// Which [KeyPromptReason], if any, a [RelayError] deserves.
///
/// Exhaustive with no `default:` branch, for the reason [RelayError]
/// itself gives: a twelfth catalogue code must be a compile error here,
/// not a silent `null` that drops a learner back into an unexplained
/// form.
KeyPromptReason? keyPromptReasonFor(RelayError error) => switch (error) {
      TrialConsumed() => KeyPromptReason.trialConsumed,
      TrialUnavailable() => KeyPromptReason.trialUnavailable,
      TrialIpLimited() => KeyPromptReason.trialIpLimited,
      QuotaExhausted() => KeyPromptReason.quotaExhausted,
      // Everything else is either automatic, inline, or has a screen of
      // its own. `InvalidKey` is deliberately not here: FR-005c asks for
      // a prompt the learner taps, and `_FailureNotice` already is one.
      RateLimited() => null,
      InvalidKey() => null,
      UnclearRetry() => null,
      TurnCapReached() => null,
      SessionAlreadyJudged() => null,
      EmptyTurn() => null,
      ProblemKilled() => null,
      BadRequest() => null,
      TransportFailure() => null,
    };

/// Explains why a key is being asked for, and returns `true` if the
/// learner chose to go and add one.
///
/// **This function does not navigate.** The caller pushes
/// `/keys/entry` — pushes, never `go`s, so the conversation stays on the
/// stack underneath and leaving the form returns to it instead of
/// closing the app.
Future<bool> showKeyPrompt(BuildContext context, KeyPromptReason reason) async {
  final AppLocalizations l10n = AppLocalizations.of(context)!;
  final bool? chose = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(_title(l10n, reason)),
      content: Text(_body(l10n, reason)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(_dismissLabel(l10n, reason)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(_primaryLabel(l10n, reason)),
        ),
      ],
    ),
  );
  return chose ?? false;
}

String _title(AppLocalizations l10n, KeyPromptReason reason) => switch (reason) {
      KeyPromptReason.trialConsumed => l10n.keyPromptTrialTitle,
      KeyPromptReason.trialUnavailable => l10n.keyPromptTrialUnavailableTitle,
      KeyPromptReason.trialIpLimited => l10n.keyPromptTrialIpLimitedTitle,
      KeyPromptReason.quotaExhausted => l10n.keyPromptQuotaTitle,
    };

String _body(AppLocalizations l10n, KeyPromptReason reason) => switch (reason) {
      KeyPromptReason.trialConsumed => l10n.keyPromptTrialBody(AppBrand.name),
      KeyPromptReason.trialUnavailable => l10n.keyPromptTrialUnavailableBody(AppBrand.name),
      KeyPromptReason.trialIpLimited => l10n.keyPromptTrialIpLimitedBody(AppBrand.name),
      KeyPromptReason.quotaExhausted => l10n.keyPromptQuotaBody,
    };

String _primaryLabel(AppLocalizations l10n, KeyPromptReason reason) => switch (reason) {
      KeyPromptReason.trialConsumed ||
      KeyPromptReason.trialUnavailable ||
      KeyPromptReason.trialIpLimited =>
        l10n.keyPromptAddAction,
      // The learner already has a key; the only thing that continues
      // today is a different one (ErrorNextAction.waitOrReplaceKey).
      KeyPromptReason.quotaExhausted => l10n.keyPromptReplaceAction,
    };

String _dismissLabel(AppLocalizations l10n, KeyPromptReason reason) => switch (reason) {
      KeyPromptReason.trialConsumed ||
      KeyPromptReason.trialUnavailable ||
      KeyPromptReason.trialIpLimited =>
        l10n.keyPromptDismissAction,
      KeyPromptReason.quotaExhausted => l10n.keyPromptQuotaDismissAction,
    };
