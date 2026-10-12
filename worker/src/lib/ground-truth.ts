// data-model.md §B3. The chat ground-truth slice. Zero hint ladders and
// zero insight `text` are ever in this slice (FR-002, FR-003, FR-003d,
// FR-010), and since tutor prompt v7 no insight keys either: which
// insights the learner has stated comes from the progress check
// (finish-check.ts), and only the leak filter uses it.
import type { Approach, Problem, WrongTurn } from "../../../tools/problem-types";
import type { RuntimeConfig } from "./runtime-config";
import type { Turn } from "./schemas";
import { isMisspelling, normalise, tightMatch, wholeWordMatch } from "./text-match";
import { requiredKeysFor } from "./verdict-map";

function learnerTurns(messages: Turn[]): Turn[] {
  return messages.filter((m) => m.role === "user");
}

function allLearnerText(messages: Turn[]): string {
  return learnerTurns(messages)
    .map((m) => m.text)
    .join(" ");
}

function recentLearnerText(messages: Turn[], n: number): string {
  return learnerTurns(messages)
    .slice(-n)
    .map((m) => m.text)
    .join(" ");
}

// FIX, discovered via the live tutor harness (worker/test/harness/): a bare
// bag-of-words overlap treats a shared stopword ("is", "a", "the"...) the
// same as a shared content word. For a short insight text and a short
// learner turn, ONE incidental stopword match can be enough tokens to
// clear cfg.trim.narrow_margin on its own — e.g. "what is a hashmap
// actually?" against an insight text ending "...the answer IS positions"
// scored 0.267 (>= the 0.15 default margin) purely on "is", marking that
// insight falsely REACHED and turning off its never_say protection. This
// is data-model.md §B3's score() pseudocode taken literally; the
// pseudocode itself doesn't filter stopwords, and following it literally
// is what let this leak through — a live-model harness run against real
// content is what caught it, not the synthetic unit tests. score() now
// only narrows Tier B and spots repeated wrong turns; "reached" comes
// from the progress check (review F4).
const STOPWORDS = new Set([
  "a", "an", "the", "and", "or", "but", "if", "then", "so", "of", "to", "in",
  "on", "at", "by", "for", "with", "as", "is", "are", "was", "were", "be",
  "been", "being", "am", "it", "its", "this", "that", "these", "those",
  "not", "no", "do", "does", "did", "has", "have", "had", "you", "your",
  "i", "we", "he", "she", "they", "them", "what", "how", "why", "when",
  "actually", "just", "really", "like", "can", "could", "would", "should",
]);

function tokenSet(text: string): Set<string> {
  return new Set(normalise(text).split(/\s+/).filter((t) => t && !STOPWORDS.has(t)));
}

/** Length-normalised token overlap between `subjectText` and `learnerText`, over content words only (STOPWORDS excluded — see the comment above). */
export function score(subjectText: string, learnerText: string): number {
  const subjectTokens = tokenSet(subjectText);
  if (subjectTokens.size === 0) return 0;
  const learnerTokens = tokenSet(learnerText);
  let overlap = 0;
  for (const token of subjectTokens) {
    if (learnerTokens.has(token)) overlap += 1;
  }
  return overlap / Math.sqrt(subjectTokens.size);
}

function approachText(approach: Approach): string {
  return `${approach.key} ${approach.name} ${approach.sketch.join(" ")}`;
}

/** First letters of a multi-word term ("breadth-first search" -> "bfs"), else "". */
function initials(normTerm: string): string {
  const parts = normTerm.split(" ").filter(Boolean);
  return parts.length >= 2 ? parts.map((p) => p[0]).join("") : "";
}

/** The learner wrote `abbr` as a word, or spelled it out in single letters ("d.p."). */
function saidAbbreviation(words: string[], abbr: string): boolean {
  if (words.includes(abbr)) return true;
  for (let i = 0; i + abbr.length <= words.length; i++) {
    if (words.slice(i, i + abbr.length).every((w, j) => w === abbr[j])) return true;
  }
  return false;
}

/**
 * FR-004a. Naming a term is not having the idea. Unblocks WORDS the learner has themselves used,
 * never marks an insight reached.
 *
 * An abbreviation and its full form are one term, in both directions, across all insights
 * (2026-10-11, docs/tutor-focus-issues.md 1a): "dynamic programming" names "dp", and "DP" or
 * "d.p." names "dynamic programming". The reverse direction needs the abbreviation written as
 * a word, not found inside the space-stripped text, or "add pairs" would name it.
 */
