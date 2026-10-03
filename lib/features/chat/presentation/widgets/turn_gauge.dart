import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/server_counters.dart';

/// Reads [ServerCounters] — a quiet caption, and worded as **remaining allowance**
/// rather than a score (FR-022a), with a semantic label that announces it
/// the same way (SC-014).
class TurnGauge extends StatelessWidget {
  const TurnGauge({required this.counters, super.key});

  final ServerCounters counters;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final String label = l10n.turnGaugeLabel(counters.turnsRemaining);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Text(label, style: context.appTypography.sansCaption),
      ),
    );
  }
}
