// plan.md §Primary Dependencies: no LLM SDK. Every implementation of this
// interface is fetch-based against an OpenAI-compatible endpoint, and takes
// the credential per call — never stores it, never reads it from a fixed env
// binding (data-model.md §B8 needs the same client pointed at several hosts
// for the trial pool).
//
// Wire role vs provider role (data-model.md §A2): messages here use OUR
// vocabulary, `user | tutor`. Translating `tutor -> assistant` is the job of
// the concrete implementation (provider-groq.ts) and of nothing else.

export interface ProviderMessage {
  role: "user" | "tutor";
  text: string;
}

export interface ProviderCallOptions {
  baseUrl: string;
  model: string;
  apiKey: string;
}

export interface UsageInfo {
  inputTokens: number;
  outputTokens: number;
}

export interface StreamChatParams extends ProviderCallOptions {
  systemPrompt: string;
  messages: ProviderMessage[];
}

export interface StreamChatResult {
  /** Text deltas as they arrive. Consumed exactly once. */
  deltas: AsyncIterable<string>;
  /** Resolves once the stream has fully drained, with the provider's real usage figures. */
  usage: () => Promise<UsageInfo>;
}

export interface StructuredCompletionParams extends ProviderCallOptions {
  systemPrompt: string;
  userContent: string;
  maxTokens: number;
  temperature: number;
  /**
   * Present for the judge call (`response_format: json_schema, strict: true`).
   * Absent for a plain-text completion — the condensation call in
   * data-model.md §B6, which is otherwise identical in shape.
   */
  jsonSchema?: { name: string; schema: Record<string, unknown> };
}

export interface StructuredCompletionResult {
  /** Raw text. Always present. What condense.ts reads. */
  text: string;
  /** Parsed JSON, present only when `jsonSchema` was supplied. What judge.ts reads. */
  json?: unknown;
  usage: UsageInfo;
}

export interface Provider {
  streamChat(params: StreamChatParams): Promise<StreamChatResult>;
  structuredCompletion(params: StructuredCompletionParams): Promise<StructuredCompletionResult>;
}

/**
 * Fixed base URL per `cfg.provider` name on the LEARNER-KEYED path (chat,
 * judge). Both are OpenAI-compatible, so provider-groq.ts's generic client
 * serves either — only the base_url differs. The trial pool (§B8) is a
 * separate, per-member-configured set of base_urls and does not use this
 * table.
 */
export const KEYED_PROVIDER_BASE_URLS: Record<string, string> = {
  groq: "https://api.groq.com/openai/v1",
  openrouter: "https://openrouter.ai/api/v1",
  gemini: "https://generativelanguage.googleapis.com/v1beta/openai",
};
