import '../../../core/network/dto/chat_dto.dart';
import '../../../core/network/sse_parser.dart';
import '../domain/server_counters.dart';
import '../domain/turn_event.dart';

/// Frames off the wire, as the events `sendTurn` yields — the pure half of
/// the loop, shared by the app's repository and the web demo's (feature
/// 007, T044). `done` and `error` frames yield nothing: an `error` frame is
/// already a thrown `RelayException` by the time the app sees frames, and
/// on the web a stream with no `meta` ends in `SseParser`'s own
/// `MissingMetaFailure`.
Stream<TurnEvent> turnEventsFromFrames(Stream<SseFrame> frames) async* {
  await for (final SseFrame frame in frames) {
    switch (frame) {
      case TokenFrame(:final text):
        yield TurnEvent.token(text);
      case MetaFrame(:final rawJson):
        yield TurnEvent.meta(countersFromMetaDto(MetaFrameDto.fromJson(rawJson)));
      case DoneFrame():
      case ErrorFrame():
        break;
    }
  }
}

ServerCounters countersFromMetaDto(MetaFrameDto dto) => ServerCounters(
      turnIndex: dto.turnIndex,
      turnsRemaining: dto.turnsRemaining,
      hintsRevealed: dto.hintsRevealed,
      hintsRemaining: dto.hintsRemaining,
      sessionEnded: dto.sessionEnded,
      leakBlocked: dto.leakBlocked,
      readyToFinish: dto.readyToFinish ?? false,
    );
