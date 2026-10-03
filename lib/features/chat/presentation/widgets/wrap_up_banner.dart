import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';

/// Entered when `turnIndex >= config.chat.wrap_up_at_turn` (the
/// `WrappingUp` state). The conversation winds down rather than stopping
/// dead (FR-022), and the copy protects the learner's own free allowance
/// rather than scoring them (FR-022a). Amber, never red — this is not a
/// failure (design-tokens.md).
///
/// The card said "it's a good place to end and see how it went" and gave
/// the learner nothing to end it with — the only way through was an
/// unlabelled app-bar icon, and a learner who assumed the tutor would
/// close the session itself simply never got an assessment (reported from
/// a physical device, 2026-09-04). The action now sits in the sentence
/// that recommends it, and the line below says plainly that finishing is
/// theirs to do.
class WrapUpBanner extends StatelessWidget {
  const WrapUpBanner({required this.onFinish, super.key});

  /// `null` until there is something to assess — `endSessionUser()`
  /// refuses a session with no turns, so offering it then would be a
  /// button that does nothing.
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTokens.amberDim,
        border: Border.all(color: AppTokens.amberBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            l10n.wrapUpBannerTitle,
            style: context.appTypography.sansHeadline.copyWith(color: AppTokens.amber, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(l10n.wrapUpBannerBody, style: context.appTypography.sansCaption),
          if (onFinish case final VoidCallback onFinish) ...<Widget>[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onFinish,
                icon: const Icon(Icons.task_alt, size: 18),
                label: Text(l10n.wrapUpFinishAction),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.endSessionExplainer,
              style: context.appTypography.sansCaption.copyWith(
                color: AppTokens.faint,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
