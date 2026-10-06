// contracts/worker-api.md §GET /v1/daily. Pure: which problem is "today's"
// for a UTC date. Moved server-side from the app's DailyRepositoryImpl so the
// operator's levers (kill switch, rotation pointer, dated problems) apply
// without a release, and the app no longer downloads the whole catalogue.
import { PRACTICE_COLLECTION } from "./content";
import type { RuntimeConfig } from "./runtime-config";
import type { PublicHalf } from "../../../tools/problem-types";

/** Whole UTC days since the epoch for a YYYY-MM-DD string; NaN if unparseable. */
export function dayNumber(date: string): number {
  return Math.floor(Date.parse(`${date}T00:00:00Z`) / 86_400_000);
}

/**
 * 1. a dated problem for exactly `date` wins; 2. the operator's pointer over
 * the id-sorted undated pool; 3. else `dayNumber % pool`. Killed problems and
 * the warm-up are never picked. `null` when nothing is eligible.
 *
 * The pointer is a port of the app's former `_pointerPick`: an unknown start
 * id starts at the top of the pool, an unparseable anchor means no elapsed
 * days, and an anchor in the future clamps to zero.
 */
export function pickDaily(
  problems: readonly PublicHalf[],
  cfg: Pick<RuntimeConfig, "killed_problem_ids" | "rotation">,
  date: string,
): PublicHalf | null {
  const eligible = problems.filter(
    (p) => !cfg.killed_problem_ids.includes(p.id) && !(p.collections ?? []).includes(PRACTICE_COLLECTION),
  );

  const dated = eligible.find((p) => p.date === date);
  if (dated) return dated;

  const pool = eligible.filter((p) => p.date === undefined).sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  if (pool.length === 0) return null;

  const rotation = cfg.rotation;
  if (rotation) {
    const found = pool.findIndex((p) => p.id === rotation.start_problem_id);
    const startIndex = found < 0 ? 0 : found;
    let elapsed = dayNumber(date) - dayNumber(rotation.anchor_date);
    if (Number.isNaN(elapsed) || elapsed < 0) elapsed = 0;
    return pool[(startIndex + elapsed) % pool.length]!;
  }

  return pool[dayNumber(date) % pool.length]!;
}
