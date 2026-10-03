// FIRST FILE WRITTEN. FR-024: key redaction must be implemented before any
// other relay behaviour ships. Every path that can produce output — error
// envelopes, console.error, D1 rows, the SSE error frame — passes its
// argument through redact() first (contracts/error-catalog.md §Redaction
// obligation).

const KEY_PATTERNS = [/gsk_[A-Za-z0-9]{20,}/g, /sk-[A-Za-z0-9]{20,}/g];
const REDACTED = "[REDACTED]";
const SENSITIVE_KEYS = new Set(["x-user-key", "authorization"]);

function redactString(value: string): string {
  let out = value;
  for (const pattern of KEY_PATTERNS) {
    out = out.replace(pattern, REDACTED);
  }
  return out;
}

function isSensitiveKey(key: string): boolean {
  return SENSITIVE_KEYS.has(key.toLowerCase());
}

function redactValue(value: unknown): unknown {
  if (typeof value === "string") {
    return redactString(value);
  }
  if (Array.isArray(value)) {
    return value.map(redactValue);
  }
  if (value instanceof Headers) {
    const out: Record<string, string> = {};
    for (const [key, headerValue] of value.entries()) {
      out[key] = isSensitiveKey(key) ? REDACTED : redactString(headerValue);
    }
    return out;
  }
  if (value !== null && typeof value === "object") {
    const out: Record<string, unknown> = {};
    for (const [key, entryValue] of Object.entries(value as Record<string, unknown>)) {
      out[key] = isSensitiveKey(key) ? REDACTED : redactValue(entryValue);
    }
    return out;
  }
  return value;
}

/**
 * Scrubs the X-User-Key header value, any
 * Authorization value, and any string matching gsk_[A-Za-z0-9]{20,} or
 * sk-[A-Za-z0-9]{20,} from any value before it is serialised. Safe to call on strings, plain objects,
 * arrays, and Headers instances.
 */
export function redact<T>(value: T): T {
  return redactValue(value) as T;
}
