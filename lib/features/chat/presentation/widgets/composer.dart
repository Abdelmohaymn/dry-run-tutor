import 'package:flutter/material.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/theme/tokens.dart';

/// The idle composer: one field, one mic, in a single row.
///
/// It has been three shapes. A 96dp circle over a language picker over a
/// small underlined "or type instead" link took a third of the screen. A
/// mic beside a muted pill was compact but still made the keyboard a
/// destination rather than a thing on screen. This is the shape the
/// practice walkthrough used, which is the one that read best on a device:
/// the field is simply there, and the mic sits on the right where the send
/// action of every other chat app lives.
///
/// FR-009 asks that voice be primary and the keyboard less prominent, and
/// it still is: the mic is a filled accent circle, the field is a muted
/// outline with placeholder text, and nothing about the keyboard is
/// promoted. What changed is that reaching it no longer costs a
/// deliberate tap — a **DEPARTURE** from FR-009's "one deliberate tap
/// away", made twice on the learner's own instruction after the link
/// proved hard to find on a real screen.
///
/// The mic becomes send the moment there is text, so the row never shows
/// two competing primary actions.
class Composer extends StatefulWidget {
  const Composer({
    required this.onMicTap,
    required this.onSubmit,
    this.languagePicker,
    this.controller,
    this.showMic = true,
    super.key,
  });

  final VoidCallback onMicTap;

  /// Optional, so a parent that needs to *write* into the field can own
  /// the controller — the practice walkthrough puts the recognised draft
  /// straight back into this row rather than onto a separate review
  /// screen. When null the composer owns one, which is what the daily
  /// chat does (its review step is `InlineReview`, a different widget).
  final TextEditingController? controller;

  /// False only while recognition is unavailable (FR-011a): the mic is
  /// hidden rather than shown-but-dead, and the trailing button stays a
  /// send action so the keyboard interim path still works.
  final bool showMic;

  /// A typed turn, which routes through the same mandatory review step a
  /// spoken one does (FR-010, FR-012, FR-053).
  final ValueChanged<String> onSubmit;

  /// FR-011b's spoken-language picker. Left in place as a seam — the
  /// widget and its repository still exist — but nothing passes one while
  /// the app speaks English only.
  final Widget? languagePicker;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  /// Non-null only when this widget created it, so `dispose()` never
  /// disposes a controller the parent still owns.
  TextEditingController? _owned;
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? (_owned = TextEditingController());
    _controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _controller.removeListener(_onTextChanged);
      _owned?.dispose();
      _owned = null;
      _controller = widget.controller ?? (_owned = TextEditingController());
      _controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _owned?.dispose();
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
    final bool hasText = _controller.text.trim().isNotEmpty;
    final bool sends = hasText || !widget.showMic;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: l10n.composerTypeInsteadLink,
              isDense: true,
              filled: true,
              fillColor: AppTokens.surface2,
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: AppTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: AppTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(26),
                borderSide: const BorderSide(color: AppTokens.accentBorder),
              ),
            ),
          ),
        ),
        ?widget.languagePicker,
        const SizedBox(width: 10),
        Semantics(
          label: sends ? l10n.textComposerSendLabel : l10n.composerMicSemanticLabel,
          button: true,
          child: InkWell(
            // With the mic hidden the arrow is always showing, so an empty
            // field leaves it inert rather than tappable-but-silent.
            onTap: hasText ? _submit : (widget.showMic ? widget.onMicTap : null),
            customBorder: const CircleBorder(),
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTokens.accentDim,
                border: Border.fromBorderSide(BorderSide(color: AppTokens.accentBorder, width: 2)),
              ),
              child: Icon(
                sends ? Icons.arrow_upward : Icons.mic,
                color: sends && !hasText ? AppTokens.faint : AppTokens.accent,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
