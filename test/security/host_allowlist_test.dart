// FR-004 / Principle VI: the app speaks to exactly one host. A request to
// any other host — including a provider's own API — must throw before it
// reaches the socket, not merely be discouraged by convention.
import 'dart:typed_data';

import 'package:dry_run/core/network/host_allowlist_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Dio dio;

  setUp(() {
    dio = Dio(BaseOptions(baseUrl: 'https://dry-run-tutor.dryrun-app.workers.dev'));
    dio.interceptors.add(
      HostAllowlistInterceptor(allowedHost: 'dry-run-tutor.dryrun-app.workers.dev'),
    );
    // No transport is configured, so any request that gets past the
    // allowlist would fail on a real socket call rather than silently
    // succeed — the test only needs to prove the allowlist throws first.
  });

  test('a request to the configured relay host is passed through', () async {
    dio.httpClientAdapter = _StubAdapter();
    final Response<dynamic> response = await dio.get<dynamic>('/v1/config');
    expect(response.statusCode, 200);
  });

  test('a request to api.groq.com throws rather than dialling', () async {
    await expectLater(
      dio.get<dynamic>('https://api.groq.com/openai/v1/chat/completions'),
      throwsA(
        isA<DioException>().having(
          (DioException e) => e.error,
          'error',
          isA<DisallowedHostException>(),
        ),
      ),
    );
  });

  test('a request to generativelanguage.googleapis.com throws', () async {
    await expectLater(
      dio.get<dynamic>('https://generativelanguage.googleapis.com/v1/models'),
      throwsA(isA<DioException>()),
    );
  });

  test('a request to api.example.com throws', () async {
    await expectLater(
      dio.get<dynamic>('https://api.example.com/v1/config'),
      throwsA(isA<DioException>()),
    );
  });
}

/// A minimal adapter that never touches a real socket — the allowlist
/// test only needs to prove the *allowed* host reaches the transport
/// layer at all, not that the transport layer works.
class _StubAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: <String>['application/json'],
    });
  }
}
