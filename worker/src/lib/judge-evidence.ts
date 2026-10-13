// Judge prompt v5, docs/judge-evidence-issues.md. Decides which of the
// judge's claims the learner's own words actually back. The judge now
// quotes the words it relied on for the approach it matched and for each
// insight it credited; two checks run on those quotes:
//
//   1. Provenance, deterministic: the quote is in a LEARNER turn. A tutor
//      that names an idea cannot earn the learner credit for it.
//   2. Support, one extra structured call: does the quote state the idea, or
//      only name a technique? "nested loop" is a verbatim learner quote, so
//      provenance alone passes it (2026-10-11); only a meaning check does not.
//      The call sees the problem, each claimed idea and its quote, plus the
//      one tutor turn before each quoted learner turn, to read a short answer
//      in context, never as the learner's words (2026-10-12, PLAN_06: "2
//      pointers" answering "how would you check one word?"). It never sees
//      the rest of the conversation, the editorial, never_say, hints or wrong
//      turns.
//
// The same check also verifies the progress check's insights before the judge
// model sees them (2026-10-13, PLAN_08 D5, `verifySettled`). Tutor text now
// reaches it in one place: an `ASSISTED` claim quotes the tutor line the
// learner is said to have accepted, and the check decides only whether that
// line states the idea. "What could you do to avoid examining all those
// pairs?" states nothing, which is how "nested loop" plus an open question
// stopped crediting "complement lookup, with a nudge".
//
// Failure policy is finish-check.ts's: a provider error or an unreadable
// answer falls back to provenance only, so a hiccup never turns a good
// session into "unclear". Never throws. Quotes live in memory for one
// request: nothing here logs, stores or returns them, or the tutor question.
import { EVIDENCE_CHECK_PROMPT } from "../prompts/evidence-check";
import type { StructuredCompletionResult } from "./provider";
import type { Problem } from "../../../tools/problem-types";

export type EvidenceCall = (
  systemPrompt: string,
  userContent: string,
  jsonSchema: { name: string; schema: Record<string, unknown> },
) => Promise<{ result: StructuredCompletionResult; providerId: string; model: string }>;

/** What postprocessJudge() needs. Absent = trust the model's own claims. */
export interface Evidence {
  approachSupported: boolean;
  supportedInsights: ReadonlySet<string>;
}

export interface EvidenceClaim {
  /** `approach:<key>`, `insight:<key>` or `assisted:<key>`. */
  id: string;
  kind: "APPROACH" | "INSIGHT" | "ASSISTED";
  /** The authored text of the idea: an approach's name and sketch, an insight's text. */
  idea: string;
  /** The learner's words, or for an ASSISTED claim the tutor line they accepted. */
  quote: string;
  /** The tutor turn just before the quoted learner turn (its tail), or null. Context only. */
  asked: string | null;
}

/** A plain string means "no tutor turn before it". */
export type LearnerTurn = string | { text: string; asked: string | null };

const textOf = (t: LearnerTurn): string => (typeof t === "string" ? t : t.text);
const askedOf = (t: LearnerTurn | undefined): string | null => (t === undefined || typeof t === "string" ? null : t.asked);

/** How much of the tutor turn the check sees: the question is almost always at the end. */
const ASKED_MAX_CHARS = 400;

/** Whitespace collapsed; the last `max` characters, cut so that no word starts half-way. */
function tailAtWord(text: string, max: number): string {
  const flat = text.replace(/\s+/g, " ").trim();
  if (flat.length <= max) return flat;
  const tail = flat.slice(flat.length - max);
  if (flat[flat.length - max - 1] === " ") return tail.trimStart();
  const space = tail.indexOf(" ");
  return space === -1 ? tail : tail.slice(space + 1);
}

/** One insight the progress check found, with the quotes that passed provenance (PLAN_08). */
export interface InsightEvidence {
  key: string;
  /** In a learner turn. Set = reached in their own words. */
  learnerQuote: string | null;
  /** In a tutor turn, accepted by the learner. Set without learnerQuote = assisted. */
  tutorQuote: string | null;
}

interface RawEvidence {
  approach_quote: string;
  matched_approach: string;
  insights_hit: { quote: string; key: string }[];
}

/**
 * Lowercase, NFKC, every run of non-letter/non-digit (Unicode) to one space.
 * Not text-match.ts's normalise(): that keeps only [a-z0-9] and would erase
 * an Arabic learner's words entirely. Combining marks stay with their letter.
 */
export function normaliseEvidence(text: string): string {
  return text
    .normalize("NFKC")
    .toLowerCase()
    .replace(/[^\p{L}\p{M}\p{N}]+/gu, " ")
    .trim();
}

/**
 * Models sometimes copy the transcript's "user:" label into the quote, and
 * since the progress check also quotes tutor lines (2026-10-13, PLAN_08), its
 * "tutor:" label.
 */
