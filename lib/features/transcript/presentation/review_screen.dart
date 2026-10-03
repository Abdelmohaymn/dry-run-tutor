import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/generated/app_localizations.dart';
import '../../../core/models/wire_enums.dart';
import '../../../core/theme/app_theme.dart';
import '../../chat/presentation/daily_session_cubit.dart';
import '../../chat/presentation/daily_session_state.dart';
import 'widgets/glossary_chips.dart';

/// Prototype screen 3: the recognised draft as editable text, **mandatory**
/// — no path sends without passing here (Principle V) — with re-record as
/// a peer of send (FR-012b) and tap-to-fix glossary chips (FR-012a).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final TextEditingController _controller = TextEditingController();
  String _lastKnownStateText = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reviewTitle)),
      body: SafeArea(
        child: BlocBuilder<DailySessionCubit, DailySessionState>(
          builder: (BuildContext context, DailySessionState state) {
            if (state is Recognising) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is! ReviewingTranscript) {
              return const SizedBox.shrink();
            }
            if (_controller.text != state.draft.text && state.draft.text != _lastKnownStateText) {
              _controller.text = state.draft.text;
              _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
            }
            _lastKnownStateText = state.draft.text;

            final DailySessionCubit cubit = context.read<DailySessionCubit>();
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    // Nothing was heard on the typed path, so the
                    // spoken-path wording about mishearing read as
                    // nonsense there (found on device).
                    state.draft.inputMode == InputMode.voice
                        ? l10n.reviewEditHint
                        : l10n.reviewEditHintTyped,
                    style: context.appTypography.sansCaption,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      onChanged: cubit.updateDraftText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlossaryChips(
                    draftText: state.draft.text,
                    glossaryTerms: state.session.problem.glossaryTerms,
                    onApply: (String updatedText, String _) => cubit.applyGlossaryChipEdit(updatedText),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          // Re-record opens the microphone, which is not
                          // what a turn the learner *typed* asked for —
                          // that path goes back to the composer instead.
                          onPressed: state.draft.inputMode == InputMode.voice
                              ? cubit.reRecord
                              : cubit.discardDraft,
                          child: Text(
                            state.draft.inputMode == InputMode.voice
                                ? l10n.reviewReRecordLabel
                                : l10n.reviewDiscardLabel,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: state.draft.text.trim().isEmpty ? null : cubit.send,
                          child: Text(l10n.reviewSendLabel),
                        ),
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
