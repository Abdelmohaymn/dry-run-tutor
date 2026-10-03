import 'relay_error.dart';

/// Which endpoint produced the error envelope being mapped. Only
/// `SESSION_ALREADY_JUDGED` needs it — the catalogue raises the same wire
/// code for a repeat `/v1/judge` and for any further turn or hint pull
/// after a verdict, and the two need different [JudgedContext]s
/// (research.md R-012). `chat` covers `/v1/chat`, a hint pull (still a
/// `/v1/chat` call with `hint_requested: true`), and `/v1/trial`
/// mode=chat — what matters is which *kind* of endpoint raised the code,
/// not whether the path was trial or keyed.
enum RelayCallKind { chat, judge }

/// Parses the error envelope from feature 001's frozen catalogue into a
/// [RelayError].
///
/// **The one code path.** Both a non-2xx JSON body and an SSE `error`
/// frame's decoded `data:` payload carry the identical
/// `{"error": {"code", "message", "retryable", "retry_after_ms"?}}` shape
/// (001 `openapi.yaml#Error`), so both are parsed by this single function.
/// `contracts/relay-client.md` names this "never branch on HTTP status
/// alone" (research.md R-004) — there is deliberately no second mapping
/// function for the stream path.
///
/// [requestProblemId] and [callKind] are supplied by the caller because
/// neither is on the wire: `PROBLEM_KILLED`'s body carries no
/// `problem_id` (001 `openapi.yaml#Error` has no such field), and
/// `SESSION_ALREADY_JUDGED`'s two meanings are told apart only by which
/// endpoint raised it, not by anything in the body.
RelayError mapErrorEnvelope(
  Map<String, Object?> body, {
  required String requestProblemId,
  required RelayCallKind callKind,
}) {
  final Object? envelope = body['error'];
  if (envelope is! Map) {
    // Not a shape the 001 contract can produce. Treated as our own fault
    // rather than crashing on a malformed body — see BAD_REQUEST's copy,
    // "something on our side is wrong".
    return const RelayError.badRequest();
  }
  final Map<String, Object?> error = Map<String, Object?>.from(envelope);
  final String code = error['code'] as String? ?? '';

  return switch (code) {
    'RATE_LIMITED' => RelayError.rateLimited(retryAfter: _retryAfter(error)),
    'INVALID_KEY' => const RelayError.invalidKey(),
    'QUOTA_EXHAUSTED' => const RelayError.quotaExhausted(),
    'UNCLEAR_RETRY' => const RelayError.unclearRetry(),
    'TURN_CAP_REACHED' => const RelayError.turnCapReached(),
    'TRIAL_CONSUMED' => const RelayError.trialConsumed(),
    'SESSION_ALREADY_JUDGED' => RelayError.sessionAlreadyJudged(
        ctx: callKind == RelayCallKind.judge
            ? JudgedContext.repeatJudge
            : JudgedContext.turnAfterVerdict,
      ),
    'EMPTY_TURN' => const RelayError.emptyTurn(),
    'TRIAL_UNAVAILABLE' => const RelayError.trialUnavailable(),
    'PROBLEM_KILLED' => RelayError.problemKilled(problemId: requestProblemId),
    'BAD_REQUEST' => const RelayError.badRequest(),
    // The catalogue is closed at eleven codes; an unrecognised one is a
    // contract break on the relay's side, not a code the client invents a
    // meaning for. Bucketed as our own fault rather than surfaced raw —
    // "no raw string from the wire is ever shown" (contracts/error-copy.md).
    _ => const RelayError.badRequest(),
  };
}

/// A stream that ends without a `meta` frame — the app's whole state
/// channel never arrived. Treated as `UNCLEAR_RETRY` (research.md R-004
/// rule 2): keep the partial text, advance no counter, offer retry.
RelayError missingMetaAsRelayError() => const RelayError.unclearRetry();

Duration _retryAfter(Map<String, Object?> error) {
  final Object? ms = error['retry_after_ms'];
  if (ms is int) {
    return Duration(milliseconds: ms);
  }
  if (ms is double) {
    return Duration(milliseconds: ms.round());
  }
  // `retry_after_ms` is documented present whenever `retryable` is true
  // and a delay is known (001 error-catalog.md). If it is ever missing,
  // fall back to the worker's own base backoff rather than a zero wait
  // that would hammer a rate-limited endpoint.
  return const Duration(seconds: 2);
}
