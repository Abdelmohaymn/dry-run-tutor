import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../voice/presentation/widgets/waveform.dart';

/// Recording, **in the conversation** — the waveform, the clock, the words
/// as they land, and stop/cancel, all in the composer's own slot.
///
/// Speaking used to push a full screen (`/session/record`) over the chat
/// and then hand off to a second full screen to edit the transcript, so a
/// single turn cost two screen changes and the conversation vanished for
/// both of them. Nothing about FR-013a changes here: the 90-second cap and
/// its 15-second warning are still the Cubit's, and this is still the only
/// thing on screen that can stop the listen session.
class InlineRecorder extends StatelessWidget {
  const InlineRecorder({
    required this.elapsed,
    required this.levels,
    required this.warned,
    required this.partialText,
    required this.onStop,
    required this.onCancel,
    this.limit,
    super.key,
  });

  final Duration elapsed;
  final List<double> levels;
  final bool warned;

  /// What the recogniser has heard so far (FR-013b) — shown live so an
  /// interrupted session still leaves the learner something to judge by.
  final String partialText;

  final VoidCallback onStop;
  final VoidCallback onCancel;

  /// The hard length of this clip on the cloud voice path. When set, the
  /// clock counts down to it instead of up, and the label says the clip is
  /// being recorded for upload. Null keeps the on-device behaviour.
  final Duration? limit;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final Duration? limit = this.limit;
    final Duration shown = limit == null
        ? elapsed
        : (limit > elapsed ? limit - elapsed : Duration.zero);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (partialText.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 96),
            child: SingleChildScrollView(
              reverse: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
                child: Text(
                  partialText,
                  style: context.appTypography.sansBody.copyWith(color: AppTokens.muted),
                ),
              ),
            ),
          ),
        if (warned)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              l10n.recordingWarningNotice,
              textAlign: TextAlign.center,
              style: context.appTypography.sansCaption.copyWith(color: AppTokens.amber),
            ),
          ),
        Row(
          children: <Widget>[
            IconButton(
              onPressed: onCancel,
              tooltip: l10n.recordingCancelLabel,
              icon: const Icon(Icons.close, color: AppTokens.muted),
            ),
            Expanded(
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppTokens.surface2,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: warned ? AppTokens.amberBorder : AppTokens.accentBorder),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.fiber_manual_record, size: 10, color: AppTokens.accent),
                    const SizedBox(width: 8),
                    // Visible, not just announced: the recogniser is
                    // English-only for now, and this is the one moment the
                    // learner needs to know it.
                    Text(
                      limit == null ? l10n.recordingListeningLabel : l10n.recordingCloudLabel,
                      style: context.appTypography.sansCaption.copyWith(color: AppTokens.muted),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        label: l10n.recordingWaveformSemanticLabel,
                        child: ExcludeSemantics(child: Waveform(levels: levels, height: 26)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(formatElapsed(shown), style: context.appTypography.monoBody),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: l10n.recordingStopLabel,
              button: true,
              child: IconButton.filled(
                onPressed: onStop,
                tooltip: l10n.recordingStopLabel,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: AppTokens.accentDim,
                  foregroundColor: AppTokens.accent,
                ),
                icon: const Icon(Icons.check, size: 22),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
