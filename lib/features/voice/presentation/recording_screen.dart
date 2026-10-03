import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import '../../chat/presentation/daily_session_state.dart';
import 'widgets/waveform.dart';

/// Prototype screen 2: live waveform from the level stream, elapsed timer
/// in mono, 90-second cap, warning at 15 seconds left (FR-013a).
///
/// **Nothing routes here any more.** Recording happens inside the
/// conversation (`widgets/inline_recorder.dart`) so a turn no longer costs
/// two screen changes; the route and this screen are kept because the
/// state they render is unchanged and either could be wanted back.
class RecordingScreen extends StatelessWidget {
  const RecordingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<DailySessionCubit, DailySessionState>(
          builder: (BuildContext context, DailySessionState state) {
            if (state is! Recording) {
              return const SizedBox.shrink();
            }
            final int remaining = 90 - state.elapsed.inSeconds;
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(l10n.recordingTitle, style: context.appTypography.sansHeadline),
                  const SizedBox(height: 24),
                  Semantics(
                    label: l10n.recordingWaveformSemanticLabel,
                    child: ExcludeSemantics(child: Waveform(levels: state.levels, width: 240)),
                  ),
                  const SizedBox(height: 24),
                  Text(formatElapsed(state.elapsed), style: context.appTypography.monoDisplay),
                  // What has been recognised so far. Without it the screen
                  // showed a waveform and a clock but no evidence the words
                  // were landing, and an interrupted session gave the
                  // learner nothing to judge by.
                  if (state.partialText.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height / 4),
                      child: SingleChildScrollView(
                        reverse: true,
                        child: Text(
                          state.partialText,
                          textAlign: TextAlign.center,
                          style: context.appTypography.sansBody.copyWith(color: AppTokens.faint),
                        ),
                      ),
                    ),
                  ],
                  if (state.warned) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      l10n.recordingWarningNotice,
                      style: context.appTypography.sansCaption.copyWith(color: AppTokens.amber),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      OutlinedButton(
                        onPressed: () => context.read<DailySessionCubit>().cancelRecording(),
                        child: Text(l10n.recordingCancelLabel),
                      ),
                      const SizedBox(width: 16),
                      FilledButton(
                        onPressed: remaining <= 0
                            ? null
                            : () => context.read<DailySessionCubit>().stopRecording(),
                        child: Text(l10n.recordingStopLabel),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

}