export function learnerNamedTerms(problem: Problem, messages: Turn[]): Set<string> {
  const text = normalise(allLearnerText(messages));
  const tight = text.replace(/ /g, "");
  const words = text.split(" ").filter(Boolean);
  const named = new Set<string>();
  for (const insight of problem.private.key_insights) {
    // Tight forms and single words of every term named so far, so a
    // spelling variant ("hash map" for "hashmap") and a short term inside
    // a named phrase ("map" inside "hash map") are named with it.
    const namedTight = new Set<string>();
    const namedWords = new Set<string>();
    for (const term of insight.never_say) {
      const normTerm = normalise(term);
      const tightTerm = normTerm.replace(/ /g, "");
      if (
        wholeWordMatch(text, normTerm) ||
        tightMatch(tight, tightTerm) ||
        // One typed word against the whole term, never a run of words:
        // "as you do" must not name "as you go".
        words.some((word) => isMisspelling(word, tightTerm))
      ) {
        named.add(term.toLowerCase());
        namedTight.add(tightTerm);
        for (const w of normTerm.split(" ")) namedWords.add(w);
      }
    }
    for (const term of insight.never_say) {
      const normTerm = normalise(term);
      if (namedTight.has(normTerm.replace(/ /g, "")) || namedWords.has(normTerm)) {
        named.add(term.toLowerCase());
      }
    }
  }

  const terms = problem.private.key_insights.flatMap((i) => i.never_say);
  const namedInitials = new Set(
    terms.filter((t) => named.has(t.toLowerCase())).map((t) => initials(normalise(t))).filter(Boolean),
  );
  for (const term of terms) {
    const normTerm = normalise(term);
    if (normTerm.includes(" ")) {
      const abbr = initials(normTerm);
      if (terms.some((t) => normalise(t) === abbr) && saidAbbreviation(words, abbr)) named.add(term.toLowerCase());
    } else if (normTerm.length >= 2 && normTerm.length <= 5 && namedInitials.has(normTerm)) {
      named.add(term.toLowerCase());
    }
  }
  return named;
}

export function isRepeatedWrongTurn(wrongTurn: WrongTurn, messages: Turn[], cfg: RuntimeConfig): boolean {
  const subjectText = `${wrongTurn.key} ${wrongTurn.text}`;
  const hits = learnerTurns(messages).filter(
    (turn) => score(subjectText, turn.text) >= cfg.trim.narrow_margin,
  ).length;
  return hits >= 2;
}

export interface GroundTruthSlice {
  statement: string;
  constraints: string[];
  approaches: { key: string; name: string; verdict: Approach["verdict"] }[];
  wrongTurns: { key: string; text: string; counter_question: string }[];
  /** Tier B. Sketch of each narrowed family — never sent for a family the learner has not narrowed to. */
  sketches: { key: string; name: string; sketch: string[] }[];
  /** Tier B. failing_case of each REPEATED wrong turn only. */
  failingCases: string[];
}

/**
 * `tier`: "AB" (default) is the keyed-path slice, Tier A plus the narrowed
 * Tier B detail. "A" is the trial path's cheaper profile
 * (`cfg.trial.ground_truth_tier`) — Tier B is skipped entirely, not merely
 * narrowed differently (data-model.md §B8, T092a).
 */
export function selectSlice(
  problem: Problem,
  messages: Turn[],
  turnIndex: number,
  cfg: RuntimeConfig,
  tier: "A" | "AB" = "AB",
): GroundTruthSlice {
  const approaches = problem.private.reference_approaches.map((a) => ({
    key: a.key,
    name: a.name,
    verdict: a.verdict,
  }));

  const wrongTurns = problem.private.common_wrong_turns.map((w) => ({
    key: w.key,
    text: w.text,
    counter_question: w.counter_question,
  }));

  if (tier === "A") {
    return {
      statement: problem.public.statement,
      constraints: problem.public.constraints,
      approaches,
      wrongTurns,
      sketches: [],
      failingCases: [],
    };
  }

  const recentText = recentLearnerText(messages, 3);
  const ranked = [...problem.private.reference_approaches].sort(
    (a, b) => score(approachText(b), recentText) - score(approachText(a), recentText),
  );
  const topScore = score(approachText(ranked[0]), recentText);
  const secondScore = score(approachText(ranked[1]), recentText);
  const narrowed =
    turnIndex >= cfg.trim.narrow_after_turn && topScore - secondScore >= cfg.trim.narrow_margin;
  const families = narrowed ? ranked.slice(0, 1) : ranked.slice(0, 2);

  const sketches = families.map((f) => ({ key: f.key, name: f.name, sketch: f.sketch }));

  const failingCases = problem.private.common_wrong_turns
    .filter((w) => isRepeatedWrongTurn(w, messages, cfg))
    .map((w) => w.failing_case);

  return {
    statement: problem.public.statement,
    constraints: problem.public.constraints,
    approaches,
    wrongTurns,
    sketches,
    failingCases,
  };
}

