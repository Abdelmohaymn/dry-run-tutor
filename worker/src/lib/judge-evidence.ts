// Judge prompt v5, docs/judge-evidence-issues.md. Decides which of the
// judge's claims the learner's own words actually back. The judge now
// quotes the words it relied on for the approach it matched and for each
// insight it credited; two checks run on those quotes:
//
//   1. Provenance, deterministic: the quote is in a LEARNER turn. Tutor
//      turns are never passed in, so a tutor that names an idea cannot earn
//      the learner credit for it.
//   2. Support, one extra structured call: does the quote state the idea, or
//      only name a technique? "nested loop" is a verbatim learner quote, so
//      provenance alone passes it (2026-10-11); only a meaning check does not.
//      The call sees the problem, each claimed idea and its quote, never the
//      conversation, the editorial, never_say, hints or wrong turns.
//
// Failure policy is finish-check.ts's: a provider error or an unreadable
// answer falls back to provenance only, so a hiccup never turns a good
// session into "unclear". Never throws. Quotes live in memory for one
// request: nothing here logs, stores or returns them.
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
  /** `approach:<key>` or `insight:<key>`. */
  id: string;
  kind: "APPROACH" | "INSIGHT";
  /** The authored text of the idea: an approach's name and sketch, an insight's text. */
  idea: string;
  quote: string;
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

/** Models sometimes copy the transcript's "user:" label into the quote. */
const LEADING_LABEL = /^\s*user\s*:\s*/i;
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
 * True if `quote` is the learner's own words. Each ellipsis-separated
 * fragment must match ONE learner turn (a quote spanning two turns is two
 * fragments), as a whole-word substring or, failing that, as a small
 * paraphrase (at least 80% of its tokens inside one same-sized window).
 */
export function quotedByLearner(quote: string, learnerTurns: readonly string[]): boolean {
  const fragments = quote
    .replace(LEADING_LABEL, "")
    .split(ELLIPSIS)
    .map(normaliseEvidence)
    .filter((f) => f.length > 0);
  if (fragments.length === 0) return false;
  const turns = learnerTurns.map(normaliseEvidence);
  return fragments.every((fragment) =>
    turns.some((turn) => ` ${turn} `.includes(` ${fragment} `) || tokenWindowMatch(fragment, turn)),
  );
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
    `  quote: "${c.quote.replace(/\s+/g, " ").trim()}"`,
  ]);
  return [`Problem: ${problem.public.title}`, problem.public.statement, "", "Claims:", ...lines].join("\n");
}

/** Provenance + support for one judge answer. Never throws. */
export async function gatherEvidence(
  raw: RawEvidence,
  learnerTurns: readonly string[],
  problem: Problem,
  call: EvidenceCall,
): Promise<Evidence> {
  const approach = problem.private.reference_approaches.find((a) => a.key === raw.matched_approach);
  const approachQuoted = !!approach && quotedByLearner(raw.approach_quote, learnerTurns);

  // First passing entry per authored key.
  const quoted = new Map<string, string>();
  const insightText = new Map(problem.private.key_insights.map((i) => [i.key, i.text]));
  for (const hit of raw.insights_hit) {
    if (insightText.has(hit.key) && !quoted.has(hit.key) && quotedByLearner(hit.quote, learnerTurns)) {
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
    });
  }
  for (const [key, quote] of quoted) {
    claims.push({ id: `insight:${key}`, kind: "INSIGHT", idea: insightText.get(key)!, quote: quote.replace(LEADING_LABEL, "") });
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
