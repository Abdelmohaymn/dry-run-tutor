import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/wire_enums.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../../transcript/presentation/widgets/glossary_chips.dart';
import '../../domain/draft.dart';

/// The **mandatory** review step (Principle V, FR-012), in the composer's
/// own slot rather than on a screen of its own.
///
/// Nothing about the guarantee changes: this is still the only place
/// `send()` is reachable from, re-record is still a peer of send
/// (FR-012b), and the tap-to-fix chips are still here (FR-012a). What
/// changes is that the learner reads their draft with the conversation
/// still above it, instead of on a screen that replaced the conversation.
class InlineReview extends StatefulWidget {
  const InlineReview({
    required this.draft,
    required this.glossaryTerms,
    required this.onChanged,
    required this.onGlossaryApply,
    required this.onSend,
    required this.onSecondary,
    required this.onRevert,
    super.key,
  });

  final Draft draft;
  final List<String> glossaryTerms;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onGlossaryApply;
  final VoidCallback onSend;

  /// FR-005, US2. Restores the raw recogniser output. Shown only when
  /// repair changed something and the learner has not already reverted
  /// (data-model.md §3).
  final VoidCallback onRevert;

  /// Re-record for a spoken draft, discard for a typed one — the Cubit
  /// decides which; this widget only decides how it is labelled.
  final VoidCallback onSecondary;

  @override
  State<InlineReview> createState() => _InlineReviewState();
}

class _InlineReviewState extends State<InlineReview> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.draft.text;
    _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
  }

  @override
  void didUpdateWidget(covariant InlineReview oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the Cubit changed the text under us — a glossary chip, or
    // the over-length trim. Assigning on every rebuild would fight the
    // learner's own cursor.
    if (widget.draft.text != oldWidget.draft.text && widget.draft.text != _controller.text) {
      _controller.text = widget.draft.text;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool spoken = widget.draft.inputMode == InputMode.voice;
    final bool canSend = widget.draft.text.trim().isNotEmpty;
    final bool showRevert = widget.draft.repaired != null &&
        widget.draft.repaired != widget.draft.recognised &&
        widget.draft.text != widget.draft.recognised;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 6),
          child: Text(
            spoken ? l10n.reviewEditHint : l10n.reviewEditHintTyped,
            style: context.appTypography.sansCaption.copyWith(color: AppTokens.faint),
          ),
        ),
        if (showRevert)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: TextButton(
              onPressed: widget.onRevert,
              child: Text(l10n.reviewRevertLabel),
            ),
          ),
        GlossaryChips(
          draftText: widget.draft.text,
          glossaryTerms: widget.glossaryTerms,
          onApply: (String updatedText, String _) => widget.onGlossaryApply(updatedText),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            IconButton(
              onPressed: widget.onSecondary,
              tooltip: spoken ? l10n.reviewReRecordLabel : l10n.reviewDiscardLabel,
              icon: Icon(spoken ? Icons.mic_none : Icons.close, color: AppTokens.muted),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                minLines: 1,
                maxLines: 5,
                onChanged: widget.onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppTokens.surface2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppTokens.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppTokens.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: AppTokens.accentBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              label: l10n.reviewSendLabel,
              button: true,
              child: IconButton.filled(
                onPressed: canSend ? widget.onSend : null,
                tooltip: l10n.reviewSendLabel,
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  backgroundColor: canSend ? AppTokens.accentDim : AppTokens.surface2,
                  foregroundColor: canSend ? AppTokens.accent : AppTokens.faint,
                ),
                icon: const Icon(Icons.arrow_upward, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
