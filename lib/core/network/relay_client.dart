import 'dart:convert';

import 'package:dio/dio.dart';

import '../errors/relay_error.dart';
import '../errors/relay_error_mapper.dart';
import 'dto/chat_dto.dart';
import 'dto/config_dto.dart';
import 'dto/error_dto.dart';
import 'dto/event_dto.dart';
import 'dto/install_dto.dart';
import 'dto/judge_dto.dart';
import 'dto/problem_dto.dart';
import 'dto/repair_dto.dart';
import 'sse_parser.dart';

/// Thrown by every [RelayClient] method that fails. Repository
/// implementations catch this and wrap it in a `Result.Err` — this class
/// is `core/network`'s boundary, not the domain's; nothing above the data
/// layer should ever catch a [RelayException] directly.
class RelayException implements Exception {
  const RelayException(this.error);

  final RelayError error;

  @override
  String toString() => 'RelayException($error)';
}

/// The response to `GET /v1/config`: the parsed, restricted projection
/// plus the raw body (for verbatim caching, FR-046) and the `ETag` (so a
/// later revision can conditionally revalidate).
class ConfigResponse {
  const ConfigResponse({required this.parsed, required this.rawJson, this.etag});

  final ConfigDto parsed;
  final String rawJson;
  final String? etag;
}

/// The eight relay calls, with the header rules from
/// contracts/relay-client.md applied once here rather than left to every
/// caller to remember:
///
/// | Header | Sent on |
/// |---|---|
/// | `X-Install-Id` | every call except `/v1/config` and the manifest |
/// | `X-User-Key` | `/v1/chat`, `/v1/judge`, `/v1/repair` only — never `/v1/trial` |
/// | `X-Provider` | `/v1/chat`, `/v1/judge`, `/v1/repair` only — never `/v1/trial` |
///
/// This class only ever throws [RelayException] (built from
/// `mapErrorEnvelope` — the one code path for a non-2xx body and an SSE
/// `error` frame, research.md R-004) or lets a [MissingMetaFailure]
/// propagate unconverted, because turning that into `UNCLEAR_RETRY` is the
/// session Cubit's decision (research.md R-004 rule 2), not this layer's.
class RelayClient {
  RelayClient(this._dio);

  final Dio _dio;

  /// `POST /v1/install`. Called exactly once, at first launch. Sends no
  /// `X-Install-Id` — this call is what mints it.
  Future<InstallResponseDto> install(String installUuid) async {
    final Map<String, Object?> body = await _postJson(
      '/v1/install',
      InstallRequestDto(installUuid: installUuid).toJson(),
      headers: const <String, String>{},
    );
    return InstallResponseDto.fromJson(body);
  }

  /// `GET /v1/config`. No `X-Install-Id` — config gates launch before an
  /// install id may even exist yet.
  Future<ConfigResponse> config() async {
    try {
      final Response<String> response = await _dio.get<String>(
        '/v1/config',
        options: Options(responseType: ResponseType.plain),
      );
      final String raw = response.data ?? '{}';
      return ConfigResponse(
        parsed: ConfigDto.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        rawJson: raw,
        etag: response.headers.value('etag'),
      );
    } on DioException catch (e) {
      throw RelayException(_mapTransportOrEnvelope(e, requestProblemId: '', callKind: RelayCallKind.chat));
    }
  }

