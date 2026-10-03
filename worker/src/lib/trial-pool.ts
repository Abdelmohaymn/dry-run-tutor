// data-model.md §B8. Only routes/trial.ts calls this. The keyed paths
// (/v1/chat, /v1/judge) never touch trial_budget and can never return
// TRIAL_UNAVAILABLE — the operator's allowance is fixed and shared by every
// new install, unlike a learner's own key.
import { AppError } from "./errors";
import type { RuntimeConfig } from "./runtime-config";
import type { ProviderCallOptions } from "./provider";

export const TRIAL_ESTIMATE_CHAT = 1600;
export const TRIAL_ESTIMATE_JUDGE = 5100;

export type TrialLeg = "chat" | "judge";

export interface TrialPoolMember {
  id: string;
  secret_binding: string;
  base_url: string;
  model: string;
  daily_token_budget: number;
  structured_output: boolean;
  enabled: boolean;
  cooldown_ms: number;
}

function estimateFor(leg: TrialLeg): number {
  return leg === "chat" ? TRIAL_ESTIMATE_CHAT : TRIAL_ESTIMATE_JUDGE;
}

/**
 * Eligible members, budget/cooldown filtered, in priority order. `chat`
 * deliberately burns the abundant (non-structured-output) budget first —
 * a stable PARTITION, not a sort, so pool array order (the operator's
 * priority) survives inside each group. `judge` restricts to
 * `structured_output: true` members and never falls back past that: a
 * silent fallback would defeat FR-014's structural guarantee.
 */
export async function selectMember(
  leg: TrialLeg,
  cfg: RuntimeConfig,
  db: D1Database,
  now: Date,
  exclude: ReadonlySet<string> = new Set(),
): Promise<TrialPoolMember | null> {
  const enabled = cfg.trial.pool.filter((m) => m.enabled && !exclude.has(m.id));
  const candidates =
    leg === "judge"
      ? enabled.filter((m) => m.structured_output)
      : [...enabled.filter((m) => !m.structured_output), ...enabled.filter((m) => m.structured_output)];

  const date = now.toISOString().slice(0, 10);
  for (const m of candidates) {
    const row = await db
      .prepare("SELECT tokens_spent, cooldown_until FROM trial_budget WHERE date = ?1 AND provider_id = ?2")
      .bind(date, m.id)
      .first<{ tokens_spent: number; cooldown_until: string | null }>();
    if (row) {
      if (row.tokens_spent >= m.daily_token_budget) continue;
      if (row.cooldown_until && new Date(row.cooldown_until) > now) continue;
    }
    return m;
  }
  return null;
}

async function reserveEstimate(db: D1Database, date: string, providerId: string, estimate: number): Promise<void> {
  await db
    .prepare(
      `INSERT INTO trial_budget (date, provider_id, tokens_spent)
       VALUES (?1, ?2, ?3)
       ON CONFLICT(date, provider_id) DO UPDATE SET tokens_spent = trial_budget.tokens_spent + ?3`,
    )
    .bind(date, providerId, estimate)
    .run();
}

/**
 * Replaces the reserved estimate with the provider's real usage figure.
 * Exported because for a streaming chat leg the actual token count is only
 * known once the SSE stream has fully drained, well after `runLeg()` has
 * returned — so the caller settles the budget itself instead of `runLeg()`
 * doing it eagerly with a not-yet-known actual.
 */
export async function settleTrialBudget(
  db: D1Database,
  now: Date,
  providerId: string,
  leg: TrialLeg,
  actual: number,
): Promise<void> {
  const date = now.toISOString().slice(0, 10);
  await db
    .prepare(
      `UPDATE trial_budget SET tokens_spent = tokens_spent - ?3 + ?4
       WHERE date = ?1 AND provider_id = ?2`,
    )
    .bind(date, providerId, estimateFor(leg), actual)
    .run();
}

