import 'package:equatable/equatable.dart';

/// One authored rung of the hint ladder, rendered verbatim — no
/// paraphrase, no truncation, no reordering (FR-026, data-model.md §9).
class HintRung extends Equatable {
  const HintRung({required this.index, required this.text, required this.exhausted});

  /// 1-based, for "Hint [index] of `hintCount`" (data-model.md §2).
  final int index;
  final String text;

  /// `true` when [index] is past the authored ladder's length — [text] is
  /// then the server's fixed closing line
  /// (`worker/src/prompts/tutor.ts`'s `LADDER_EXHAUSTED_LINE`), not a rung,
  /// and the session stays open (FR-026, data-model.md §9).
  final bool exhausted;

  @override
  List<Object?> get props => <Object?>[index, text, exhausted];
}
