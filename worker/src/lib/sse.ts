// SSE frame writer for POST /v1/chat. Frames, in order: zero or more
// `token`, then exactly one `meta`, then `done`. An `error` frame may
// replace the tail at any point and carries the same envelope as a non-2xx
// body (contracts/openapi.yaml text/event-stream example). The low-level
// SSE wire format (event:/data: lines) is hono's; this module is the
// domain-specific frame shapes on top of it.
import type { SSEStreamingApi } from "hono/streaming";
import { buildEnvelope, type AppError } from "./errors";

export interface MetaFramePayload {
  /** From the D1 counter, never the payload (FR-010c). Unchanged across a hint pull. */
  turn_index: number;
  turns_remaining: number;
  /** Rungs spent so far. Monotonic (data-model.md §B2.4). */
  hints_revealed: number;
  /** Zero means the next pull returns the fixed ladder-exhausted line (FR-003e). */
  hints_remaining: number;
  /**
   * Feature 005: the learner has explained every required key insight, so
   * the app may offer to finish. Absent when no check ran this turn.
   */
  ready_to_finish?: boolean;
  /** Present only when this turn condensed history. */
  summary?: string | null;
  /**
   * Present exactly when `summary` is: how many of the request's leading
   * `messages` the new summary covers. The rest were kept verbatim and
   * must be sent again next turn.
   */
  summary_covers?: number;
  /** SERVER-DERIVED. "solution" is set by data-model.md §B2.2, never the caller. */
  session_ended: "user" | "cap" | "solution" | null;
  leak_blocked: boolean;
}

export async function writeToken(stream: SSEStreamingApi, text: string): Promise<void> {
  await stream.writeSSE({ event: "token", data: JSON.stringify({ text }) });
}

export async function writeMeta(stream: SSEStreamingApi, meta: MetaFramePayload): Promise<void> {
  await stream.writeSSE({ event: "meta", data: JSON.stringify(meta) });
}

export async function writeDone(stream: SSEStreamingApi): Promise<void> {
  await stream.writeSSE({ event: "done", data: JSON.stringify({}) });
}

/** Same envelope shape as a non-2xx JSON body (errors.ts buildEnvelope), routed through redact() there. */
export async function writeError(stream: SSEStreamingApi, error: AppError): Promise<void> {
  await stream.writeSSE({ event: "error", data: JSON.stringify(buildEnvelope(error)) });
}