/**
 * Undoes `reserveEstimate()` for a call that failed. The provider either
 * never answered or answered with nothing usable, so nothing is settled
 * later and the estimate would otherwise stay counted for the whole day
 * (docs/errors/2026-09-25-trial-judge-unclear-retry.md, bug 2).
 */
async function releaseEstimate(db: D1Database, date: string, providerId: string, estimate: number): Promise<void> {
  await db
    .prepare(
      `UPDATE trial_budget SET tokens_spent = MAX(tokens_spent - ?3, 0)
       WHERE date = ?1 AND provider_id = ?2`,
    )
    .bind(date, providerId, estimate)
    .run();
}

async function setCooldown(db: D1Database, date: string, providerId: string, cooldownUntil: string): Promise<void> {
  await db
    .prepare(
      `INSERT INTO trial_budget (date, provider_id, tokens_spent, cooldown_until)
       VALUES (?1, ?2, 0, ?3)
       ON CONFLICT(date, provider_id) DO UPDATE SET cooldown_until = ?3`,
    )
    .bind(date, providerId, cooldownUntil)
    .run();
}

export interface RunLegResult<T> {
  member: TrialPoolMember;
  result: T;
}

/**
 * Runs one leg against the pool, routing around a RATE_LIMITED/
 * QUOTA_EXHAUSTED member (a routing signal, not an outcome — FR-031c) to
 * the next eligible one, so a 429 never reaches the caller (SC-010c).
 * `call` performs the actual provider request and should throw AppError on
 * failure exactly like provider.ts. The estimate is reserved before each
 * attempt and released again if that attempt throws; the CALLER settles a
 * successful one to the real figure via `settleTrialBudget()` once usage is
 * known (see that function's comment).
 */
export async function runLeg<T>(
  leg: TrialLeg,
  cfg: RuntimeConfig,
  db: D1Database,
  now: Date,
  call: (opts: ProviderCallOptions) => Promise<T>,
  secretFor: (bindingName: string) => string,
): Promise<RunLegResult<T>> {
  const tried = new Set<string>();
  const date = now.toISOString().slice(0, 10);
  const estimate = estimateFor(leg);
  let lastError: AppError | null = null;

  for (;;) {
    const member = await selectMember(leg, cfg, db, now, tried);
    if (!member) {
      // A member that answered badly says nothing about the pool's budget,
      // so the learner gets that retryable error, not "trial unavailable".
      throw lastError?.tryElsewhere ? lastError : new AppError("TRIAL_UNAVAILABLE");
    }
    tried.add(member.id);

    await reserveEstimate(db, date, member.id, estimate);

    try {
      const result = await call({
        baseUrl: member.base_url,
        model: member.model,
        apiKey: secretFor(member.secret_binding),
      });
      return { member, result };
    } catch (err) {
      await releaseEstimate(db, date, member.id, estimate);
      // A member that is rate-limited, out of quota, or simply not
      // answering is a member this call should stop waiting on and the
      // next one should be tried — that is the whole reason the pool has
      // more than one member.
      //
      // A provider that never answered was previously rethrown here, which
      // meant a single slow member ended the call outright: on a physical
      // device the assessment failed roughly two times in three, always
      // after the provider's own 30-second timeout, while the other pool
      // member was healthy and answering in about a second. The cooldown
      // goes on too, exactly as for a rate limit — a member that just timed
      // out is very likely to time out again, and burning another 30
      // seconds to rediscover that is the learner's time, not ours.
      //
      // An upstream that answered with a 5xx or an unusable 200 is flagged
      // `tryElsewhere`: the next member gets the call, but this one is not
      // cooled down, since one bad answer is not a pattern. Any other error
      // status (400, 401) is about the request and surfaces straight to the
      // caller; `trial.session-identity` pins that for a lone member.
      const tryNextMember =
        err instanceof AppError &&
        (err.code === "RATE_LIMITED" || err.code === "QUOTA_EXHAUSTED" || err.memberUnavailable);
      if (tryNextMember) {
        await setCooldown(db, date, member.id, new Date(now.getTime() + member.cooldown_ms).toISOString());
        lastError = err;
        continue;
      }
      if (err instanceof AppError && err.tryElsewhere) {
        lastError = err;
        continue;
      }
      throw err;
    }
  }
}

