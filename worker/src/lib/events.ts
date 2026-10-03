// `events` table writer (data-model.md §A4). Two callers: this internal
// helper for server-generated analytics (e.g. assessment_verdict_overridden,
// written by judge.ts with no message content), and POST /v1/event
// (routes/event.ts, T100) for client-submitted batches validated against
// contracts/event.schema.json. Same table, same shape.
import { nowIso } from "./time";

export interface EventRecord {
  installId: string;
  name: string;
  props: Record<string, string | number | boolean>;
  clientTs: string;
}

export async function writeEvent(db: D1Database, record: EventRecord): Promise<void> {
  await db
    .prepare(
      `INSERT INTO events (install_id, name, props_json, client_ts, server_ts)
       VALUES (?,?,?,?,?)`,
    )
    .bind(record.installId, record.name, JSON.stringify(record.props), record.clientTs, nowIso())
    .run();
}
