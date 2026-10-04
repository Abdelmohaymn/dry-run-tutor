// Against an OpenAI-compatible chat-completions endpoint. This is the ONLY
// module that reads a provider HTTP status or body, and the ONLY module that
// translates our wire role (`tutor`) to the provider's (`assistant`) —
// nothing inbound ever carries the provider's vocabulary, so nothing else
// may need to (data-model.md §A2). base_url, model and the credential are
// taken as arguments on every call, never a fixed env binding, because the
// trial pool (§B8) points this same client at several hosts.
import { AppError } from "./errors";
import type {
  Provider,
  ProviderMessage,
  StreamChatParams,
  StreamChatResult,
  StructuredCompletionParams,
  StructuredCompletionResult,
  UsageInfo,
} from "./provider";

// How long to wait on a provider before giving up on it and letting the
// pool try the next member. Not a generous "it might still come back"
// budget: a healthy structured completion returns in one to five seconds,
// and a provider whose free tier is spent does not answer at all — the
// Gemini compat endpoint hangs indefinitely rather than returning 429,
// observed live. At 30s that discovery cost the learner half a minute on
// EVERY assessment before the healthy member was even tried.
const REQUEST_TIMEOUT_MS = 15_000;
const DAILY_QUOTA_PATTERN = /daily|quota/i;
// Gemini's OpenAI-compatible endpoint rejects a bad or expired key with a
// 400 ("Please pass a valid API key", or reason API_KEY_INVALID) where
// Groq sends a 401. Without this the learner saw "try again" for a key
// that will never work (found 2026-09-25).
const INVALID_KEY_400_PATTERN = /valid API key|API_KEY_INVALID|API key (?:not valid|expired)/i;

interface OpenAIChatMessage {
  role: "system" | "user" | "assistant";
  content: string;
}

function toProviderMessages(systemPrompt: string, messages: ProviderMessage[]): OpenAIChatMessage[] {
  return [
    { role: "system", content: systemPrompt },
    ...messages.map((m) => ({
      // The ONLY place `tutor -> assistant` is translated, and never the reverse.
      role: (m.role === "tutor" ? "assistant" : "user") as "assistant" | "user",
      content: m.text,
    })),
  ];
}

async function mapErrorResponse(res: Response): Promise<AppError> {
  if (res.status === 401 || res.status === 403) {
    return new AppError("INVALID_KEY");
  }
  if (res.status === 400) {
    // One of the two points where upstream text is inspected: to tell a
    // rejected key apart from any other bad request. Never stored, never
    // forwarded (error-catalog.md §Mapping upstream to ours).
    const body = await res.text().catch(() => "");
    return new AppError(INVALID_KEY_400_PATTERN.test(body) ? "INVALID_KEY" : "UNCLEAR_RETRY");
  }
  if (res.status === 429) {
    // The other point where upstream text is inspected — only to tell a daily
    // quota signal apart from a per-minute rate limit. Never stored, never
    // forwarded (error-catalog.md §Mapping upstream to ours).
    const body = await res.text().catch(() => "");
    if (DAILY_QUOTA_PATTERN.test(body)) {
      return new AppError("QUOTA_EXHAUSTED");
    }
    const retryAfterHeader = res.headers.get("retry-after");
    const retryAfterMs = retryAfterHeader ? Number(retryAfterHeader) * 1000 : undefined;
    return new AppError("RATE_LIMITED", {
      retryAfterMs: Number.isFinite(retryAfterMs) ? retryAfterMs : undefined,
    });
  }
  // A 5xx is the provider's own trouble (Gemini answers "high demand" with
  // a 503), so another pool member may serve the same request.
  if (res.status >= 500) {
    return new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
  }
  // 408, or anything else unexpected.
  return new AppError("UNCLEAR_RETRY");
}

async function fetchWithTimeout(url: string, init: RequestInit): Promise<Response> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    return await fetch(url, { ...init, signal: controller.signal });
  } catch {
    // Network error, abort, or timeout — all map to the same code, but
    // they are flagged as "this member did not answer" so the pool can try
    // the next one instead of ending the call. A provider that answers
    // with an error status is NOT flagged: that says something about the
    // request, and the next member would fail identically.
    throw new AppError("UNCLEAR_RETRY", { memberUnavailable: true });
  } finally {
    clearTimeout(timeout);
  }
}