/**
 * §B6a. The assessment's slice — full ground truth, a different job than
 * the chat slice (§B3): classify what was said against everything, once,
 * at the end. `hints` is NEVER here (the judge never needs a rung); `text`
 * on every insight IS here (it is what classification matches against).
 * `editorial` is NOT here — it is attached to the response after
 * post-processing, never sent to the provider (FR-022).
 */
export interface JudgeSlice {
  statement: string;
  constraints: string[];
  approaches: {
    key: string;
    name: string;
    sketch: string[];
    time: string;
    space: string;
    verdict: Approach["verdict"];
    /** The insight keys this approach needs for a pass (verdict-map.ts requiredKeysFor). */
    needs: string[];
  }[];
  insights: { key: string; text: string; required: boolean }[];
  wrongTurns: { key: string; text: string; why_it_fails: string; counter_question: string }[];
  edgeCases: string[];
}

export function judgeSlice(problem: Problem): JudgeSlice {
  return {
    statement: problem.public.statement,
    constraints: problem.public.constraints,
    approaches: problem.private.reference_approaches.map((a) => ({
      key: a.key,
      name: a.name,
      sketch: a.sketch,
      time: a.time,
      space: a.space,
      verdict: a.verdict,
      needs: [...requiredKeysFor(problem, a.key)],
    })),
    insights: problem.private.key_insights.map((i) => ({
      key: i.key,
      text: i.text,
      required: i.required,
    })),
    wrongTurns: problem.private.common_wrong_turns.map((w) => ({
      key: w.key,
      text: w.text,
      why_it_fails: w.why_it_fails,
      counter_question: w.counter_question,
    })),
    edgeCases: problem.private.edge_cases,
  };
}

/** Renders a JudgeSlice into the plain-text block substituted for {{GROUND_TRUTH}} in prompts/judge.ts. */
export function renderJudgeGroundTruth(slice: JudgeSlice): string {
  const lines: string[] = [];
  lines.push(`Problem statement: ${slice.statement}`);
  lines.push(`Constraints: ${slice.constraints.join("; ")}`);
  lines.push("");
  lines.push("Reference approaches:");
  for (const a of slice.approaches) {
    const needs = a.needs.length > 0 ? `needs insights: ${a.needs.join(", ")}` : "needs no key insight";
    lines.push(`- ${a.key} — ${a.name} (${a.verdict}, time ${a.time}, space ${a.space}; ${needs}):`);
    for (const step of a.sketch) lines.push(`  - ${step}`);
  }
  lines.push("");
  lines.push("Key insights:");
  for (const i of slice.insights) {
    lines.push(`- ${i.key} (${i.required ? "required" : "optional"}): ${i.text}`);
  }
  lines.push("");
  lines.push("Known wrong turns:");
  for (const w of slice.wrongTurns) {
    lines.push(`- ${w.key}: ${w.text} — why it fails: ${w.why_it_fails}`);
  }
  lines.push("");
  lines.push(`Edge cases: ${slice.edgeCases.join("; ")}`);
  return lines.join("\n");
}

/**
 * Renders a GroundTruthSlice into the plain-text block substituted for
 * {{GROUND_TRUTH}} in prompts/tutor.ts. The slice's SHAPE is fixed by §B3;
 * this serialisation into prose is an implementation choice the prompt
 * itself leaves open (there is no {{GROUND_TRUTH}} sub-template) — flagged
 * here for design review rather than treated as pinned-down by data-model.md.
 */
export function renderGroundTruth(slice: GroundTruthSlice): string {
  const lines: string[] = [];
  lines.push(`Problem statement: ${slice.statement}`);
  lines.push(`Constraints: ${slice.constraints.join("; ")}`);
  lines.push("");
  lines.push("Reference approaches (name and verdict only — no detail unless narrowed below):");
  for (const a of slice.approaches) lines.push(`- ${a.name} (${a.verdict})`);
  // No insight list. Told which authored insights were still open and to
  // steer by them, the tutor pulled learners on a valid unlisted approach
  // toward the reference one, describing it in plain words the leak filter
  // cannot catch (review F1, 2026-10-07). The tutor reads the conversation
  // itself.
  lines.push("");
  lines.push("Known wrong turns:");
  for (const w of slice.wrongTurns) {
    lines.push(`- ${w.text} — if raised for the first time, ask: "${w.counter_question}"`);
  }
  if (slice.sketches.length > 0) {
    lines.push("");
    lines.push("Narrowed approach detail (the family the learner's recent turns are closest to):");
    for (const s of slice.sketches) {
      lines.push(`- ${s.name}:`);
      for (const step of s.sketch) lines.push(`  - ${step}`);
    }
  }
  if (slice.failingCases.length > 0) {
    lines.push("");
    lines.push("The learner has repeated a wrong turn — offer this concrete failing case:");
    for (const failingCase of slice.failingCases) lines.push(`- ${failingCase}`);
  }
  return lines.join("\n");
}
