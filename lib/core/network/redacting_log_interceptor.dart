import 'dart:developer' as developer;

import 'package:dio/dio.dart';

/// The client half of the worker's `redact.ts`. Every log line this
/// interceptor writes has `X-User-Key`, `Authorization`, and any
/// `gsk_`/`sk-`-prefixed token substring scrubbed first — the same three
/// obligations `test/security/no_key_leak_test.dart` (R-009) asserts hold
/// across every log line, analytics payload, and database row written
/// during a full session.
///
/// Logs only in debug builds (`kDebugMode`-gated by the caller wiring this
/// in), and even then never the raw headers or body — only a redacted
/// summary line. There is no "verbose mode" that bypasses this.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor({this.enabled = true});

  final bool enabled;

  static const List<String> _sensitiveHeaders = <String>[
    'x-user-key',
    'authorization',
  ];

  static final RegExp _tokenPattern = RegExp(r'(gsk_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9]{20,})');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      _log(
        '→ ${options.method} ${redact(options.uri.toString())} '
        'headers=${redactHeaders(options.headers)}',
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (enabled) {
      _log(
        '← ${response.statusCode} ${redact(response.requestOptions.uri.toString())}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      _log(
        '✗ ${err.requestOptions.method} '
        '${redact(err.requestOptions.uri.toString())} — '
        '${redact(err.message ?? err.type.name)}',
      );
    }
    handler.next(err);
  }

  void _log(String message) {
    developer.log(message, name: 'relay');
  }

  /// Scrubs any key-shaped substring out of [input]. Public so the SSE
  /// layer and any other logging call site can share exactly one
  /// implementation rather than reinventing the pattern.
  static String redact(String input) {
    return input.replaceAll(_tokenPattern, '<redacted>');
  }

  /// A header map safe to log: sensitive header values replaced outright,
  /// everything else passed through [redact] in case a key ever leaked
  /// into an unexpected header.
  static Map<String, String> redactHeaders(Map<String, dynamic> headers) {
    final Map<String, String> out = <String, String>{};
    for (final MapEntry<String, dynamic> entry in headers.entries) {
      if (_sensitiveHeaders.contains(entry.key.toLowerCase())) {
        out[entry.key] = '<redacted>';
      } else {
        out[entry.key] = redact(entry.value.toString());
      }
    }
    return out;
  }
}
