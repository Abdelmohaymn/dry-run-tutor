// research.md R-004 / DEPLOY-DEV.md: "never branch on HTTP status alone"
// is a parsing property, not a policy — this test is what protects it.
// Four scenarios: a multi-line `data:` field, an `error` frame replacing
// the tail of an opened 200 stream, a stream ending without `meta`, and a
// frame boundary split mid-field across chunk reads.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dry_run/core/network/sse_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Stream<List<int>> chunksOf(List<String> parts) {
    return Stream<List<int>>.fromIterable(parts.map(utf8.encode));
  }

  test('a multi-line data: field is joined with newlines', () async {
    const String raw = 'event: meta\n'
        'data: {"turn_index":1,\n'
        'data: "turns_remaining":9}\n\n';
    final List<SseFrame> frames = await SseParser.parse(chunksOf([raw])).toList();
    expect(frames, hasLength(1));
    final MetaFrame meta = frames.single as MetaFrame;
    expect(meta.rawJson['turn_index'], 1);
    expect(meta.rawJson['turns_remaining'], 9);
  });

  test('an error frame can replace the tail of an already-opened stream', () async {
    const String raw = 'event: token\n'
        'data: {"text":"Walk me through"}\n\n'
        'event: error\n'
        'data: {"error":{"code":"TRIAL_UNAVAILABLE","message":"x","retryable":false}}\n\n';
    final List<SseFrame> frames = await SseParser.parse(chunksOf([raw]))
        .handleError((Object _) {}) // MissingMetaFailure expected at the end
        .toList();
    expect(frames, hasLength(2));
    expect(frames[0], isA<TokenFrame>());
    final ErrorFrame error = frames[1] as ErrorFrame;
    expect(
      (error.rawJson['error']! as Map<String, Object?>)['code'],
      'TRIAL_UNAVAILABLE',
    );
  });

  test('a stream ending without meta completes with MissingMetaFailure', () async {
    const String raw = 'event: token\ndata: {"text":"partial"}\n\n';
    await expectLater(
      SseParser.parse(chunksOf([raw])),
      emitsInOrder(<Object>[isA<TokenFrame>(), emitsError(isA<MissingMetaFailure>())]),
    );
  });

  test('a stream that reaches meta does not fail, even if more chunks follow', () async {
    const String raw = 'event: meta\ndata: {"turn_index":2}\n\nevent: done\ndata: \n\n';
    final List<SseFrame> frames = await SseParser.parse(chunksOf([raw])).toList();
    expect(frames, hasLength(2));
    expect(frames[0], isA<MetaFrame>());
    expect(frames[1], isA<DoneFrame>());
  });

  test('a frame boundary split mid-field across chunk reads still parses', () async {
    // The blank-line boundary and the "meta" event name are each split
    // across two separate chunk deliveries.
    final List<String> parts = <String>[
      'event: tok',
      'en\ndata: {"text":"a"}\n',
      '\nevent: me',
      'ta\ndata: {"turn_index":3}\n\n',
    ];
    final List<SseFrame> frames = await SseParser.parse(chunksOf(parts)).toList();
    expect(frames, hasLength(2));
    expect((frames[0] as TokenFrame).text, 'a');
    expect((frames[1] as MetaFrame).rawJson['turn_index'], 3);
  });

  test('tokens paint one at a time in arrival order', () async {
    const String raw = 'event: token\ndata: {"text":"a"}\n\n'
        'event: token\ndata: {"text":"b"}\n\n'
        'event: meta\ndata: {"turn_index":1}\n\n';
    final List<SseFrame> frames = await SseParser.parse(chunksOf([raw])).toList();
    expect(frames.whereType<TokenFrame>().map((TokenFrame t) => t.text), <String>['a', 'b']);
  });

  // Regression: every test above builds a `Stream<List<int>>`, but `dio`
  // hands the parser a `Stream<Uint8List>`. That reified type difference is
  // load-bearing — `Stream.transform` is covariant in its source element,
  // so a `Uint8List` stream rejects `Utf8Decoder` (a
  // `StreamTransformer<List<int>, String>`) at runtime while the
  // `List<int>` stream accepts it. On device that threw inside the
  // controller's `onListen`, escaped to the zone, and left the turn's
  // `await for` suspended forever behind a spinner that never resolved.
  test('parses the Stream<Uint8List> dio actually delivers', () async {
    const String raw = 'event: token\ndata: {"text":"hi"}\n\n'
        'event: meta\ndata: {"turn_index":1,"turns_remaining":9}\n\n';
    final Stream<Uint8List> bytes = Stream<Uint8List>.fromIterable(
      <Uint8List>[Uint8List.fromList(utf8.encode(raw))],
    );
    final List<SseFrame> frames = await SseParser.parse(bytes).toList();
    expect(frames, hasLength(2));
    expect((frames[0] as TokenFrame).text, 'hi');
    expect((frames[1] as MetaFrame).rawJson['turn_index'], 1);
  });

  // The same escape hatch, viewed from the caller: a failure while setting
  // the source stream up must surface as a stream error, never as a stream
  // that neither emits nor closes.
  test('a source stream that throws on listen errors instead of hanging', () async {
    await expectLater(
      SseParser.parse(_ThrowsOnListenStream()).toList().timeout(const Duration(seconds: 5)),
      throwsA(isA<FormatException>()),
    );
  });
}

/// A stream whose `listen` throws synchronously — the shape of the original
/// device failure, where `Utf8Decoder` was rejected the instant the parser
/// tried to subscribe. `Stream.multi` cannot stand in here: it reports a
/// throwing callback as an asynchronous error event, which never exercised
/// the synchronous path that hung.
class _ThrowsOnListenStream extends Stream<List<int>> {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    throw const FormatException('cannot subscribe');
  }
}
