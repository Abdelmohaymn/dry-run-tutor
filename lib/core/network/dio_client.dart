import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

import '../config/relay.dart';
import 'host_allowlist_interceptor.dart';
import 'redacting_log_interceptor.dart';
import 'server_date_interceptor.dart';

/// The one `dio` instance the app is allowed to construct. Every relay
/// call — install, config, daily, practice, chat, judge, trial — goes
/// through this client, which is what makes "the app only talks to one
/// host" a property of the object graph rather than a habit (FR-004,
/// Principle VI).
///
/// The SC-011 / FR-004 capture check needs every request this client makes
/// to be observable at a proxy, and `dart:io`'s `HttpClient` — unlike the
/// platform HTTP stacks — ignores Android's system proxy setting entirely,
/// so setting one on the device captures nothing from this app. Passing
/// `--dart-define=CAPTURE_PROXY=host:port` routes this client, and only this
/// client, through that proxy. It is compiled out of release builds and
/// inert when the define is absent, which is every build but a capture run.
/// Profile builds honour it too: the SC-001/002/007 timings have to be taken
/// on an AOT build to mean anything, and SC-007 needs the relay made
/// unreachable for exactly this client while `adb` keeps its own connection.
const String _captureProxy = String.fromEnvironment('CAPTURE_PROXY');

/// [onServerDate] wires the trusted-time chain's tier two (research.md
/// R-003) without this file depending on `core/time` — the callback is
/// supplied by whoever assembles the client at the composition root.
Dio buildDioClient({
  required void Function(DateTime serverDate) onServerDate,
}) {
  final Uri base = Uri.parse(relayBaseUrl);
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: relayBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      // Deliberately longer than the relay's own per-provider timeout
      // (`worker/src/lib/provider-groq.ts`'s REQUEST_TIMEOUT_MS, 30s), and
      // with room for the pool to try a second member after the first one
      // times out. At exactly 30s the client always gave up a fraction of a
      // second BEFORE the relay's own error arrived, so a slow assessment
      // reached the learner as "No connection right now" — told they were
      // offline while plainly online (found on a physical device). A
      // timeout that is not longer than the server's cannot report the
      // server's answer.
      receiveTimeout: const Duration(seconds: 75),
      sendTimeout: const Duration(seconds: 10),
      headers: const <String, String>{'Content-Type': 'application/json'},
    ),
  );

  // Order matters: the allowlist must run first so a disallowed host is
  // rejected before anything else — including logging, which would
  // otherwise dial-adjacent code paths never meant to run — touches it.
  if (!kReleaseMode && _captureProxy.isNotEmpty) {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        // Parenthesised deliberately: without it the `..` below binds as a
        // cascade on the returned String, not on the HttpClient.
        ..findProxy = ((Uri uri) => 'PROXY $_captureProxy')
        // The proxy re-signs with its own CA. `dart:io` carries its own
        // BoringSSL trust store and never consults Android's, so this
        // callback — not a `network_security_config` — is the only thing
        // that has to accept it, and it is unreachable without the define.
        ..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
    );
  }

  dio.interceptors.add(HostAllowlistInterceptor(allowedHost: base.host));
  dio.interceptors.add(ServerDateInterceptor(onServerDate: onServerDate));
  dio.interceptors.add(RedactingLogInterceptor(enabled: kDebugMode));

  return dio;
}
