// Shared time helpers, matching `nowIso()` and `utcDate(now)` as referenced
// throughout data-model.md Part B, so every module computes "today" the
// same way.

export function nowIso(): string {
  return new Date().toISOString();
}

/** YYYY-MM-DD, UTC. */
export function utcDate(now: Date = new Date()): string {
  return now.toISOString().slice(0, 10);
}
