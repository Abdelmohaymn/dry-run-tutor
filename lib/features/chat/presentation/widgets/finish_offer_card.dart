import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

/// Feature 005. Shown in the `FinishOffered` state, when the relay's
/// finish check (Nemotron) says the learner has already explained every
/// required key insight. An offer, never an action: Finish is the
/// learner's tap, and Keep going hides the card for the rest of the
/// session. Accent, not amber — this is good news, not a limit.
class FinishOfferCard extends StatelessWidget {
  const FinishOfferCard({required this.onFinish, required this.onKeepGoing, super.key});

  final VoidCallback onFinish;
  final VoidCallback onKeepGoing;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.accentDim,
        border: Border.all(color: AppTokens.accentBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.finishOfferTitle,
            style: context.appTypography.sansHeadline.copyWith(color: AppTokens.accent, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(l10n.finishOfferBody, style: context.appTypography.sansCaption),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: onKeepGoing,
                  child: Text(l10n.finishOfferKeepGoing),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.task_alt, size: 18),
                  label: Text(l10n.finishOfferFinish),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
