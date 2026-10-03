import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// FR-031's dispute affordance, on every assessment screen.
///
/// It used to be a bare `OutlinedButton` labelled "Dispute this
/// assessment" that, on tap, wrote a flag to the local session row and
/// changed nothing on screen — so it read as a broken button (reported
/// from a physical device, 2026-09-04). It was working; it was simply
/// invisible.
///
/// Two things fix that, and neither changes what disputing *does*:
/// the line underneath says what it is for before the learner taps it
/// (FR-031a: recorded on the device, nothing uploaded — and FR-031b
/// forbids asking for upload consent the app will not act on), and the
/// control acknowledges the tap afterwards using the notice that was
/// already authored in the ARB and never rendered anywhere.
class DisputeAction extends StatelessWidget {
  const DisputeAction({required this.disputed, required this.onPressed, super.key});

  /// `Session.disputed` — set by `AssessmentRepository.recordDispute` and
  /// carried back into state by the Cubit, so this survives a rebuild and
  /// a return to the screen.
  final bool disputed;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    if (disputed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTokens.surface2,
          border: Border.all(color: AppTokens.border),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.flag_outlined, size: 18, color: AppTokens.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.verdictDisputedNotice,
                style: context.appTypography.sansCaption.copyWith(color: AppTokens.muted),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        OutlinedButton(onPressed: onPressed, child: Text(l10n.verdictDisputeAction)),
        const SizedBox(height: 6),
        Text(
          l10n.verdictDisputeExplainer,
          textAlign: TextAlign.center,
          style: context.appTypography.sansCaption.copyWith(color: AppTokens.faint),
        ),
      ],
    );
  }
}