// --- trial_consumed (data-model.md §A4, §B8, FR-032, FR-032a) ---

export interface TrialConsumedRow {
  startedAt: string;
  completedAt: string | null;
  /**
   * The problem the taster was spent on. NULL on a pre-0002 row, and on a
   * row the walkthrough created before the taster proper was claimed
   * (0003) — `isTasterUnclaimed()` tells those two apart.
   */
  problemId: string | null;
  /** The UTC day it was spent on. NULL in the same two cases as above. */
  date: string | null;
  /** Walkthrough turns spent by this install, for life (0003). */
  practiceTurns: number;
}

export async function getTrialConsumed(db: D1Database, installId: string): Promise<TrialConsumedRow | null> {
  const row = await db
    .prepare(
      "SELECT started_at, completed_at, problem_id, date, practice_turns FROM trial_consumed WHERE install_id = ?1",
    )
    .bind(installId)
    .first<{
      started_at: string;
      completed_at: string | null;
      problem_id: string | null;
      date: string | null;
      practice_turns: number;
    }>();
  if (!row) return null;
  return {
    startedAt: row.started_at,
    completedAt: row.completed_at,
    problemId: row.problem_id,
    date: row.date,
    practiceTurns: row.practice_turns ?? 0,
  };
}

/**
 * FR-032. True only for a call that belongs to the ONE session this install
 * already has open: same problem, same UTC day, not yet completed. Anything
 * else is a request for a SECOND session and must be refused.
 *
 * The identity check is the fix for the hole 0002 documents: without it,
 * `completed_at IS NULL` alone meant "in flight", and since completed_at is
 * only ever written after a successful judge, an abandoned session stayed in
 * flight for good — handing out a fresh trial.turn_cap on every new
 * problem_id and again every day, with the new-session budget gate skipped.
 */
export function isSameTrialSession(
  row: TrialConsumedRow,
  problemId: string,
  date: string,
): boolean {
  return row.completedAt === null && row.problemId === problemId && row.date === date;
}

/**
 * A row that exists but has never claimed the taster proper — written by
 * the walkthrough alone (0003), which counts its turns on this row without
 * pinning it to a problem or a day.
 *
 * Deliberately NOT the same shape as the pre-0002 rows this looks like:
 * those carry `completed_at = started_at`, written by 0002's own UPDATE
 * exactly so an unidentifiable open session could never be mistaken for a
 * live one. An unclaimed row is open AND unpinned; a legacy row is closed.
 */
export function isTasterUnclaimed(row: TrialConsumedRow): boolean {
  return row.completedAt === null && row.problemId === null;
}

/** Practice turns already spent by this install, for life. */
export function practiceTurnsUsed(row: TrialConsumedRow | null): number {
  return row?.practiceTurns ?? 0;
}

/**
 * Counts one walkthrough turn against the taster row, creating that row if
 * the learner has not started the taster proper yet. `problem_id`/`date`
 * are left NULL: practice does not claim the session, it only spends from
 * the same lifetime allowance.
 */
export async function bumpPracticeTurn(
  db: D1Database,
  installId: string,
  startedAt: string,
): Promise<void> {
  await db
    .prepare(
      `INSERT INTO trial_consumed (install_id, started_at, practice_turns)
       VALUES (?1, ?2, 1)
       ON CONFLICT(install_id) DO UPDATE SET practice_turns = practice_turns + 1`,
    )
    .bind(installId, startedAt)
    .run();
}

