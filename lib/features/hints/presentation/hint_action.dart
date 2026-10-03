import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../chat/domain/session.dart';

/// An **explicit control**, distinct from asking for a hint inside the
/// conversation (FR-025). Disabled once the authored ladder is exhausted
/// rather than left to fail on the wire a second time.
class HintAction extends StatelessWidget {
  const HintAction({
    required this.session,
    required this.onPressed,
    super.key,
  });

  final Session session;

  /// `null` while a pull is already in flight, or once the ladder is
  /// exhausted.
  final VoidCallback? onPressed;

  bool get _exhausted =>
      session.problem.hintCount <= 0 || session.counters.hintsRevealed >= session.problem.hintCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool disabled = onPressed == null || _exhausted;
    return OutlinedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: const Icon(Icons.lightbulb_outline, size: 18),
      label: Text(l10n.hintActionLabel),
      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
    );
  }
}
