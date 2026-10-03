import 'package:equatable/equatable.dart';

import '../../../core/models/wire_enums.dart';

/// The unsent draft for a session (data-model.md §4, §9). Persisted on
/// every edit (debounced) and deleted on send or re-record (FR-012b,
/// FR-016, FR-024).
class Draft extends Equatable {
  const Draft({required this.text, this.recognised, this.repaired, required this.inputMode});

  final String text;

  /// The recognised text before any learner edit, if this draft came from
  /// voice — `null` for a typed draft. NEVER overwritten by repair.
  final String? recognised;

  /// What transcript repair returned, or `null` if repair never ran or did
  /// not change anything (data-model.md §3, §4).
  final String? repaired;
  final InputMode inputMode;

  Draft copyWith({String? text}) => Draft(
        text: text ?? this.text,
        recognised: recognised,
        repaired: repaired,
        inputMode: inputMode,
      );

  @override
  List<Object?> get props => <Object?>[text, recognised, repaired, inputMode];
}