const LEADING_LABEL = /^\s*(?:user|tutor)\s*:\s*/i;
const ELLIPSIS = /\.\.\.|…/;

/** Share of a fragment's tokens that must sit in one same-sized window of a turn. */
const PARAPHRASE_SHARE = 0.8;

function tokenWindowMatch(fragment: string, turn: string): boolean {
  const need = fragment.split(" ");
  const have = turn.split(" ");
  const floor = Math.ceil(PARAPHRASE_SHARE * need.length);
  const last = Math.max(0, have.length - need.length);
  for (let start = 0; start <= last; start++) {
    const window = new Map<string, number>();
    for (const token of have.slice(start, start + need.length)) window.set(token, (window.get(token) ?? 0) + 1);
    let found = 0;
    for (const token of need) {
      const left = window.get(token) ?? 0;
      if (left > 0) {
        window.set(token, left - 1);
        found++;
      }
    }
    if (found >= floor) return true;
  }
  return false;
}

/**
 * Index of the learner turn holding the quote's first fragment, or -1 if the
 * quote is not the learner's own words. Each ellipsis-separated fragment must
 * match ONE learner turn (a quote spanning two turns is two fragments), as a
 * whole-word substring or, failing that, as a small paraphrase (at least 80%
 * of its tokens inside one same-sized window).
 */
export function quotedTurnIndex(quote: string, learnerTurns: readonly string[]): number {
  const fragments = quote
    .replace(LEADING_LABEL, "")
    .split(ELLIPSIS)
    .map(normaliseEvidence)
    .filter((f) => f.length > 0);
  if (fragments.length === 0) return -1;
  const turns = learnerTurns.map(normaliseEvidence);
  const turnOf = (fragment: string) =>
    turns.findIndex((turn) => ` ${turn} `.includes(` ${fragment} `) || tokenWindowMatch(fragment, turn));
  const indexes = fragments.map(turnOf);
  return indexes.every((i) => i >= 0) ? indexes[0] : -1;
}

/**
 * True if `quote` is the learner's own words. Each ellipsis-separated
 * fragment must match ONE learner turn (a quote spanning two turns is two
 * fragments), as a whole-word substring or, failing that, as a small
 * paraphrase (at least 80% of its tokens inside one same-sized window).
 */
export function quotedByLearner(quote: string, learnerTurns: readonly string[]): boolean {
  return quotedTurnIndex(quote, learnerTurns) >= 0;
}

/** Strict schema: one result per claim, `why` before `supported` so the reason is written first. */
export function evidenceCheckSchema(ids: string[]): { name: string; schema: Record<string, unknown> } {
  return {
    name: "evidence_check",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["results"],
      properties: {
        results: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["id", "why", "supported"],
            properties: {
              id: { type: "string", enum: ids },
              why: { type: "string" },
              supported: { type: "boolean" },
            },
          },
        },
      },
    },
  };
}

/** The user message: the problem, then each claimed idea with the words offered for it. */
export function buildEvidenceCheckInput(problem: Problem, claims: readonly EvidenceClaim[]): string {
  const lines = claims.flatMap((c) => [
    `- id: ${c.id}`,
    `  kind: ${c.kind}`,
    `  idea: ${c.idea}`,
    ...(c.asked === null ? [] : [`  asked: "${c.asked.replace(/\s+/g, " ").trim()}"`]),
    `  quote: "${c.quote.replace(/\s+/g, " ").trim()}"`,
  ]);
  return [`Problem: ${problem.public.title}`, problem.public.statement, "", "Claims:", ...lines].join("\n");
}

/**
 * The tail of the tutor turn before the learner turn that holds `quote`, or
 * null. Context for the support check only, never the learner's words.
 */
function askedFor(learnerTurns: readonly LearnerTurn[], quote: string): string | null {
  const asked = askedOf(learnerTurns[quotedTurnIndex(quote, learnerTurns.map(textOf))]);
  return asked === null ? null : tailAtWord(asked, ASKED_MAX_CHARS) || null;
}

