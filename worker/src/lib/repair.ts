// plan.md §Guards. Three pure guards over a repair candidate, each with its
// own unit test (test/unit/repair-guards.test.ts). Any failure discards the
// repaired text in favour of the raw transcript — a rejected guard is not an
// error the learner sees (FR-006).
import { AppError } from "./errors";
import { containsBlockedTerm } from "./leak-filter";
import { REPAIR_PROMPT } from "../prompts/repair";
import type { Provider } from "./provider";
import { normalise } from "./text-match";

/** Guard 1. Both directions: catches truncation and runaway output. */
export function withinLengthRatio(raw: string, repaired: string, maxRatio: number): boolean {
  if (raw.length === 0) return false;
  const ratio = repaired.length / raw.length;
  return ratio <= maxRatio && ratio >= 1 / maxRatio;
}

/** Guard 2. blockedTerms is built by the CALLER from the private half, after the provider answered. */
export function containsNoGroundTruth(repaired: string, blockedTerms: readonly string[]): boolean {
  return !containsBlockedTerm(repaired, blockedTerms);
}

/** Guard 3. Normalised word-multiset overlap: what fraction of the raw's words survive. */
export function retainsLearnerWords(raw: string, repaired: string, minOverlap: number): boolean {
  const rawWords = normalise(raw).split(" ").filter((w) => w.length > 0);
  if (rawWords.length === 0) return false;
  const pool = new Map<string, number>();
  for (const w of normalise(repaired).split(" ").filter((w) => w.length > 0)) {
    pool.set(w, (pool.get(w) ?? 0) + 1);
  }
  let kept = 0;
  for (const w of rawWords) {
    const n = pool.get(w) ?? 0;
    if (n > 0) { pool.set(w, n - 1); kept++; }
  }
  return kept / rawWords.length >= minOverlap;
}

export interface CallRepairProviderParams {
  provider: Provider;
  baseUrl: string;
  apiKey: string;
  model: string;
  glossaryTerms: readonly string[];
  transcript: string;
  timeoutMs: number;
}

export interface CallRepairProviderResult {
  text: string;
  inputTokens: number;
  outputTokens: number;
  latencyMs: number;
}

/**
 * `research.md` READ THIS BEFORE T001 §4 — `structuredCompletion()` has no
 * per-call timeout parameter, so the bound here is a `Promise.race` against
 * a timer, not an abort signal. Returns `null` on timeout or on any thrown
 * `AppError` (a rejected key, a rate limit, a malformed upstream body) —
 * every one of those is a fallback to the raw transcript, never a thrown
 * error the caller has to catch.
 */
export async function callRepairProvider(
  params: CallRepairProviderParams,
): Promise<CallRepairProviderResult | null> {
  const userContent = `Terms: ${params.glossaryTerms.join(", ")}\n\nTranscript: ${params.transcript}`;
  const startedAt = Date.now();
  try {
    const call = params.provider.structuredCompletion({
      baseUrl: params.baseUrl,
      model: params.model,
      apiKey: params.apiKey,
      systemPrompt: REPAIR_PROMPT,
      userContent,
      maxTokens: Math.min(1024, Math.ceil(params.transcript.length / 3) + 128),
      temperature: 0,
    });
    const result = await Promise.race([
      call,
      new Promise<null>((resolve) => setTimeout(() => resolve(null), params.timeoutMs)),
    ]);
    const latencyMs = Date.now() - startedAt;
    if (result === null) return null;
    return {
      text: result.text,
      inputTokens: result.usage.inputTokens,
      outputTokens: result.usage.outputTokens,
      latencyMs,
    };
  } catch (err) {
    if (err instanceof AppError) return null;
    throw err;
  }
}
