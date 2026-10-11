// data-model.md §B2. Three counters, one table (`device_day`), one round
// trip each. All server state — none of it is ever read from the request
// body. `(device_hash, date, problem_id)` is the session identity.
import { AppError } from "./errors";
import { nowIso } from "./time";

const MAX_SOLUTION_REQUEST_INCREMENT = 1;

export interface TurnCounterKey {
  installId: string;
  problemId: string;
  date: string;
}

export interface ReserveTurnResult {
  turnIndex: number;
  solutionRequests: number;
  judgedAt: string | null;
  hintsRevealed: number;
  /** Insight keys the progress check found stated on earlier turns (finish-check.ts). */
  reachedKeys: string[];
}

function parseReachedKeys(raw: string | null | undefined): string[] {
  if (!raw) return [];
  try {
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed.filter((k): k is string => typeof k === "string") : [];
  } catch {
    return [];
  }
}

/**
 * §B2.1. Increments `turns` before the provider call, clamps
 * `solution_requests` to rise by at most one per accepted turn. Throws
 * TURN_CAP_REACHED once the (already-incremented) counter exceeds `cap`.
 */
export async function reserveTurn(
  db: D1Database,
  key: TurnCounterKey,
  cap: number,
  claimedSolutionRequests: number,
): Promise<ReserveTurnResult> {
  const row = await db
    .prepare(
      `INSERT INTO device_day (device_hash, problem_id, date, turns, solution_requests)
       VALUES (?1, ?2, ?3, 1, min(?4, ${MAX_SOLUTION_REQUEST_INCREMENT}))
       ON CONFLICT(device_hash, date, problem_id) DO UPDATE SET
         turns = device_day.turns + 1,
         solution_requests = max(
           device_day.solution_requests,
           min(?4, device_day.solution_requests + ${MAX_SOLUTION_REQUEST_INCREMENT})
         )
       RETURNING turns, solution_requests, judged_at, hints_revealed, reached_keys`,
    )
    .bind(key.installId, key.problemId, key.date, claimedSolutionRequests)
    .first<{
      turns: number;
      solution_requests: number;
      judged_at: string | null;
      hints_revealed: number;
      reached_keys: string | null;
    }>();

  if (!row) {
    throw new Error("reserveTurn: INSERT ... RETURNING produced no row");
  }
  if (row.turns > cap) {
    throw new AppError("TURN_CAP_REACHED");
  }
  return {
    turnIndex: row.turns,
    solutionRequests: row.solution_requests,
    judgedAt: row.judged_at,
    hintsRevealed: row.hints_revealed,
    reachedKeys: parseReachedKeys(row.reached_keys),
  };
}

/**
 * Stores the session's reached insight keys: the union of what earlier
 * turns found and what this turn's check found. Only ever grows — a word
 * the learner has earned is not taken back.
 */
export async function recordReachedKeys(
  db: D1Database,
  key: TurnCounterKey,
  earlier: readonly string[],
  found: readonly string[],
): Promise<void> {
  const union = [...new Set([...earlier, ...found])];
  if (union.length === earlier.length) return;
  await db
    .prepare(
      `UPDATE device_day SET reached_keys = ?4
       WHERE device_hash = ?1 AND problem_id = ?2 AND date = ?3`,
    )
    .bind(key.installId, key.problemId, key.date, JSON.stringify(union))
    .run();
}

/**
 * §B2.1a. Guarded on the exact index just taken — a no-op if a concurrent
 * request already moved the counter past it. `solution_requests` is NEVER
 * refunded. Call only when the caller received no tutor reply at all and
 * zero token frames were emitted.
 */
export async function refundTurn(db: D1Database, key: TurnCounterKey, turnIndex: number): Promise<void> {
  await db
    .prepare(
      `UPDATE device_day SET turns = turns - 1
       WHERE device_hash = ?1 AND problem_id = ?2 AND date = ?3 AND turns = ?4`,
    )
    .bind(key.installId, key.problemId, key.date, turnIndex)
    .run();
}

/**
 * §B2.2. Pure. Monotonic + rate-limited solution_requests (from
 * reserveTurn) makes a turn-1 release arithmetically unreachable.
 */
export function releaseSolution(turnIndex: number, solutionRequests: number): boolean {
  return turnIndex >= 2 && solutionRequests >= 2;
}

/**
 * §B2.3. UPSERT, not UPDATE — the row may not exist yet. Claimed before the
 * provider call. Throws SESSION_ALREADY_JUDGED only on a genuine repeat.
 */
