// Shared live-provider client for both harness suites. Unlike
// test/contract/helpers.ts, fetchMock is never activated here — requests
// go out to the real provider, over the real network, using a real key
// read from GROQ_API_KEY (worker/package.json T088 gates test:harness on
// this being set; see also quickstart.md §7).
import { env, SELF } from "cloudflare:test";

export function requireGroqApiKey(): string {
  const key = env.GROQ_API_KEY;
  if (!key) {
    throw new Error(
      "GROQ_API_KEY is not set. worker/test/harness/** makes live provider calls and must not run without it — see quickstart.md §7.",
    );
  }
  return key;
}

/**
 * Optional: point this harness run at a different provider/model than
 * whatever's seeded in config, without editing the migration's
 * seed row — set both HARNESS_PROVIDER and HARNESS_MODEL to opt in. Left
 * unset, the seeded default (groq) runs as normal. Useful for verifying
 * the harness against a different learner key when the usual one is
 * rate-limited, without ever committing a provider swap.
 */
export async function applyProviderOverride(db: D1Database): Promise<void> {
  const provider = env.HARNESS_PROVIDER;
  const model = env.HARNESS_MODEL;
  if (!provider || !model) return;
  const row = await db.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  if (!row) return;
  const cfg = JSON.parse(row.payload);
  cfg.provider = provider;
  cfg.model = model;
  await db
    .prepare("UPDATE config SET payload = ?1, updated_at = datetime('now') WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

export async function mintInstallId(): Promise<string> {
  const res = await SELF.fetch("https://worker.test/v1/install", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ platform: "android", device_id: crypto.randomUUID().replace(/-/g, "").slice(0, 16) }),
  });
  const body = (await res.json()) as { install_id: string };
  return body.install_id;
}

export interface Turn {
  role: "user" | "tutor";
  text: string;
}

export interface ChatSSEFrame {
  event: string;
  data: unknown;
}

export function parseChatSSE(text: string): ChatSSEFrame[] {
  const frames: ChatSSEFrame[] = [];
  for (const raw of text.split("\n\n")) {
    if (!raw.trim()) continue;
    const lines = raw.split("\n");
    const eventLine = lines.find((l) => l.startsWith("event:"));
    const dataLine = lines.find((l) => l.startsWith("data:"));
    if (!eventLine || !dataLine) continue;
    frames.push({ event: eventLine.slice(6).trim(), data: JSON.parse(dataLine.slice(5).trim()) });
  }
  return frames;
}

export interface LiveChatResult {
  replyText: string;
  leakBlocked: boolean;
  sessionEnded: string | null;
  turnIndex: number;
  /** Set only when the turn came back as an `error` frame (e.g. RATE_LIMITED) — the caller's cue to back off and retry rather than treat an empty reply as a content result. */
  errorRetryAfterMs?: number;
}

/** Sends one live /v1/chat turn and concatenates every `token` frame into one reply string. */
export async function sendChatTurn(
  installId: string,
  problemId: string,
  messages: Turn[],
  apiKey: string,
): Promise<LiveChatResult> {
  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: problemId, messages }),
  });
  const frames = parseChatSSE(await res.text());
  const errorFrame = frames.find((f) => f.event === "error")?.data as
    | { error?: { retry_after_ms?: number } }
    | undefined;
  const replyText = frames
    .filter((f) => f.event === "token")
    .map((f) => (f.data as { text: string }).text)
    .join(" ");
  const meta = frames.find((f) => f.event === "meta")?.data as
    | { session_ended: string | null; turn_index: number; leak_blocked: boolean }
    | undefined;
  return {
    replyText,
    leakBlocked: meta?.leak_blocked ?? false,
    sessionEnded: meta?.session_ended ?? null,
    turnIndex: meta?.turn_index ?? 0,
    errorRetryAfterMs: errorFrame?.error?.retry_after_ms,
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

/** Never wait longer than this for one retry, even if the server asks for more — a suite-halting multi-minute wait is worse than a clear, fast failure that says "this key doesn't have headroom for this suite's burst pattern." */
const MAX_RETRY_WAIT_MS = 45_000;

/**
 * Runs a whole scripted conversation (learner turns only) against one
 * fresh session, returning every tutor reply in order. Retries once past
 * a RATE_LIMITED response, waiting the server's own retry_after_ms
 * (capped) — a free tier key under a rapid-fire test suite hits this
 * routinely, and an empty reply from an unretried 429 would otherwise
 * register as a vacuous pass on every assertion downstream (an empty
 * string trivially contains no blocked term).
 */
export async function runConversation(
  problemId: string,
  learnerTurns: string[],
  apiKey: string,
): Promise<LiveChatResult[]> {
  const installId = await mintInstallId();
  const conversation: Turn[] = [];
  const results: LiveChatResult[] = [];
  for (const text of learnerTurns) {
    conversation.push({ role: "user", text });
    let result = await sendChatTurn(installId, problemId, conversation, apiKey);
    if (result.replyText.length === 0) {
      await sleep(Math.min(result.errorRetryAfterMs ?? 4000, MAX_RETRY_WAIT_MS));
      result = await sendChatTurn(installId, problemId, conversation, apiKey);
    }
    conversation.push({ role: "tutor", text: result.replyText });
    results.push(result);
    await sleep(800);
  }
  return results;
}

export async function requestAssessment(
  problemId: string,
  conversation: Turn[],
  apiKey: string,
): Promise<Record<string, unknown>> {
  const installId = await mintInstallId();
  const res = await SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": apiKey,
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: problemId, conversation, ended_by: "user" }),
  });
  return res.json();
}
