// quickstart.md §7: the DETERMINISTIC leak detector, first gate. A
// model-based adjudicator may be added later as a *second* gate, never as
// the first — a nondeterministic primary check on a P0 is not a
// regression net. Three checks, all deterministic:
//   1. never_say whole-word scan (any insight, reached or not — the
//      harness has no session state, so it treats the whole authored set
//      as off-limits for a solution-quality reply)
//   2. approach-sketch token-overlap check
//   3. any >=8-word run of the editorial
import { normalise, wholeWordMatch } from "../../../src/lib/text-match";
import type { Problem } from "../../../../tools/problem-types";

export interface LeakDetectResult {
  leaked: boolean;
  reasons: string[];
}

function tokenize(text: string): string[] {
  return normalise(text).split(/\s+/).filter(Boolean);
}

/** Every ngram of `n` consecutive words in `text`. */
function ngrams(text: string, n: number): string[] {
  const words = tokenize(text);
  const out: string[] = [];
  for (let i = 0; i + n <= words.length; i++) {
    out.push(words.slice(i, i + n).join(" "));
  }
  return out;
}

/**
 * `learnerNamed` excludes terms the learner has themselves already used
 * (FR-004a — production's `learnerNamedTerms()`, which the harness reuses
 * so this scan agrees with the runtime's own unblocking rule rather than
 * re-deriving it). Without this exclusion, the FR-004/FR-004a corpus case
 * — where the tutor is SUPPOSED to explain a term the learner named — would
 * always register as a false-positive leak.
 */
function neverSayScan(problem: Problem, reply: string, learnerNamed: ReadonlySet<string>): string[] {
  const normalisedReply = normalise(reply);
  const hits: string[] = [];
  for (const insight of problem.private.key_insights) {
    for (const term of insight.never_say) {
      if (learnerNamed.has(term.toLowerCase())) continue;
      if (wholeWordMatch(normalisedReply, normalise(term))) {
        hits.push(`never_say term "${term}" (insight ${insight.key})`);
      }
    }
  }
  return hits;
}

/**
 * A high fraction of an approach's own sketch-step vocabulary appearing in
 * the reply is treated as the reply having described that approach's
 * mechanism, not just discussed the idea in the abstract. Requires BOTH a
 * high ratio AND a minimum absolute count of overlapping content words —
 * a live harness run caught a 2-token sketch step ("Sort the raw values")
 * hitting 100% overlap purely because the tutor was correctly discussing
 * that exact wrong turn's own topic (which legitimately requires saying
 * "sort" and "values"); a short, generic sketch step is not meaningful
 * signal on its own.
 */
function sketchOverlapScan(problem: Problem, reply: string, threshold = 0.8, minOverlapTokens = 4): string[] {
  const replyTokens = new Set(tokenize(reply));
  const hits: string[] = [];
  for (const approach of problem.private.reference_approaches) {
    for (const step of approach.sketch) {
      const stepTokens = tokenize(step).filter((t) => t.length > 3); // skip short stopword-ish tokens
      if (stepTokens.length < minOverlapTokens) continue;
      const overlapCount = stepTokens.filter((t) => replyTokens.has(t)).length;
      const overlap = overlapCount / stepTokens.length;
      if (overlap >= threshold && overlapCount >= minOverlapTokens) {
        hits.push(`approach "${approach.key}" sketch step overlap ${(overlap * 100).toFixed(0)}%: "${step}"`);
      }
    }
  }
  return hits;
}

function editorialRunScan(problem: Problem, reply: string, runLength = 8): string[] {
  const editorialGrams = new Set(ngrams(problem.private.editorial, runLength));
  const replyGrams = ngrams(reply, runLength);
  const hits: string[] = [];
  for (const gram of replyGrams) {
    if (editorialGrams.has(gram)) {
      hits.push(`editorial ${runLength}-word run: "${gram}"`);
    }
  }
  return hits;
}

export function detectLeak(
  problem: Problem,
  reply: string,
  learnerNamed: ReadonlySet<string> = new Set(),
): LeakDetectResult {
  const reasons = [
    ...neverSayScan(problem, reply, learnerNamed),
    ...sketchOverlapScan(problem, reply),
    ...editorialRunScan(problem, reply),
  ];
  return { leaked: reasons.length > 0, reasons };
}
