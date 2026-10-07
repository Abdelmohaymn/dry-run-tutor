// contracts/error-catalog.md — the closed set of sixteen error codes. Every
// non-2xx response from every route uses this envelope, and it is routed
// through redact() first: no provider error body, status line, or stack
// trace ever reaches the caller (FR-039, SC-011).
import { redact } from "./redact";

export const ERROR_CODES = [
  "RATE_LIMITED",
  "INVALID_KEY",
  "QUOTA_EXHAUSTED",
  "UNCLEAR_RETRY",
  "TURN_CAP_REACHED",
  "TRIAL_CONSUMED",
  "SESSION_ALREADY_JUDGED",
  "EMPTY_TURN",
  "PROBLEM_KILLED",
  "TRIAL_UNAVAILABLE",
  "TRIAL_IP_LIMIT",
  "BAD_REQUEST",
  "INVALID_EMAIL",
  "VOICE_UNAVAILABLE",
  "VOICE_EXHAUSTED",
  "VOICE_BUSY",
] as const;

export type ErrorCode = (typeof ERROR_CODES)[number];

interface ErrorSpec {
  status: number;
  retryable: boolean;
  message: string;
}

// One row per error-catalog.md. `message` is written by us and safe to show
// a learner as-is — never interpolated from an upstream response.
const ERROR_TABLE: Record<ErrorCode, ErrorSpec> = {
  RATE_LIMITED: {
    status: 429,
    retryable: true,
    message: "The provider is rate-limiting this key right now. Wait a moment and try again.",
  },
  INVALID_KEY: {
    status: 401,
    retryable: false,
    message: "This key was rejected by the provider. Re-enter your key to continue.",
  },
  QUOTA_EXHAUSTED: {
    status: 429,
    retryable: false,
    message: "Your provider's daily free allowance is spent for today. It resets on their schedule — no charge occurred.",
  },
  UNCLEAR_RETRY: {
    status: 502,
    retryable: true,
    message: "That call didn't come back cleanly. Try again.",
  },
  TURN_CAP_REACHED: {
    status: 409,
    retryable: false,
    message: "This session has reached its turn limit. End the session to get your assessment.",
  },
  TRIAL_CONSUMED: {
    status: 409,
    retryable: false,
    message: "The free taster has already been used on this install. Add your own key to keep going.",
  },
  SESSION_ALREADY_JUDGED: {
    status: 409,
    retryable: false,
    message: "This session has already been assessed. See the assessment you already have.",
  },
  EMPTY_TURN: {
    status: 400,
    retryable: false,
    message: "That turn was empty. Say a bit more and try again.",
  },
  PROBLEM_KILLED: {
    status: 409,
    retryable: false,
    message: "This problem was pulled. Try another daily problem.",
  },
  TRIAL_UNAVAILABLE: {
    status: 503,
    retryable: false,
    message: "The free taster is at capacity today — add your key and start now.",
  },
  TRIAL_IP_LIMIT: {
    status: 429,
    retryable: false,
    message: "Free sessions from this network are used up for today. Add your own key to keep going.",
  },
  BAD_REQUEST: {
    status: 400,
    retryable: false,
    message: "That request wasn't valid.",
  },
  INVALID_EMAIL: {
    status: 400,
    retryable: false,
    message: "That email address doesn't look right.",
  },
  VOICE_UNAVAILABLE: {
    status: 503,
    retryable: false,
    message: "Voice transcription isn't available right now. Your phone's own speech recognition will be used.",
  },
  VOICE_EXHAUSTED: {
    status: 429,
    retryable: false,
    message: "Today's voice allowance is used up. Your phone's own speech recognition will be used until midnight UTC.",
  },
  VOICE_BUSY: {
    status: 503,
    retryable: true,
    message: "Voice transcription hit a temporary problem. Send the same clip again.",
  },
};

export interface ErrorEnvelope {
  error: {
    code: ErrorCode;
    message: string;
    retryable: boolean;
    retry_after_ms?: number;
  };
}

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly status: number;
  readonly retryable: boolean;
  readonly retryAfterMs?: number;

  /**
   * The provider never answered at all — the request timed out, was
   * aborted, or the connection failed. Distinct from an upstream that
   * answered with an error status, which says something about the request
   * and would fail identically on any member. Only this flag routes
   * `runLeg()` on to the next pool member; it never reaches the wire.
   */
  readonly memberUnavailable: boolean;

  /**
   * The provider answered, but with a server error (5xx, e.g. Gemini's
   * "high demand" 503) or a 200 whose body was not the requested JSON.
   * Both say something about that provider right now, not about the
   * request, so `runLeg()` tries the next pool member, without cooling
   * this one down. Never reaches the wire.
   */
  readonly tryElsewhere: boolean;

  constructor(
    code: ErrorCode,
    opts?: { retryAfterMs?: number; memberUnavailable?: boolean; tryElsewhere?: boolean },
  ) {
    const spec = ERROR_TABLE[code];
    super(spec.message);
    this.code = code;
    this.status = spec.status;
    this.retryable = spec.retryable;
    // retry_after_ms is present only when retryable is true and a delay is known.
    this.retryAfterMs = spec.retryable ? opts?.retryAfterMs : undefined;
    this.memberUnavailable = opts?.memberUnavailable ?? false;
    this.tryElsewhere = opts?.tryElsewhere ?? false;
  }
}

export function statusFor(code: ErrorCode): number {
  return ERROR_TABLE[code].status;
}

export function retryableFor(code: ErrorCode): boolean {
  return ERROR_TABLE[code].retryable;
}

/** Builds the closed-envelope object, redacted, safe to serialise as-is. */
export function buildEnvelope(error: AppError): ErrorEnvelope {
  const envelope: ErrorEnvelope = {
    error: {
      code: error.code,
      message: error.message,
      retryable: error.retryable,
      ...(error.retryAfterMs !== undefined ? { retry_after_ms: error.retryAfterMs } : {}),
    },
  };
  return redact(envelope);
}

/** Every route's error path goes through this. Routes every envelope through redact(). */
export function toResponse(error: AppError): Response {
  const envelope = buildEnvelope(error);
  return new Response(JSON.stringify(envelope), {
    status: error.status,
    headers: { "content-type": "application/json" },
  });
}
