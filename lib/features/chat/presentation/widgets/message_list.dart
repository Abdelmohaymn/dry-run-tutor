import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/l10n/generated/app_localizations.dart';
import '../../../../core/models/wire_enums.dart';
import '../../../../core/text/markdown_text.dart';
import 'top_fade.dart';
import 'typing_indicator.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/tokens.dart';
import '../../domain/message.dart';

/// Appends tokens as they arrive and scrolls on the same tick — buffering
/// and revealing does not satisfy FR-018. [streamingText], when non-null,
/// is painted as a trailing tutor bubble still in flight.
class MessageList extends StatefulWidget {
  const MessageList({
    required this.messages,
    required this.hintCount,
    this.exampleCount = 0,
    this.streamingText,
    this.awaitingReply = false,
    this.onRetry,
    super.key,
  });

  final List<Message> messages;

  /// The cached problem's authored ladder length, for "Hint n of
  /// `hintCount`" labels (FR-026). A hint's own 1-based ordinal is derived
  /// here by counting `MessageKind.hintRung` rows up to and including it,
  /// rather than stored on the row — hints are revealed strictly in
  /// order and never removed, so the count is the index.
  final int hintCount;

  /// How many worked examples the problem has, for the "Example n of m"
  /// label — the ordinal itself is counted off the rows, exactly as the
  /// hint ordinal is.
  final int exampleCount;
  final String? streamingText;

  /// The turn is sent and the first token has not arrived. Paints a tutor
  /// bubble carrying [TypingIndicator] — the waiting belongs where the
  /// answer will appear, not in the composer.
  final bool awaitingReply;

  /// FR-042. `null` only where retrying makes no sense — the session is
  /// over, or the conversation is being shown read-only.
  final ValueChanged<Message>? onRetry;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messages.length != widget.messages.length ||
        oldWidget.streamingText != widget.streamingText ||
        oldWidget.awaitingReply != widget.awaitingReply) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int extra = widget.streamingText == null && !widget.awaitingReply ? 0 : 1;
    // 1-based ordinal per `MessageKind.hintRung` row, in seq order — the
    // index this pull's own `HintRung.index` already carried server-side;
    // recomputed here rather than stored on the row (FR-026).
    int hintOrdinal = 0;
    int exampleOrdinal = 0;
    final Map<String, int> hintOrdinalByMessageId = <String, int>{};
    final Map<String, int> exampleOrdinalByMessageId = <String, int>{};
    for (final Message message in widget.messages) {
      if (message.kind == MessageKind.hintRung) {
        hintOrdinal++;
        hintOrdinalByMessageId[message.id] = hintOrdinal;
      } else if (message.kind == MessageKind.example) {
        exampleOrdinal++;
        exampleOrdinalByMessageId[message.id] = exampleOrdinal;
      }
    }

    if (widget.messages.isEmpty && widget.streamingText == null && !widget.awaitingReply) {
      // Before the first turn this area was a full screen of nothing, which
      // read as a screen that had failed to load rather than as an invitation
      // (found on device). It says what to do and disappears the moment a
      // message exists.
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            AppLocalizations.of(context)!.conversationEmptyBody,
            textAlign: TextAlign.center,
            style: context.appTypography.sansBody.copyWith(color: AppTokens.faint),
          ),
        ),
      );
    }

    return TopFade(
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.messages.length + extra,
        itemBuilder: (BuildContext context, int index) {
          if (index >= widget.messages.length) {
            final String? streaming = widget.streamingText;
            return streaming == null
                ? const _PendingBubble()
                : _MessageBubble(role: TurnRole.tutor, text: streaming, failed: false);
          }
          final Message message = widget.messages[index];
          return _MessageBubble(
            role: message.role,
            text: message.text,
            failed: message.delivery == Delivery.failedRetryable,
            onRetry: widget.onRetry == null ? null : () => widget.onRetry!(message),
            kind: message.kind,
            hintIndex: hintOrdinalByMessageId[message.id],
            hintCount: widget.hintCount,
            exampleIndex: exampleOrdinalByMessageId[message.id],
            exampleCount: widget.exampleCount,
          );
        },
      ),
    );
  }
}

