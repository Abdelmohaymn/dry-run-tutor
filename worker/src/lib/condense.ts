// data-model.md §B6. Windowing that keeps total condensation cost linear in
// turn count (SC-007a). Its input is the conversation only — the
// ground-truth slice must never reach it (FR-007).
import { CONDENSE_PROMPT } from "../prompts/condense";
import type { Provider } from "./provider";
import type { RuntimeConfig } from "./runtime-config";
import type { Turn } from "./schemas";
import { writeUsage } from "./usage";

export interface CondenseResult {
  /** Present when called; otherwise the prior summary passed straight through. */
  summary: string | undefined;
  /** The newest K turns, untouched. */
  verbatim: Turn[];
  called: boolean;
  /**
   * How many of the request's leading `messages` this call folded into
   * `summary`. Zero when not called. The app marks exactly these rows
   * covered; the `verbatim` ones must keep being sent.
   */
  covered: number;
}

export interface CondenseCallOptions {
  baseUrl: string;
  apiKey: string;
  /**
   * The condensation model for THIS request's provider. Passed in rather than
   * read from cfg.trim.condense_model, because since per-key routing the
   * provider — and so the model name — varies per request (FR-008b).
   */
  model: string;
}

export interface CondenseUsageContext {
  db: D1Database;
  installId: string;
  problemId: string;
  date: string;
  /** From turn-cap.ts, for the usage row. */
  turnIndex: number;
}

function renderTurns(turns: Turn[]): string {
  return turns.map((t) => `${t.role}: ${t.text}`).join("\n");
}

export async function condense(
  priorSummary: string | undefined,
  messages: Turn[],
  cfg: RuntimeConfig,
  provider: Provider,
  callOptions: CondenseCallOptions,
  usageContext: CondenseUsageContext,
): Promise<CondenseResult> {
  const K = cfg.trim.verbatim_turns;
  if (messages.length <= K) {
    return { summary: priorSummary, verbatim: messages, called: false, covered: 0 };
  }

  // ONLY the newly-overflowing turns — disjoint across calls, which is what
  // keeps cumulative condensation input linear rather than quadratic.
  const falling = messages.slice(0, messages.length - K);
  const verbatim = messages.slice(messages.length - K);

  const startedAt = Date.now();
  const result = await provider.structuredCompletion({
    baseUrl: callOptions.baseUrl,
    model: callOptions.model,
    apiKey: callOptions.apiKey,
    systemPrompt: CONDENSE_PROMPT,
    userContent: `${priorSummary ?? ""}\n\n${renderTurns(falling)}`,
    // 200 was sized for a plain completion. Some condense-model choices
    // (e.g. Groq's openai/gpt-oss-120b) are reasoning models whose hidden
    // reasoning tokens are billed against maxTokens before any `content` is
    // emitted — on a richer conversation the reasoning alone can exhaust a
    // 200-token budget, leaving `content: ""` and `finish_reason: "length"`
    // (surfaces as UNCLEAR_RETRY). 600 leaves headroom for reasoning to
    // finish and still emit the ~120-word summary CONDENSE_PROMPT asks for.
    maxTokens: 600,
    temperature: 0,
  });
  const latencyMs = Date.now() - startedAt;

  await writeUsage(usageContext.db, {
    installId: usageContext.installId,
    date: usageContext.date,
    endpoint: "condense",
    problemId: usageContext.problemId,
    turnIndex: usageContext.turnIndex,
    model: callOptions.model,
    provider: cfg.provider,
    inputTokens: result.usage.inputTokens,
    outputTokens: result.usage.outputTokens,
    latencyMs,
  });

  return { summary: result.text, verbatim, called: true, covered: falling.length };
}
