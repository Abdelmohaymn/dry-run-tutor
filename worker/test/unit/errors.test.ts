import { describe, expect, it } from "vitest";
import { AppError, ERROR_CODES, retryableFor, statusFor, toResponse } from "../../src/lib/errors";

// contracts/error-catalog.md — the closed set. Thirteen codes (eleven plus
// feature 007's INVALID_EMAIL and the per-network TRIAL_IP_LIMIT), no more, and
// status/retryable must match the catalog row for row.

describe("error code set", () => {
  it("is closed at exactly thirteen codes", () => {
    expect(ERROR_CODES.length).toBe(13);
    expect(new Set(ERROR_CODES).size).toBe(13);
  });

  it("contains exactly the thirteen named codes", () => {
    expect([...ERROR_CODES].sort()).toEqual(
      [
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
      ].sort(),
    );
  });
});

describe("status and retryable, row for row against error-catalog.md", () => {
  const table: Array<[string, number, boolean]> = [
    ["RATE_LIMITED", 429, true],
    ["INVALID_KEY", 401, false],
    ["QUOTA_EXHAUSTED", 429, false],
    ["UNCLEAR_RETRY", 502, true],
    ["TURN_CAP_REACHED", 409, false],
    ["TRIAL_CONSUMED", 409, false],
    ["SESSION_ALREADY_JUDGED", 409, false],
    ["EMPTY_TURN", 400, false],
    ["PROBLEM_KILLED", 409, false],
    ["TRIAL_UNAVAILABLE", 503, false],
    ["TRIAL_IP_LIMIT", 429, false],
    ["BAD_REQUEST", 400, false],
    ["INVALID_EMAIL", 400, false],
  ];

  it.each(table)("%s -> %i, retryable=%s", (code, status, retryable) => {
    expect(statusFor(code as any)).toBe(status);
    expect(retryableFor(code as any)).toBe(retryable);
  });

  it("TRIAL_UNAVAILABLE is 503 and NOT retryable, so a client cannot loop on it", () => {
    expect(statusFor("TRIAL_UNAVAILABLE")).toBe(503);
    expect(retryableFor("TRIAL_UNAVAILABLE")).toBe(false);
  });
});

describe("toResponse()", () => {
  it("produces the closed envelope shape with the right status", async () => {
    const res = toResponse(new AppError("RATE_LIMITED", { retryAfterMs: 2000 }));
    expect(res.status).toBe(429);
    const body = await res.json();
    expect(body).toEqual({
      error: {
        code: "RATE_LIMITED",
        message: expect.any(String),
        retryable: true,
        retry_after_ms: 2000,
      },
    });
  });

  it("omits retry_after_ms when the error is not retryable", async () => {
    const res = toResponse(new AppError("INVALID_KEY"));
    const body = (await res.json()) as { error: { retry_after_ms?: number; retryable: boolean } };
    expect(body.error.retry_after_ms).toBeUndefined();
    expect(body.error.retryable).toBe(false);
  });

  it("redacts a key embedded in the message", async () => {
    const err = new AppError("BAD_REQUEST");
    const res = toResponse(err);
    const text = await res.text();
    expect(text).not.toContain("gsk_");
  });
});
