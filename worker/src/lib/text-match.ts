// Shared whole-word matching used by leak-filter.ts (§B1 containsBlockedTerm)
// and ground-truth.ts (§B3 learnerNamedTerms). Normalise to lowercase,
// replace every non-alphanumeric run with a single space, then match
// \b<term>\b on the normalised string — case- and punctuation-insensitive.

export function normalise(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/** `needle` must already be normalised. */
export function wholeWordMatch(haystack: string, needle: string): boolean {
  if (!needle) return false;
  return new RegExp(`\\b${escapeRegExp(needle)}\\b`).test(haystack);
}

/**
 * The "tight" (space-stripped) comparison FR-004a needs so "hashmap" names
 * the term "hash map" and vice versa. Once spaces are stripped there are no
 * word boundaries left inside the blob for `\b` to anchor on, so this is a
 * plain substring test on the space-stripped strings, not a whole-word match
 * — `wholeWordMatch` degenerates to (almost) never matching mid-string once
 * the haystack has no non-alphanumeric characters at all.
 */
export function tightMatch(haystack: string, needle: string): boolean {
  if (!needle) return false;
  return haystack.includes(needle);
}

/**
 * Optimal-string-alignment distance (Levenshtein plus adjacent swaps, so
 * "hashamp" is one edit from "hashmap"), or `max + 1` as soon as it is
 * clear the distance exceeds `max`.
 */
export function editDistance(a: string, b: string, max: number): number {
  if (Math.abs(a.length - b.length) > max) return max + 1;
  let prevPrev: number[] = [];
  let prev = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i++) {
    const row = [i];
    let rowMin = i;
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let d = Math.min(prev[j] + 1, row[j - 1] + 1, prev[j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d = Math.min(d, prevPrev[j - 2] + 1);
      }
      row.push(d);
      rowMin = Math.min(rowMin, d);
    }
    if (rowMin > max) return max + 1;
    prevPrev = prev;
    prev = row;
  }
  return prev[b.length];
}

/**
 * A typed word counts as a misspelling of `tightTerm` (normalised, spaces
 * stripped) when it shares the first letter and sits within 1 edit for a
 * 5-6 letter term, 2 edits for 7+. Shorter terms need exact spelling: at
 * 2 edits "map" would match "mad" and "cap". The budget is 1 below 7
 * letters because 2 edits takes "index" to "inner".
 */
export function isMisspelling(word: string, tightTerm: string): boolean {
  if (tightTerm.length < 5 || word === tightTerm || word[0] !== tightTerm[0]) return false;
  const max = tightTerm.length >= 7 ? 2 : 1;
  return editDistance(word, tightTerm, max) <= max;
}
