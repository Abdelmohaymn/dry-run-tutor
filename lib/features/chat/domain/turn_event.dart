import 'package:freezed_annotation/freezed_annotation.dart';

import 'server_counters.dart';

part 'turn_event.freezed.dart';

/// What `SessionRepository.sendTurn` yields as a turn streams in
/// (contracts/repositories.md). A token is painted the instant it arrives
/// (FR-018); a meta closes the turn out with the server's counters, the
/// only source of truth for them (FR-019).
///
/// An `error` frame off the wire never reaches this union — `RelayClient`
/// converts it into a thrown `RelayException` before a caller ever sees a
/// frame, and a stream that ends without a `meta` propagates a
/// `MissingMetaFailure` as a stream error. Both are for the Cubit to
/// catch, per research.md R-004 rule 2.
@freezed
sealed class TurnEvent with _$TurnEvent {
  const factory TurnEvent.token(String text) = TurnEventToken;
  const factory TurnEvent.meta(ServerCounters counters) = TurnEventMeta;
}
