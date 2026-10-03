// data-model.md §A4 `usage` table. FR-012, FR-035: real token counts, from
// the first request, on every relayed call — chat, judge, condense, hint
// (zero tokens), trial_chat, trial_judge. Never a learner key, never message
// content: only the columns below are ever written.
import { nowIso } from "./time";

export type UsageEndpoint = "chat" | "judge" | "condense" | "hint" | "trial_chat" | "trial_judge" | "repair" | "key_check";

export interface UsageRecord {
  installId: string;
  date: string; // YYYY-MM-DD, UTC
  endpoint: UsageEndpoint;
  problemId: string;
  turnIndex: number; // from turn-cap.ts, never the payload
  model: string;
  provider: string;
  inputTokens: number;
  outputTokens: number;
  latencyMs: number;
  leakBlocked?: boolean;
  verdictOverridden?: boolean;
}

export async function writeUsage(db: D1Database, record: UsageRecord): Promise<void> {
  await db
    .prepare(
      `INSERT INTO usage (
         install_id, date, endpoint, problem_id, turn_index, model, provider,
         input_tokens, output_tokens, latency_ms, leak_blocked, verdict_overridden, created_at
       ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
    )
    .bind(
      record.installId,
      record.date,
      record.endpoint,
      record.problemId,
      record.turnIndex,
      record.model,
      record.provider,
      record.inputTokens,
      record.outputTokens,
      record.latencyMs,
      record.leakBlocked ? 1 : 0,
      record.verdictOverridden ? 1 : 0,
      nowIso(),
    )
    .run();
}