/** Undoes bumpPracticeTurn() when the provider never answered (Constitution VIII). */
export async function releasePracticeTurn(db: D1Database, installId: string): Promise<void> {
  await db
    .prepare(
      "UPDATE trial_consumed SET practice_turns = MAX(0, practice_turns - 1) WHERE install_id = ?1",
    )
    .bind(installId)
    .run();
}

/**
 * Written on the FIRST trial call that reaches the provider — never a
 * hint pull, which reaches none (FR-032a). ON CONFLICT DO NOTHING: a
 * session already in flight must not have its started_at, its problem or
 * its date disturbed — those three ARE the session's identity, and
 * isSameTrialSession() reads them on every later call.
 */
export async function markTrialStarted(
  db: D1Database,
  installId: string,
  startedAt: string,
  problemId: string,
  date: string,
): Promise<void> {
  await db
    .prepare(
      // DO UPDATE, but only over a row that has not claimed the taster: the
      // walkthrough may have created it (0003) with problem_id/date NULL.
      // The WHERE is what preserves 0002's guarantee — a row that already
      // names a problem is never re-pointed at a different one.
      `INSERT INTO trial_consumed (install_id, started_at, problem_id, date)
       VALUES (?1, ?2, ?3, ?4)
       ON CONFLICT(install_id) DO UPDATE
         SET started_at = ?2, problem_id = ?3, date = ?4
         WHERE trial_consumed.problem_id IS NULL AND trial_consumed.completed_at IS NULL`,
    )
    .bind(installId, startedAt, problemId, date)
    .run();
}

/**
 * Undoes markTrialStarted() when the provider never answered — the trial-path
 * counterpart of refundTurn() and releaseJudgeClaim() (Constitution VIII: what
 * was never served is not spent).
 *
 * Guarded on `started_at`, which markTrialStarted() leaves untouched on an
 * existing row (ON CONFLICT DO NOTHING). So this removes ONLY a row the same
 * call just created; a failed turn in the middle of an established session
 * cannot delete that session. Matters more since 0002: the row now pins the
 * taster to one problem on one day, so a row written by a call that never
 * reached a provider would forfeit the taster outright.
 */
export async function releaseTrialStart(db: D1Database, installId: string, startedAt: string): Promise<void> {
  await db
    .prepare("DELETE FROM trial_consumed WHERE install_id = ?1 AND started_at = ?2 AND completed_at IS NULL")
    .bind(installId, startedAt)
    .run();
}

export async function markTrialCompleted(db: D1Database, installId: string, completedAt: string): Promise<void> {
  await db
    .prepare("UPDATE trial_consumed SET completed_at = ?2 WHERE install_id = ?1")
    .bind(installId, completedAt)
    .run();
}

/** New sessions started today, across all installs — data-model.md §B8's `sessionsStartedToday()`. */
export async function countSessionsStartedToday(db: D1Database, date: string): Promise<number> {
  const row = await db
    // `problem_id IS NOT NULL`: a row written by the walkthrough alone has
    // not started a session, and must not count against the operator's cap
    // on how many tasters begin today.
    .prepare(
      "SELECT COUNT(*) AS n FROM trial_consumed WHERE started_at LIKE ?1 AND problem_id IS NOT NULL",
    )
    .bind(`${date}%`)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

/**
 * data-model.md §A5: `trial.daily_session_cap` and `trial.pool[]` are both
 * read here, not in routes/trial.ts — the new-session gate is this
 * module's concern in full. Refuses only a NEW session (no
 * `trial_consumed` row yet); a session already in flight is the caller's
 * to allow regardless of this result.
 */
export async function newSessionGateOk(cfg: RuntimeConfig, db: D1Database, now: Date): Promise<boolean> {
  const member = await selectMember("chat", cfg, db, now);
  if (!member) return false;
  if (cfg.trial.daily_session_cap > 0) {
    const date = now.toISOString().slice(0, 10);
    const startedToday = await countSessionsStartedToday(db, date);
    if (startedToday >= cfg.trial.daily_session_cap) return false;
  }
  return true;
}