/// The tutor's bubble before its first token — same shape, same place,
/// three dots instead of words.
class _PendingBubble extends StatelessWidget {
  const _PendingBubble();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 14),
        decoration: BoxDecoration(color: AppTokens.surface2, borderRadius: BorderRadius.circular(11)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l10n.messageListTutorLabel, style: context.appTypography.monoLabel),
            const SizedBox(height: 8),
            const TypingIndicator(),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.text,
    required this.failed,
    this.onRetry,
    this.kind = MessageKind.turn,
    this.hintIndex,
    this.hintCount = 0,
    this.exampleIndex,
    this.exampleCount = 0,
  });

  final TurnRole role;
  final String text;
  final bool failed;
  final VoidCallback? onRetry;
  final MessageKind kind;
  final int? hintIndex;
  final int hintCount;
  final int? exampleIndex;
  final int exampleCount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final bool isUser = role == TurnRole.user;
    final String label = switch (kind) {
      MessageKind.hintRung when hintIndex != null => l10n.hintMessageLabel(hintIndex!, hintCount),
      MessageKind.example when exampleIndex != null => l10n.exampleMessageLabel(exampleIndex!, exampleCount),
      MessageKind.ladderExhausted => l10n.hintLadderExhaustedLabel,
      _ => isUser ? l10n.messageListYouLabel : l10n.messageListTutorLabel,
    };
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPressStart: (LongPressStartDetails details) => _showCopyMenu(context, details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isUser ? AppTokens.surface3 : AppTokens.surface2,
            borderRadius: BorderRadius.circular(11),
            border: failed ? Border.all(color: AppTokens.border2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(label, style: context.appTypography.monoLabel),
              const SizedBox(height: 4),
              // The tutor and the hint ladder speak Markdown; a learner's
              // own turn is literal text and stays that way, so a stray
              // asterisk they typed is never eaten as formatting.
              if (isUser) Text(text, style: context.appTypography.sansBody) else MarkdownText(text),
              if (failed) ...<Widget>[
                const SizedBox(height: 4),
                // A real control, not a caption describing one. The label
                // says "tap to retry"; until this it was not tappable.
                InkWell(
                  onTap: onRetry,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.refresh, size: 14, color: AppTokens.red),
                        const SizedBox(width: 6),
                        // Flexible: the bubble is capped at 320 and this
                        // label wraps rather than overflowing at the larger
                        // accessibility text sizes.
                        Flexible(
                          child: Text(
                            l10n.messageListFailedRetryLabel,
                            style: context.appTypography.sansCaption.copyWith(color: AppTokens.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Long press offers Copy. The raw text is copied, so a tutor reply keeps
  /// its Markdown and pastes the way it was written.
  Future<void> _showCopyMenu(BuildContext context, Offset position) async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    unawaited(HapticFeedback.selectionClick());
    // Not `showMenu`: Material menus round their width up in 56px steps,
    // which left a wide box around one short word. This one wraps its
    // content and sits where the finger was.
    final bool? copy = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 120),
      transitionBuilder: (_, Animation<double> animation, _, Widget child) =>
          FadeTransition(opacity: animation, child: child),
      pageBuilder: (BuildContext dialogContext, _, _) {
        final Size screen = MediaQuery.sizeOf(dialogContext);
        return Stack(
          children: <Widget>[
            Positioned(
              // Kept on screen near the right edge and the bottom.
              left: position.dx.clamp(8, screen.width - 96),
              top: (position.dy - 44).clamp(8, screen.height - 48),
              child: Material(
                color: AppTokens.surface3,
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => Navigator.of(dialogContext).pop(true),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.copy, size: 14),
                        const SizedBox(width: 6),
                        Text(l10n.messageCopyAction, style: context.appTypography.sansCaption),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    if (copy != true) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(l10n.messageCopiedNotice)));
    }
  }
}
