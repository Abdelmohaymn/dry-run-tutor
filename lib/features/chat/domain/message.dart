import 'package:equatable/equatable.dart';

import '../../../core/models/wire_enums.dart';

/// One row of the conversation (data-model.md §4, §9). Pure Dart — no
/// Drift, no DTO — mapped at the data-layer boundary by
/// `SessionRepositoryImpl`.
class Message extends Equatable {
  const Message({
    required this.id,
    required this.seq,
    required this.role,
    required this.text,
    required this.kind,
    required this.delivery,
    this.recognisedDraft,
    this.inputMode,
  });

  final String id;
  final int seq;

  /// `user` / `tutor` — the app's own wire vocabulary, never the
  /// provider's `user`/`assistant`.
  final TurnRole role;
  final String text;

  /// Distinguishes an ordinary turn from a hint rung, a fallback redirect
  /// (`meta.leak_blocked`), or the ladder-exhausted closing line. Only
  /// `kind: turn` rows are replayed as conversation context (FR-020).
  final MessageKind kind;
  final Delivery delivery;

  /// The pre-edit recognised draft, kept alongside the (possibly edited)
  /// `text` for `transcript_edited.chars_changed` (FR-003 of US1).
  final String? recognisedDraft;

  /// `null` for a tutor message; `voice` or `text` for a learner turn —
  /// Principle I's own falsification test.
  final InputMode? inputMode;

  Message copyWith({Delivery? delivery}) => Message(
        id: id,
        seq: seq,
        role: role,
        text: text,
        kind: kind,
        delivery: delivery ?? this.delivery,
        recognisedDraft: recognisedDraft,
        inputMode: inputMode,
      );

  @override
  List<Object?> get props => <Object?>[
        id,
        seq,
        role,
        text,
        kind,
        delivery,
        recognisedDraft,
        inputMode,
      ];
}
