import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/tokens.dart';

/// The typed-turn path, reached from the composer's "Type instead"
/// control — available **at all times** (FR-010), and, once submitted,
/// routed through the same mandatory review step as a spoken turn
/// (`inputMode: text`). A learner who cannot or will not use voice is
/// fully served by this field, without it being promoted over voice
/// (FR-053).
///
/// One row, in the same place the mic bar occupies, so choosing the
/// keyboard swaps a control rather than moving the learner somewhere else.
class TextComposer extends StatefulWidget {
  const TextComposer({required this.onSubmit, this.onUseMic, super.key});

  final ValueChanged<String> onSubmit;

  /// Back to the mic without leaving the conversation. Null hides the
  /// control (the recogniser is unavailable, so there is nothing to go
  /// back to — FR-011a).
  final VoidCallback? onUseMic;

  @override
  State<TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // The learner just asked for the keyboard; making them tap the field
    // as well is a tap that buys nothing.
    _focusNode.requestFocus();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final String text = _controller.text;
    if (text.trim().isEmpty) {
      return;
    }
    widget.onSubmit(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool canSend = _controller.text.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        if (widget.onUseMic case final VoidCallback onUseMic)
          IconButton(
            onPressed: onUseMic,
            tooltip: l10n.composerUseMicLabel,
            icon: const Icon(Icons.mic_none, color: AppTokens.muted),
          ),
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: 1,
            maxLines: 5,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: l10n.textComposerLabel,
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
          label: l10n.textComposerSendLabel,
          button: true,
          child: IconButton.filled(
            onPressed: canSend ? _submit : null,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: canSend ? AppTokens.accentDim : AppTokens.surface2,
              foregroundColor: canSend ? AppTokens.accent : AppTokens.faint,
            ),
            icon: const Icon(Icons.arrow_upward, size: 20),
          ),
        ),
      ],
    );
  }
}
