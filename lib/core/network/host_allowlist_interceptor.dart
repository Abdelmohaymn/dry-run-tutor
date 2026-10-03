import 'package:dio/dio.dart';

/// Rejects any request whose host is not the configured relay, **before it
/// reaches the socket** (FR-004, Principle VI).
///
/// This is the client half of the reason the relay exists at all: the app
/// must not be able to talk to a model provider directly, even by
/// accident — a typo'd base URL, a copy-pasted debug request, a future
/// contributor who does not know the rule. The check happens in
/// `onRequest`, ahead of dio's transport, so a disallowed host throws
/// instead of dialling. `test/security/host_allowlist_test.dart` is what
/// keeps this true.
class HostAllowlistInterceptor extends Interceptor {
  HostAllowlistInterceptor({required this.allowedHost});

  /// The one host this dio instance may ever reach — the relay's host for
  /// the current flavor.
  final String allowedHost;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    if (options.uri.host != allowedHost) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: DisallowedHostException(options.uri.host, allowedHost),
          message: 'Host "${options.uri.host}" is not the configured relay '
              '("$allowedHost"). Refusing to dial it.',
        ),
      );
      return;
    }
    handler.next(options);
  }
}

/// Thrown (wrapped in a [DioException]) when a request targets any host
/// other than the configured relay. The app speaks to exactly one host —
/// this exception is what makes that a mechanism rather than a promise.
class DisallowedHostException implements Exception {
  DisallowedHostException(this.requestedHost, this.allowedHost);

  final String requestedHost;
  final String allowedHost;

  @override
  String toString() =>
      'DisallowedHostException: "$requestedHost" is not the allowed relay host "$allowedHost"';
}