async function* streamDeltas(
  body: ReadableStream<Uint8Array>,
  usageBox: { value?: UsageInfo },
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      let boundary: number;
      while ((boundary = buffer.indexOf("\n\n")) !== -1) {
        const rawEvent = buffer.slice(0, boundary);
        buffer = buffer.slice(boundary + 2);
        for (const line of rawEvent.split("\n")) {
          if (!line.startsWith("data:")) continue;
          const data = line.slice(5).trim();
          if (data === "[DONE]") continue;
          let parsed: any;
          try {
            parsed = JSON.parse(data);
          } catch {
            throw new AppError("UNCLEAR_RETRY");
          }
          const delta: string | undefined = parsed?.choices?.[0]?.delta?.content;
          if (delta) yield delta;
          if (parsed?.usage) {
            usageBox.value = {
              inputTokens: parsed.usage.prompt_tokens ?? 0,
              outputTokens: parsed.usage.completion_tokens ?? 0,
            };
          }
        }
      }
    }
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw new AppError("UNCLEAR_RETRY");
  } finally {
    // Runs on normal completion AND on an early `return()` — which is what
    // a `for await...of` consumer triggers by breaking out of the loop
    // (leak-filter.ts's streamFiltered() aborting on a blocked term). This
    // is `abortUpstream()` from data-model.md §B1: cancelling the reader
    // signals upstream that we are no longer reading, so the connection is
    // not left dangling.
    await reader.cancel().catch(() => {});
  }
}

async function streamChat(params: StreamChatParams): Promise<StreamChatResult> {
  const res = await fetchWithTimeout(`${params.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${params.apiKey}`,
    },
    body: JSON.stringify({
      model: params.model,
      messages: toProviderMessages(params.systemPrompt, params.messages),
      stream: true,
      stream_options: { include_usage: true },
    }),
  });

  if (!res.ok || !res.body) {
    throw await mapErrorResponse(res);
  }

  const usageBox: { value?: UsageInfo } = {};
  return {
    deltas: streamDeltas(res.body, usageBox),
    usage: async () => usageBox.value ?? { inputTokens: 0, outputTokens: 0 },
  };
}

async function structuredCompletion(
  params: StructuredCompletionParams,
): Promise<StructuredCompletionResult> {
  const res = await fetchWithTimeout(`${params.baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${params.apiKey}`,
    },
    body: JSON.stringify({
      // First, so none of the fields below can be overridden by config.
      ...(params.structuredExtraBody ?? {}),
      model: params.model,
      messages: [
        { role: "system", content: params.systemPrompt },
        { role: "user", content: params.userContent },
      ],
      max_tokens: params.maxTokens,
      temperature: params.temperature,
      stream: false,
      ...(params.jsonSchema
        ? {
            response_format: {
              type: "json_schema",
              json_schema: { name: params.jsonSchema.name, strict: true, schema: params.jsonSchema.schema },
            },
          }
        : {}),
    }),
  });

  if (!res.ok) {
    throw await mapErrorResponse(res);
  }

  // From here on the provider answered 200 but possibly with nothing
  // usable. Another pool member may do better, so each throw is flagged.
  let body: any;
  try {
    body = await res.json();
  } catch {
    throw new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
  }

  const choice = body?.choices?.[0]?.message;
  const text: string | undefined = choice?.content;
  const refusal = choice?.refusal;
  if (refusal || typeof text !== "string" || text.length === 0) {
    throw new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
  }

  const usage: UsageInfo = {
    inputTokens: body?.usage?.prompt_tokens ?? 0,
    outputTokens: body?.usage?.completion_tokens ?? 0,
  };

  if (!params.jsonSchema) {
    return { text, usage };
  }

  let json: unknown;
  try {
    json = JSON.parse(text);
  } catch {
    throw new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
  }
  return { text, json, usage };
}

export const groqProvider: Provider = { streamChat, structuredCompletion };