/** Provenance + support for one judge answer. Never throws. */
export async function gatherEvidence(
  raw: RawEvidence,
  learnerTurns: readonly LearnerTurn[],
  problem: Problem,
  call: EvidenceCall,
): Promise<Evidence> {
  // Provenance reads the learner's text only; the tutor turn is context for
  // the support check and is never matched against a quote.
  const texts = learnerTurns.map(textOf);
  const approach = problem.private.reference_approaches.find((a) => a.key === raw.matched_approach);
  const approachQuoted = !!approach && quotedByLearner(raw.approach_quote, texts);

  // First passing entry per authored key.
  const quoted = new Map<string, string>();
  const insightText = new Map(problem.private.key_insights.map((i) => [i.key, i.text]));
  for (const hit of raw.insights_hit) {
    if (insightText.has(hit.key) && !quoted.has(hit.key) && quotedByLearner(hit.quote, texts)) {
      quoted.set(hit.key, hit.quote);
    }
  }

  // A `wrong` approach is never demoted (it could only raise the grade), so
  // provenance is all it needs and it is not sent.
  const claims: EvidenceClaim[] = [];
  if (approach && approachQuoted && approach.verdict !== "wrong") {
    claims.push({
      id: `approach:${approach.key}`,
      kind: "APPROACH",
      idea: `${approach.name}: ${approach.sketch.join("; ")}`,
      quote: raw.approach_quote.replace(LEADING_LABEL, ""),
      asked: askedFor(learnerTurns, raw.approach_quote),
    });
  }
  for (const [key, quote] of quoted) {
    claims.push({
      id: `insight:${key}`,
      kind: "INSIGHT",
      idea: insightText.get(key)!,
      quote: quote.replace(LEADING_LABEL, ""),
      asked: askedFor(learnerTurns, quote),
    });
  }

  if (claims.length === 0) return { approachSupported: approachQuoted, supportedInsights: new Set() };

  const provenanceOnly: Evidence = { approachSupported: approachQuoted, supportedInsights: new Set(quoted.keys()) };
  try {
    const { result } = await call(
      EVIDENCE_CHECK_PROMPT,
      buildEvidenceCheckInput(problem, claims),
      evidenceCheckSchema(claims.map((c) => c.id)),
    );
    const results = (result.json as { results?: unknown } | undefined)?.results;
    if (!Array.isArray(results)) return provenanceOnly;
    const supported = new Set<string>();
    for (const r of results as { id?: unknown; supported?: unknown }[]) {
      if (r && typeof r.id === "string" && r.supported === true) supported.add(r.id);
    }
    const approachSent = claims.some((c) => c.kind === "APPROACH");
    return {
      approachSupported: approachQuoted && (!approachSent || supported.has(`approach:${approach!.key}`)),
      supportedInsights: new Set([...quoted.keys()].filter((k) => supported.has(`insight:${k}`))),
    };
  } catch {
    return provenanceOnly;
  }
}

/**
 * The support check on the progress check's quotes (2026-10-13, PLAN_08 D5),
 * run before the judge model is called so it is shown verified lists only.
 * Per key: the learner's quote supported gives reached; else the tutor's
 * quote supported gives assisted; else the key is dropped. A provider error
 * or an unreadable answer falls back to the provenance-only lists, the same
 * policy as gatherEvidence. No evidence means no call. Never throws.
 */
export async function verifySettled(
  found: readonly InsightEvidence[],
  learnerTurns: readonly LearnerTurn[],
  problem: Problem,
  call: EvidenceCall,
): Promise<{ reached: string[]; assisted: string[] }> {
  const insightText = new Map(problem.private.key_insights.map((i) => [i.key, i.text]));
  const kept = new Map<string, InsightEvidence>();
  for (const e of found) {
    if (insightText.has(e.key) && !kept.has(e.key) && (e.learnerQuote !== null || e.tutorQuote !== null)) kept.set(e.key, e);
  }
  if (kept.size === 0) return { reached: [], assisted: [] };

  const claims: EvidenceClaim[] = [];
  for (const e of kept.values()) {
    if (e.learnerQuote !== null) {
      claims.push({
        id: `insight:${e.key}`,
        kind: "INSIGHT",
        idea: insightText.get(e.key)!,
        quote: e.learnerQuote.replace(LEADING_LABEL, ""),
        asked: askedFor(learnerTurns, e.learnerQuote),
      });
    }
    if (e.tutorQuote !== null) {
      claims.push({
        id: `assisted:${e.key}`,
        kind: "ASSISTED",
        idea: insightText.get(e.key)!,
        quote: e.tutorQuote.replace(LEADING_LABEL, ""),
        asked: null,
      });
    }
  }

  const keys = [...kept.keys()];
  const hasOwn = (k: string) => kept.get(k)!.learnerQuote !== null;
  const provenanceOnly = { reached: keys.filter(hasOwn), assisted: keys.filter((k) => !hasOwn(k)) };
  try {
    const { result } = await call(
      EVIDENCE_CHECK_PROMPT,
      buildEvidenceCheckInput(problem, claims),
      evidenceCheckSchema(claims.map((c) => c.id)),
    );
    const results = (result.json as { results?: unknown } | undefined)?.results;
    if (!Array.isArray(results)) return provenanceOnly;
    const supported = new Set<string>();
    for (const r of results as { id?: unknown; supported?: unknown }[]) {
      if (r && typeof r.id === "string" && r.supported === true) supported.add(r.id);
    }
    // Only a claim that was sent can count, whatever the answer lists.
    const reached = keys.filter((k) => hasOwn(k) && supported.has(`insight:${k}`));
    const assisted = keys.filter((k) => !reached.includes(k) && kept.get(k)!.tutorQuote !== null && supported.has(`assisted:${k}`));
    return { reached, assisted };
  } catch {
    return provenanceOnly;
  }
}
