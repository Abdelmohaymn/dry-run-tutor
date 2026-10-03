import { describe, expect, it } from "vitest";
import { redact } from "../../src/lib/redact";

// FR-023, FR-024, SC-006: a known key string must appear ZERO times across
// every shape redact() is required to scrub — the error envelope, a captured
// log line, a D1 row, and the SSE error frame. This is the test written
// before any relay code exists (error-catalog.md §Redaction obligation).

const KNOWN_KEY = "gsk_abcdefghijklmnopqrstuvwxyz012345";
const KNOWN_OPENAI_STYLE_KEY = "sk-abcdefghijklmnopqrstuvwxyz012345";

function assertKeyAbsent(serialised: string) {
  expect(serialised).not.toContain(KNOWN_KEY);
  expect(serialised).not.toContain(KNOWN_OPENAI_STYLE_KEY);
}

describe("redact()", () => {
  it("scrubs the X-User-Key header value regardless of casing", () => {
    const headers = new Headers({
      "X-User-Key": KNOWN_KEY,
      "content-type": "application/json",
    });
    const result = redact(headers) as unknown as Record<string, string>;
    expect(result["x-user-key"]).toBe("[REDACTED]");
    assertKeyAbsent(JSON.stringify(result));
  });


  it("scrubs any Authorization header value", () => {
    const headers = new Headers({ Authorization: `Bearer ${KNOWN_KEY}` });
    const result = redact(headers) as unknown as Record<string, string>;
    assertKeyAbsent(JSON.stringify(result));
  });

  it("scrubs a gsk_ key embedded anywhere in a string, not just under a known key name", () => {
    const message = `upstream said: invalid key ${KNOWN_KEY} for this request`;
    assertKeyAbsent(redact(message));
  });

  it("scrubs an sk- style key embedded anywhere in a string", () => {
    const message = `upstream said: invalid key ${KNOWN_OPENAI_STYLE_KEY} for this request`;
    assertKeyAbsent(redact(message));
  });

  it("scrubs the key from an error envelope (contracts/error-catalog.md §Envelope)", () => {
    const envelope = {
      error: {
        code: "INVALID_KEY",
        message: `provider rejected ${KNOWN_KEY}`,
        retryable: false,
      },
    };
    assertKeyAbsent(JSON.stringify(redact(envelope)));
  });

  it("scrubs the key from a captured log line shape", () => {
    const logLine = {
      level: "error",
      msg: "provider call failed",
      headers: { "x-user-key": KNOWN_KEY, "content-type": "application/json" },
      context: { install_id: "abc", raw: `key was ${KNOWN_KEY}` },
    };
    assertKeyAbsent(JSON.stringify(redact(logLine)));
  });

  it("scrubs the key from a D1 row shape written during a request", () => {
    const row = {
      install_id: "abc123",
      date: "2026-08-20",
      endpoint: "chat",
      model: "openai/gpt-oss-120b",
      provider: "groq",
      // A row must never legitimately carry a key, but redact() is the
      // backstop if a bug ever put one in a free-text-shaped column.
      debug_note: `served with ${KNOWN_KEY}`,
    };
    assertKeyAbsent(JSON.stringify(redact(row)));
  });

  it("scrubs the key from an SSE error frame", () => {
    const frame = `event: error\ndata: ${JSON.stringify({
      error: { code: "UNCLEAR_RETRY", message: `upstream body: ${KNOWN_KEY}`, retryable: true },
    })}\n\n`;
    assertKeyAbsent(redact(frame));
  });

  it("leaves non-sensitive content untouched", () => {
    const envelope = { error: { code: "BAD_REQUEST", message: "invalid problem_id", retryable: false } };
    expect(redact(envelope)).toEqual(envelope);
  });

  it("redacts nested arrays and objects", () => {
    const nested = { items: [{ headers: { authorization: `Bearer ${KNOWN_KEY}` } }] };
    assertKeyAbsent(JSON.stringify(redact(nested)));
  });
});
