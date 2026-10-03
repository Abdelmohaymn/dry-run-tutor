import 'dart:async';
import 'dart:convert';

/// A single Server-Sent Event frame off `/v1/chat` or `/v1/trial`
/// (mode=chat). Sealed so the Cubit that consumes this stream switches
/// exhaustively — a fifth frame type would be a compile error, not a
/// silently-ignored one.
sealed class SseFrame {
  const SseFrame();
}

/// One streamed token of the tutor's reply. FR-018: painted as it arrives.
class TokenFrame extends SseFrame {
  const TokenFrame(this.text);

  final String text;
}

/// The whole state channel for this turn — `turn_index`, `turns_remaining`,
/// `hints_revealed`, `hints_remaining`, `session_ended`, `leak_blocked`,
/// and optionally `summary`, exactly as the wire sent them (FR-019).
/// [rawJson] is the decoded `data:` payload, mapped to `MetaFrameDto` one
/// layer up — this parser has no opinion on the schema's field names.
class MetaFrame extends SseFrame {
  const MetaFrame(this.rawJson);

  final Map<String, Object?> rawJson;
}

/// An `error` frame — the same envelope a non-2xx body carries, arriving
/// instead inside an already-opened 200 stream. `research.md` R-004: this
/// is mapped through the identical `RelayError` code path as any other
/// error body, never a special case.
class ErrorFrame extends SseFrame {
  const ErrorFrame(this.rawJson);

  final Map<String, Object?> rawJson;
}

/// The stream's own end-of-stream marker (distinct from the Dart
/// `Stream`'s `done` — the relay sends an explicit `event: done` frame).
class DoneFrame extends SseFrame {
  const DoneFrame();
}

/// Raised when the byte stream ends without ever emitting a [MetaFrame].
/// The `meta` frame is the app's whole state channel (contracts §
/// relay-client.md); its absence is not a token that got lost, it is the
/// one condition this parser treats as a hard failure of its own rather
/// than leaving the caller to notice a short stream.
class MissingMetaFailure implements Exception {
  const MissingMetaFailure();

  @override
  String toString() => 'MissingMetaFailure: the stream ended without a meta frame';
}

/// Parses a raw SSE byte stream into [SseFrame]s.
///
/// Decodes UTF-8, splits on the blank-line frame separator (`\n\n`), reads
/// `event:`/`data:` lines (`data:` may repeat and is joined with `\n`, per
/// the SSE spec), and emits exactly the four frame types above.
///
/// **Never branches on HTTP status.** This transformer is handed the same
/// byte stream regardless of whether the response was 200 or non-2xx —
/// `DEPLOY-DEV.md` records that `TRIAL_UNAVAILABLE` and friends can arrive
/// as an `error` frame inside an already-opened stream depending on
/// timing, so "the status was 200" is never treated as success here. The
/// caller's success signal is "a `meta` frame arrived".
class SseParser {
  /// Transforms a chunked byte stream into a stream of [SseFrame]s.
  /// Completes with a [MissingMetaFailure] error if the source stream
  /// closes without ever emitting a [MetaFrame].
  static Stream<SseFrame> parse(Stream<List<int>> bytes) {
    late final StreamController<SseFrame> controller;
    StreamSubscription<String>? subscription;
    bool sawMeta = false;
    String buffer = '';

    void flushEvent(String rawEvent) {
      if (rawEvent.trim().isEmpty) {
        return;
      }
      String? eventName;
      final List<String> dataLines = <String>[];
      for (final String line in rawEvent.split('\n')) {
        if (line.startsWith('event:')) {
          eventName = line.substring('event:'.length).trim();
        } else if (line.startsWith('data:')) {
          dataLines.add(line.substring('data:'.length).trimLeft());
        }
      }
      final String data = dataLines.join('\n');

      switch (eventName) {
        case 'token':
          final Map<String, Object?> json = _decode(data);
          final Object? text = json['text'];
          controller.add(TokenFrame(text is String ? text : data));
        case 'meta':
          sawMeta = true;
          controller.add(MetaFrame(_decode(data)));
        case 'error':
          controller.add(ErrorFrame(_decode(data)));
        case 'done':
          controller.add(const DoneFrame());
        case null:
          // No `event:` line — SSE defaults to a "message" event, which
          // this contract never uses deliberately, but a frame with data
          // and no name is still worth surfacing rather than dropping.
          if (data.isNotEmpty) {
            controller.add(TokenFrame(data));
          }
        default:
          // An event name outside the four the contract defines. Ignored
          // rather than surfaced as an error — a forward-compatible
          // addition to the stream should not break an older client.
          break;
      }
    }

    controller = StreamController<SseFrame>(
      onListen: () {
        // Anything that throws in here throws inside the controller's
        // `onListen` callback, which the async machinery reports to the
        // zone rather than to our subscriber — the controller would then
        // never emit and never close, hanging the caller's `await for`
        // forever (a spinner that never resolves). Routing it to
        // `addError` keeps a setup failure on the same path as a
        // mid-stream one.
        try {
          // `utf8.decoder.bind` rather than `bytes.transform(utf8.decoder)`:
          // `transform` is covariant in the source element type, so a
          // `Stream<Uint8List>` (what `dio` hands us) demands a
          // `StreamTransformer<Uint8List, String>` at runtime, which
          // `Utf8Decoder` — a `StreamTransformer<List<int>, String>` — is
          // not. `bind` takes the declared `Stream<List<int>>` and sidesteps
          // the downcast entirely.
          subscription = utf8.decoder.bind(bytes).listen(
            (String chunk) {
              buffer += chunk;
              int splitAt;
              while ((splitAt = _findFrameBoundary(buffer)) != -1) {
                final String rawEvent = buffer.substring(0, splitAt);
                buffer = buffer.substring(splitAt);
                buffer = _stripLeadingBoundary(buffer);
                flushEvent(rawEvent);
              }
            },
            onError: controller.addError,
            onDone: () {
              if (buffer.trim().isNotEmpty) {
                flushEvent(buffer);
              }
              if (!sawMeta) {
                controller.addError(const MissingMetaFailure());
              }
              controller.close();
            },
            cancelOnError: true,
          );
        } catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          controller.close();
        }
      },
      onCancel: () => subscription?.cancel(),
    );
    return controller.stream;
  }

  static Map<String, Object?> _decode(String data) {
    if (data.isEmpty) {
      return const <String, Object?>{};
    }
    final Object? decoded = jsonDecode(data);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  }

  /// The index of the first `\n\n` or `\r\n\r\n` frame boundary, or -1.
  /// Handles a boundary split across chunk reads because the search runs
  /// over the accumulated buffer, not the latest chunk alone.
  static int _findFrameBoundary(String buffer) {
    final int lfLf = buffer.indexOf('\n\n');
    final int crlfCrlf = buffer.indexOf('\r\n\r\n');
    if (lfLf == -1) {
      return crlfCrlf;
    }
    if (crlfCrlf == -1) {
      return lfLf;
    }
    return lfLf < crlfCrlf ? lfLf : crlfCrlf;
  }

  static String _stripLeadingBoundary(String buffer) {
    if (buffer.startsWith('\r\n\r\n')) {
      return buffer.substring(4);
    }
    if (buffer.startsWith('\n\n')) {
      return buffer.substring(2);
    }
    return buffer;
  }
}
