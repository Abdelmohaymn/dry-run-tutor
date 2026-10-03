// data-model.md §B2. Three counters, one table (`turn_counter`), one round
// trip each. All server state — none of it is ever read from the request
// body. `(install_id, problem_id, date)` is the session identity.
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
      `INSERT INTO turn_counter (install_id, problem_id, date, turns, solution_requests)
       VALUES (?1, ?2, ?3, 1, min(?4, ${MAX_SOLUTION_REQUEST_INCREMENT}))
       ON CONFLICT(install_id, problem_id, date) DO UPDATE SET
         turns = turn_counter.turns + 1,
         solution_requests = max(
           turn_counter.solution_requests,
           min(?4, turn_counter.solution_requests + ${MAX_SOLUTION_REQUEST_INCREMENT})
         )
       RETURNING turns, solution_requests, judged_at, hints_revealed`,
    )
    .bind(key.installId, key.problemId, key.date, claimedSolutionRequests)
    .first<{ turns: number; solution_requests: number; judged_at: string | null; hints_revealed: number }>();

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
  };
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
      `UPDATE turn_counter SET turns = turns - 1
       WHERE install_id = ?1 AND problem_id = ?2 AND date = ?3 AND turns = ?4`,
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
      `INSERT INTO turn_counter (install_id, problem_id, date, turns, judged_at)
       VALUES (?1, ?2, ?3, 0, ?4)
       ON CONFLICT(install_id, problem_id, date) DO UPDATE SET judged_at = ?4
         WHERE turn_counter.judged_at IS NULL
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
      `UPDATE turn_counter SET judged_at = NULL
        WHERE install_id = ?1 AND problem_id = ?2 AND date = ?3 AND judged_at = ?4`,
    )
    .bind(key.installId, key.problemId, key.date, judgedAt)
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
      `SELECT turns, solution_requests, hints_revealed, judged_at FROM turn_counter
       WHERE install_id = ?1 AND problem_id = ?2 AND date = ?3`,
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
      `INSERT INTO turn_counter (install_id, problem_id, date, turns, hints_revealed)
       VALUES (?1, ?2, ?3, 0, 1)
       ON CONFLICT(install_id, problem_id, date) DO UPDATE SET
         hints_revealed = turn_counter.hints_revealed + 1
       RETURNING hints_revealed`,
    )
    .bind(key.installId, key.problemId, key.date)
    .first<{ hints_revealed: number }>();

  if (!row) {
    throw new Error("revealNextHint: INSERT ... RETURNING produced no row");
  }
  return row.hints_revealed;
}
