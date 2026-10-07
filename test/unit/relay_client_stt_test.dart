// RelayClient.stt() against a real Dio with a scripted transport, the same
// seam remote_config_test.dart uses. Proves the header rules (X-Install-Id
// only, never X-User-Key / X-Provider), the audio content type and language
// query, and how each Worker refusal surfaces: the three voice codes as
// SttRefusedException, everything else as RelayException.
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dry_run/core/errors/relay_error.dart';
import 'package:dry_run/core/network/dto/stt_dto.dart';
import 'package:dry_run/core/network/relay_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every call with [_behaviour] and records the request it saw.
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this._behaviour);

  final ResponseBody Function() _behaviour;
  RequestOptions? lastRequest;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return _behaviour();
  }
}

ResponseBody _json(int status, String json) => ResponseBody.fromString(
  json,
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>['application/json'],
  },
);

String _errorBody(String code) =>
    '{"error":{"code":"$code","message":"m","retryable":false}}';

({RelayClient client, _CapturingAdapter adapter}) _clientReturning(
  ResponseBody Function() behaviour,
) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://relay.test'));
  final _CapturingAdapter adapter = _CapturingAdapter(behaviour);
  dio.httpClientAdapter = adapter;
  return (client: RelayClient(dio), adapter: adapter);
}

Future<SttResponseDto> _stt(RelayClient client, {String? language = 'en'}) {
  return client.stt(
    installId: 'install-123',
    audio: Uint8List.fromList(<int>[1, 2, 3, 4]),
    contentType: 'audio/mp4',
    language: language,
  );
}

void main() {
  test('200 parses the transcript and the remaining budget', () async {
    final harness = _clientReturning(
      () => _json(
        200,
        '{"text":"hello there","seconds_left":240,"max_clip_seconds":120}',
      ),
    );

    final SttResponseDto dto = await _stt(harness.client);

    expect(dto.text, 'hello there');
    expect(dto.secondsLeft, 240);
    expect(dto.maxClipSeconds, 120);
  });

  test(
    'the request carries X-Install-Id, audio/mp4 and the language, never X-User-Key',
    () async {
      final harness = _clientReturning(
        () =>
            _json(200, '{"text":"x","seconds_left":1,"max_clip_seconds":120}'),
      );

      await _stt(harness.client);

      final RequestOptions request = harness.adapter.lastRequest!;
      expect(request.method, 'POST');
      expect(request.path, '/v1/stt');
      expect(request.headers['X-Install-Id'], 'install-123');
      expect(request.contentType, 'audio/mp4');
      expect(request.queryParameters['language'], 'en');
      expect(request.headers[Headers.contentLengthHeader], 4);

      final Iterable<String> names = request.headers.keys.map(
        (String k) => k.toLowerCase(),
      );
      expect(names, isNot(contains('x-user-key')));
      expect(names, isNot(contains('x-provider')));
    },
  );

  test('a null language sends no language query', () async {
    final harness = _clientReturning(
      () => _json(200, '{"text":"x","seconds_left":1,"max_clip_seconds":120}'),
    );

    await _stt(harness.client, language: null);

    expect(harness.adapter.lastRequest!.queryParameters, isEmpty);
  });

  group('refusals', () {
    Future<void> expectRefusal(
      int status,
      String code,
      SttRefusal refusal,
    ) async {
      final harness = _clientReturning(() => _json(status, _errorBody(code)));
      await expectLater(
        _stt(harness.client),
        throwsA(
          isA<SttRefusedException>().having(
            (SttRefusedException e) => e.refusal,
            'refusal',
            refusal,
          ),
        ),
      );
    }

    test(
      '429 VOICE_EXHAUSTED is exhausted',
      () => expectRefusal(429, 'VOICE_EXHAUSTED', SttRefusal.exhausted),
    );

    test(
      '503 VOICE_UNAVAILABLE is unavailable',
      () => expectRefusal(503, 'VOICE_UNAVAILABLE', SttRefusal.unavailable),
    );

    test(
      '503 VOICE_BUSY is busy',
      () => expectRefusal(503, 'VOICE_BUSY', SttRefusal.busy),
    );
  });

  test('400 BAD_REQUEST is a RelayException(BadRequest)', () async {
    final harness = _clientReturning(
      () => _json(400, _errorBody('BAD_REQUEST')),
    );

    await expectLater(
      _stt(harness.client),
      throwsA(
        isA<RelayException>().having(
          (RelayException e) => e.error,
          'error',
          isA<BadRequest>(),
        ),
      ),
    );
  });

  test('a connection error is a RelayException(TransportFailure)', () async {
    final harness = _clientReturning(() {
      throw DioException(
        requestOptions: RequestOptions(path: '/v1/stt'),
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(
      _stt(harness.client),
      throwsA(
        isA<RelayException>().having(
          (RelayException e) => e.error,
          'error',
          isA<TransportFailure>(),
        ),
      ),
    );
  });
}