  /// `GET /v1/content/manifest.json` (or `config.contentManifestUrl` if
  /// the caller resolved a different path from config — the host is
  /// still enforced by [HostAllowlistInterceptor] either way). No
  /// `X-Install-Id`.
  Future<ManifestDto> manifest({String path = '/v1/content/manifest.json'}) async {
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(path);
      return ManifestDto.fromJson(response.data!);
    } on DioException catch (e) {
      throw RelayException(_mapTransportOrEnvelope(e, requestProblemId: '', callKind: RelayCallKind.chat));
    }
  }

  /// `POST /v1/chat` — the streamed turn. `X-User-Key` and `X-Provider`
  /// are sent when [userKey]/[providerId] are supplied (the keyed path);
  /// omit both for a trial call by calling [trialChat] instead.
  Stream<SseFrame> chat({
    required String installId,
    required ChatRequestDto request,
    String? userKey,
    String? providerId,
  }) {
    return _streamedTurn(
      '/v1/chat',
      request.toJson(),
      installId: installId,
      userKey: userKey,
      providerId: providerId,
    );
  }

  /// `POST /v1/judge` — one assessment, once. Same key/provider rule as
  /// [chat].
  Future<AssessmentDto> judge({
    required String installId,
    required JudgeRequestDto request,
    String? userKey,
    String? providerId,
  }) async {
    final Map<String, Object?> body = await _postJson(
      '/v1/judge',
      request.toJson(),
      headers: _headers(installId: installId, userKey: userKey, providerId: providerId),
      requestProblemId: request.problemId,
      callKind: RelayCallKind.judge,
    );
    return AssessmentDto.fromJson(body);
  }

  /// `POST /v1/repair` — transcript correction on the learner's own key.
  /// Reserves no turn. `X-User-Key` is REQUIRED by the relay; there is no
  /// trial path (research.md R-009).
  Future<RepairResponseDto> repair({
    required String installId,
    required RepairRequestDto request,
    required String userKey,
    String? providerId,
  }) async {
    final Map<String, Object?> body = await _postJson(
      '/v1/repair',
      request.toJson(),
      headers: _headers(installId: installId, userKey: userKey, providerId: providerId),
      requestProblemId: request.problemId,
    );
    return RepairResponseDto.fromJson(body);
  }

  /// `POST /v1/trial`, mode=chat. **Never** sends `X-User-Key` or
  /// `X-Provider` — this path spends the operator's credential
  /// (contracts/relay-client.md).
  Stream<SseFrame> trialChat({required String installId, required ChatRequestDto request}) {
    final Map<String, Object?> body = <String, Object?>{...request.toJson(), 'mode': 'chat'};
    return _streamedTurn('/v1/trial', body, installId: installId);
  }

  /// `POST /v1/trial`, mode=judge.
  Future<AssessmentDto> trialJudge({
    required String installId,
    required JudgeRequestDto request,
  }) async {
    final Map<String, Object?> body = <String, Object?>{...request.toJson(), 'mode': 'judge'};
    final Map<String, Object?> response = await _postJson(
      '/v1/trial',
      body,
      headers: _headers(installId: installId),
      requestProblemId: request.problemId,
      callKind: RelayCallKind.judge,
    );
    return AssessmentDto.fromJson(response);
  }

  /// `POST /v1/event`. Fire-and-forget from the caller's point of view —
  /// `AnalyticsClient` is what guarantees a failure here never surfaces
  /// (FR-051); this method still throws on failure so the drain loop
  /// knows to retry.
  Future<void> sendEvents({required String installId, required EventBatchDto batch}) async {
    await _postJson(
      '/v1/event',
      batch.toJson(),
      headers: _headers(installId: installId),
    );
  }

  // --- internals ---------------------------------------------------

  Map<String, String> _headers({String? installId, String? userKey, String? providerId}) {
    final Map<String, String> headers = <String, String>{};
    if (installId != null) {
      headers['X-Install-Id'] = installId;
    }
    if (userKey != null) {
      headers['X-User-Key'] = userKey;
    }
    if (providerId != null) {
      headers['X-Provider'] = providerId;
    }
    return headers;
  }

  Future<Map<String, Object?>> _postJson(
    String path,
    Object? data, {
    Map<String, String> headers = const <String, String>{},
    String requestProblemId = '',
    RelayCallKind callKind = RelayCallKind.chat,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio.post<Map<String, dynamic>>(
        path,
        data: data,
        options: Options(headers: headers),
      );
      return response.data ?? const <String, Object?>{};
    } on DioException catch (e) {
      throw RelayException(
        _mapTransportOrEnvelope(e, requestProblemId: requestProblemId, callKind: callKind),
      );
    }
  }

  Stream<SseFrame> _streamedTurn(
    String path,
    Object? data, {
    required String installId,
    String? userKey,
    String? providerId,
  }) async* {
    final Response<ResponseBody> response = await _dio.post<ResponseBody>(
      path,
      data: data,
      options: Options(
        responseType: ResponseType.stream,
        headers: <String, String>{
          ..._headers(installId: installId, userKey: userKey, providerId: providerId),
          'Accept': 'text/event-stream',
        },
        // Status is never the success signal here (research.md R-004) —
        // both a pre-stream JSON failure and a 200 that opens a stream
        // are read, never thrown by dio itself.
        validateStatus: (int? status) => true,
      ),
    );

    final ResponseBody body = response.data!;
    final String contentType = (body.headers['content-type'] ?? const <String>[]).join(';');
    final String requestProblemId = data is Map<String, Object?>
        ? (data['problem_id'] as String? ?? '')
        : '';

    if (!contentType.contains('text/event-stream')) {
      // A pre-stream failure: the whole body is one JSON error envelope,
      // never SSE-framed (contracts/relay-client.md).
      final List<int> bytes = await body.stream.expand((List<int> chunk) => chunk).toList();
      final Map<String, Object?> json =
          bytes.isEmpty ? const <String, Object?>{} : jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      throw RelayException(
        mapErrorEnvelope(json, requestProblemId: requestProblemId, callKind: RelayCallKind.chat),
      );
    }

    await for (final SseFrame frame in SseParser.parse(body.stream)) {
      if (frame is ErrorFrame) {
        throw RelayException(
          mapErrorEnvelope(
            frame.rawJson,
            requestProblemId: requestProblemId,
            callKind: RelayCallKind.chat,
          ),
        );
      }
      yield frame;
    }
  }

  RelayError _mapTransportOrEnvelope(
    DioException e, {
    required String requestProblemId,
    required RelayCallKind callKind,
  }) {
    final Object? data = e.response?.data;
    if (data is Map) {
      return mapErrorEnvelope(
        Map<String, Object?>.from(data),
        requestProblemId: requestProblemId,
        callKind: callKind,
      );
    }
    if (data is String && data.isNotEmpty) {
      try {
        final Object? decoded = jsonDecode(data);
        if (decoded is Map) {
          return mapErrorEnvelope(
            Map<String, Object?>.from(decoded),
            requestProblemId: requestProblemId,
            callKind: callKind,
          );
        }
      } on FormatException {
        // Falls through to transport() below.
      }
    }
    // No parseable envelope reached us at all — the request never
    // reached the relay, or the relay's response was not JSON. This is
    // what puts a row in the outbox instead of a message on a screen.
    return const RelayError.transport();
  }
}

/// Re-exported so `dto/error_dto.dart`'s [ErrorDto] stays reachable from
/// call sites that want the typed envelope rather than a raw map (e.g. for
/// logging a redacted summary of a rejected batch).
typedef RelayErrorEnvelope = ErrorDto;
