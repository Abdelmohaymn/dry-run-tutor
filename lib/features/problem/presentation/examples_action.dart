import 'package:flutter/material.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../domain/problem.dart';

/// "See an example" — the peer of "Pull a hint", and delivered the same
/// way: one authored example at a time, into the conversation, labelled
/// "Example 1 of 3" by the bubble it lands in.
///
/// The statement is deliberately prose — it is meant to be spoken through
/// — which left a learner with no concrete input to picture and a first
/// turn that was a guess about what was even being asked. A sheet was
/// tried first and was wrong: an example belongs in the transcript the
/// learner scrolls back through, not behind a modal that closes and takes
/// it with it.
///
/// Hidden entirely for a problem with no authored examples, and disabled
/// once every one has been shown — the same two states [HintAction] has.
class ExamplesAction extends StatelessWidget {
  const ExamplesAction({
    required this.problem,
    required this.revealed,
    required this.onPressed,
    this.dense = false,
    super.key,
  });

  final Problem problem;

  /// How many are already in the conversation, counted off the message
  /// rows rather than stored — the conversation is the source of truth,
  /// so this survives a restart for free.
  final int revealed;

  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (problem.examples.isEmpty) {
      return const SizedBox.shrink();
    }
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool exhausted = revealed >= problem.examples.length;
    return OutlinedButton.icon(
      onPressed: exhausted ? null : onPressed,
      icon: const Icon(Icons.data_object, size: 18),
      label: Text(l10n.examplesActionLabel),
      style: dense ? OutlinedButton.styleFrom(visualDensity: VisualDensity.compact) : null,
    );
  }
}
