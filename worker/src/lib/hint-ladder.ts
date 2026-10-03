// data-model.md §B7. The learner pulls hints; the tutor does not push them.
// A flat sequence over key_insights in authored order, three rungs each,
// emitted verbatim and by code — no provider call, no paraphrase, no model
// in the path (FR-003a, FR-003b).
import type { Problem } from "../../../tools/problem-types";

export interface LadderRung {
  insightKey: string;
  text: string;
}

export const LADDER_EXHAUSTED = "LADDER_EXHAUSTED" as const;

/** Authored order: insight 0's three rungs, then insight 1's, and so on. */
export function flatLadder(problem: Problem): LadderRung[] {
  const ladder: LadderRung[] = [];
  for (const insight of problem.private.key_insights) {
    for (const rung of insight.hints) {
      ladder.push({ insightKey: insight.key, text: rung });
    }
  }
  return ladder;
}

/** 1-based, from turn-cap.ts §B2.4's `hints_revealed`. */
export function nextHint(problem: Problem, hintsRevealed: number): LadderRung | typeof LADDER_EXHAUSTED {
  const ladder = flatLadder(problem);
  if (hintsRevealed > ladder.length) return LADDER_EXHAUSTED;
  return ladder[hintsRevealed - 1];
}