export async function claimJudge(db: D1Database, key: TurnCounterKey): Promise<{ judgedAt: string }> {
  const ts = nowIso();
  const row = await db
    .prepare(
      `INSERT INTO device_day (device_hash, problem_id, date, turns, judged_at)
       VALUES (?1, ?2, ?3, 0, ?4)
       ON CONFLICT(device_hash, date, problem_id) DO UPDATE SET judged_at = ?4
         WHERE device_day.judged_at IS NULL
       RETURNING judged_at`,
    )
    .bind(key.installId, key.problemId, key.date, ts)
    .first<{ judged_at: string }>();

  if (!row) {
    throw new AppError("SESSION_ALREADY_JUDGED");
  }
  return { judgedAt: row.judged_at };
}

/**
 * Undoes claimJudge() when the assessment was never produced. Constitution
 * VIII: an assessment the provider never returned is not spent. The claim
 * exists to stop a SECOND judge running while the first is in flight
 * (FR-013a), not to burn the learner's one assessment on a provider fault —
 * without this, a retryable UNCLEAR_RETRY leaves every retry answering
 * SESSION_ALREADY_JUDGED, which is a dead end with no assessment ever.
 *
 * Guarded on the exact timestamp this caller wrote, so a concurrent claim
 * that legitimately won the row afterwards is never cleared.
 */
export async function releaseJudgeClaim(
  db: D1Database,
  key: TurnCounterKey,
  judgedAt: string,
): Promise<void> {
  await db
    .prepare(
      `UPDATE device_day SET judged_at = NULL
        WHERE device_hash = ?1 AND problem_id = ?2 AND date = ?3 AND judged_at = ?4`,
    )
    .bind(key.installId, key.problemId, key.date, judgedAt)
    .run();
}

/**
 * POST /v1/session/reset with reason "recover": clears a judge claim whose
 * verdict the app never received, without touching the turn counters.
 * Unlike releaseJudgeClaim() it is not guarded on a timestamp — the caller
 * is the app saying it holds no assessment for this session.
 */
export async function releaseLostJudgeClaim(db: D1Database, key: TurnCounterKey): Promise<void> {
  await db
    .prepare(
      `UPDATE device_day SET judged_at = NULL
        WHERE device_hash = ?1 AND problem_id = ?2 AND date = ?3`,
    )
    .bind(key.installId, key.problemId, key.date)
    .run();
}

/** §B2.3b. Called by /v1/chat on both the conversational and hint paths. */
export function assertNotJudged(judgedAt: string | null): void {
  if (judgedAt !== null) {
    throw new AppError("SESSION_ALREADY_JUDGED");
  }
}

export interface Counters {
  turns: number;
  solutionRequests: number;
  hintsRevealed: number;
  judgedAt: string | null;
}

/** §B2.3a. Pure read. Never advances anything. Zeroes when no row exists. */
export async function readCounters(db: D1Database, key: TurnCounterKey): Promise<Counters> {
  const row = await db
    .prepare(
      `SELECT turns, solution_requests, hints_revealed, judged_at FROM device_day
       WHERE device_hash = ?1 AND problem_id = ?2 AND date = ?3`,
    )
    .bind(key.installId, key.problemId, key.date)
    .first<{ turns: number; solution_requests: number; hints_revealed: number; judged_at: string | null }>();

  if (!row) {
    return { turns: 0, solutionRequests: 0, hintsRevealed: 0, judgedAt: null };
  }
  return {
    turns: row.turns,
    solutionRequests: row.solution_requests,
    hintsRevealed: row.hints_revealed,
    judgedAt: row.judged_at,
  };
}

/**
 * §B2.4. UPSERT, not UPDATE — the hint path runs before reserveTurn(), so
 * this may be the first write of the session. Monotonic, 1-based.
 */
export async function revealNextHint(db: D1Database, key: TurnCounterKey): Promise<number> {
  const row = await db
    .prepare(
      `INSERT INTO device_day (device_hash, problem_id, date, turns, hints_revealed)
       VALUES (?1, ?2, ?3, 0, 1)
       ON CONFLICT(device_hash, date, problem_id) DO UPDATE SET
         hints_revealed = device_day.hints_revealed + 1
       RETURNING hints_revealed`,
    )
    .bind(key.installId, key.problemId, key.date)
    .first<{ hints_revealed: number }>();

  if (!row) {
    throw new Error("revealNextHint: INSERT ... RETURNING produced no row");
  }
  return row.hints_revealed;
}
