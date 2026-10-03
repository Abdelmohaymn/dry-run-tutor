// data-model.md §B1. Sentence-boundary output filter. A leak is blocked by
// code, not requested in a prompt (FR-003, Constitution III).
import type { Problem } from "../../../tools/problem-types";
import { normalise, wholeWordMatch } from "./text-match";

const ABBREVIATIONS = ["e.g.", "i.e.", "etc.", "vs.", "dr."];

export type SessionEnded = "user" | "cap" | "solution" | null;

/**
 * FR-004a is drawn here, lexically: `learnerNamed` (§B3 learnerNamedTerms)
 * unblocks the WORDS the learner has themselves used, without marking the
 * insight reached.
 *
 * `sessionEnded` MUST come from `releaseSolution()` (turn-cap.ts) — NEVER
 * from the request payload. This branch stands down the only code-level
 * leak protection there is.
 */
export function buildBlockedTerms(
  problem: Problem,
  insightsAlreadyHit: ReadonlySet<string>,
  learnerNamed: ReadonlySet<string>,
  sessionEnded: SessionEnded,
): string[] {
  if (sessionEnded === "solution") return [];

  const terms = new Set<string>();
  for (const insight of problem.private.key_insights) {
    if (insightsAlreadyHit.has(insight.key)) continue;
    for (const term of insight.never_say) {
      const lower = term.toLowerCase();
      if (learnerNamed.has(lower)) continue;
      terms.add(lower);
    }
  }
  return [...terms];
}

export interface SentenceSplit {
  sentence: string;
  remainder: string;
}

/** Index spans (inclusive) covered by any abbreviation occurrence in `buffer` — every period inside "e.g." is protected, not just its last one. */
function abbreviationSpans(buffer: string): Array<[number, number]> {
  const lower = buffer.toLowerCase();
  const spans: Array<[number, number]> = [];
  for (const abbr of ABBREVIATIONS) {
    let idx = lower.indexOf(abbr);
    while (idx !== -1) {
      spans.push([idx, idx + abbr.length - 1]);
      idx = lower.indexOf(abbr, idx + 1);
    }
  }
  return spans;
}

/**
 * Splits on `.`, `?`, `!`, `\n` not preceded by a digit (decimal numbers)
 * and not part of a known abbreviation (e.g., i.e., etc., vs., Dr.). Returns
 * null when no complete sentence is available yet.
 */
export function takeCompleteSentence(buffer: string): SentenceSplit | null {
  const spans = abbreviationSpans(buffer);
  const insideAbbreviation = (i: number) => spans.some(([start, end]) => i >= start && i <= end);

  for (let i = 0; i < buffer.length; i++) {
    const ch = buffer[i];
    if (ch !== "." && ch !== "?" && ch !== "!" && ch !== "\n") continue;

    if (ch === ".") {
      const prevChar = buffer[i - 1];
      if (prevChar && /[0-9]/.test(prevChar)) continue; // e.g. "3.14"
      if (insideAbbreviation(i)) continue;
    }

    return { sentence: buffer.slice(0, i + 1), remainder: buffer.slice(i + 1) };
  }
  return null;
}

/**
 * Whole-word, case-insensitive, punctuation-insensitive, per §B1: normalise
 * to lowercase, replace non-alphanumerics with a single space, then match
 * \b<term>\b on the normalised string.
 */
export function containsBlockedTerm(text: string, blockedTerms: readonly string[]): boolean {
  const normalisedText = normalise(text);
  return blockedTerms.some((term) => wholeWordMatch(normalisedText, normalise(term)));
}

export interface StreamFilteredResult {
  leakBlocked: boolean;
}

/**
 * Emits one complete sentence at a time, aborting the upstream iterable the
 * instant a blocked term appears in a sentence. A blocked reply is NOT
 * refunded against the turn cap — the tutor answered; the filter suppressed
 * it. Never logs the offending sentence.
 */
export async function streamFiltered(
  upstream: AsyncIterable<string>,
  blockedTerms: readonly string[],
  emit: (sentence: string) => void | Promise<void>,
): Promise<StreamFilteredResult> {
  let buffer = "";

  for await (const delta of upstream) {
    buffer += delta;
    let taken = takeCompleteSentence(buffer);
    while (taken) {
      if (containsBlockedTerm(taken.sentence, blockedTerms)) {
        return { leakBlocked: true }; // early return cancels `upstream` (see provider-groq.ts)
      }
      await emit(taken.sentence);
      buffer = taken.remainder;
      taken = takeCompleteSentence(buffer);
    }
  }

  if (buffer.trim() !== "") {
    if (containsBlockedTerm(buffer, blockedTerms)) {
      return { leakBlocked: true };
    }
    await emit(buffer);
  }
  return { leakBlocked: false };
}

/** Every blocked term that appears in `text`, whole-word as in §B1. */
export function blockedTermsIn(text: string, blockedTerms: readonly string[]): string[] {
  const normalisedText = normalise(text);
  return blockedTerms.filter((term) => wholeWordMatch(normalisedText, normalise(term)));
}

/**
 * The sentences of `text` before the first one holding a blocked term, or
 * all of `text` when none does. What streamFiltered() would have emitted.
 */
export function cleanLead(text: string, blockedTerms: readonly string[]): string {
  let lead = "";
  let rest = text;
  let taken = takeCompleteSentence(rest);
  while (taken) {
    if (containsBlockedTerm(taken.sentence, blockedTerms)) return lead;
    lead += taken.sentence;
    rest = taken.remainder;
    taken = takeCompleteSentence(rest);
  }
  if (rest.trim() !== "" && !containsBlockedTerm(rest, blockedTerms)) lead += rest;
  return lead;
}
