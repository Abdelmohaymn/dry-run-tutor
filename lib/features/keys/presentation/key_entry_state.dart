import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/errors/relay_error.dart';

part 'key_entry_state.freezed.dart';

/// `data-model.md` §11's `KeyEntryState`: `entering → probing → saved |
/// rejected(preservingInput)`. [Rejected] carries the same [providerId]
/// and [value] the learner typed — US2 scenario 5 requires what they
/// typed to survive a rejection, so losing it here would be the bug the
/// state exists to prevent.
@freezed
sealed class KeyEntryState with _$KeyEntryState {
  const factory KeyEntryState.entering({
    required List<String> providers,
    required String providerId,
    required String value,
  }) = KeyEntryEntering;

  const factory KeyEntryState.probing({
    required List<String> providers,
    required String providerId,
    required String value,
  }) = KeyEntryProbing;

  const factory KeyEntryState.saved({required String providerId}) = KeyEntrySaved;

  const factory KeyEntryState.rejected({
    required List<String> providers,
    required String providerId,
    required String value,
    required RelayError error,
  }) = KeyEntryRejected;
}
