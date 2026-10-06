import { env, SELF, fetchMock } from "cloudflare:test";

export const GROQ_ORIGIN = "https://api.groq.com";
export const GROQ_CHAT_PATH = "/openai/v1/chat/completions";

/** Registers the given Android ID; the same id always yields the same install id. */
export async function mintInstallIdFor(deviceId: string): Promise<string> {
  const res = await SELF.fetch("https://worker.test/v1/install", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ platform: "android", device_id: deviceId }),
  });
  const body = (await res.json()) as { install_id: string };
  return body.install_id;
}

export async function mintInstallId(): Promise<string> {
  return mintInstallIdFor(crypto.randomUUID().replace(/-/g, "").slice(0, 16));
}

/** A minimal, valid streaming SSE body an OpenAI-compatible endpoint would return. */
export function groqStreamBody(
  text: string,
  usage: { prompt_tokens: number; completion_tokens: number } = { prompt_tokens: 500, completion_tokens: 50 },
): string {
  return [
    `data: ${JSON.stringify({ choices: [{ delta: { content: text } }] })}\n\n`,
    `data: ${JSON.stringify({ choices: [{ delta: {} }], usage })}\n\n`,
    `data: [DONE]\n\n`,
  ].join("");
}

/** A minimal, valid non-streaming completion body (condense / judge shape). */
export function groqCompletionBody(
  content: string,
  usage: { prompt_tokens: number; completion_tokens: number } = { prompt_tokens: 100, completion_tokens: 20 },
) {
  return { choices: [{ message: { content } }], usage };
}

/**
 * Sends one /v1/chat turn, capturing the raw outbound request body via
 * undici's reply-callback form (invoked exactly once per consumed request —
 * unlike an options.body matcher function, which fires twice), and fully
 * drains the SSE response before returning. NOTE: leaving a streamed
 * response undrained across successive requests in a loop has been observed
 * to break vitest-pool-workers' isolated-storage bookkeeping — always drain.
 */
export async function sendTurnCapturingSystemPrompt(
  installId: string,
  n: number,
  capturedBodies: string[],
): Promise<{ status: number }> {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(
      200,
      (opts) => {
        capturedBodies.push(opts.body as string);
        return groqStreamBody(`reply ${n}`);
      },
      { headers: { "content-type": "text/event-stream" } },
    );

  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: `turn ${n}` }] }),
  });
  const status = res.status;
  await res.text();
  return { status };
}

export function systemPromptOf(rawBody: string): string {
  const parsed = JSON.parse(rawBody);
  return parsed.messages[0].content as string;
}

/**
 * Feature 004. The seed migration's `config` row carries no `repair`
 * block (it predates this feature), so every repair contract test that
 * needs `cfg.repair.enabled === true` writes one first — same D1-payload-edit
 * pattern as config.turncap-lever.test.ts. Values match
 * contracts/repair-endpoint.md §Merge — the D1 write.
 */
export async function setRepairConfig(
  overrides: Partial<{
    enabled: boolean;
    model: string;
    min_chars: number;
    max_input_chars: number;
    timeout_ms: number;
    max_output_ratio: number;
    min_word_overlap: number;
  }> = {},
): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  cfg.repair = {
    enabled: true,
    model: "llama-3.1-8b-instant",
    min_chars: 40,
    max_input_chars: 2000,
    timeout_ms: 1500,
    max_output_ratio: 1.5,
    min_word_overlap: 0.6,
    ...overrides,
  };
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

/**
 * Feature 007. The seed migration's `config` row carries no `web`
 * block (it predates this feature), so every web-route contract test that
 * needs a known origin writes one first — same
 * D1-payload-edit pattern as setRepairConfig above.
 */
export async function setWebConfig(
  overrides: Partial<{
    allowed_origins: string[];
    notify_enabled: boolean;
  }> = {},
): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  cfg.web = {
    allowed_origins: ["https://site.test"],
    notify_enabled: true,
    ...overrides,
  };
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

export async function readChatSSE(res: Response): Promise<{ event: string; data: unknown }[]> {
  const text = await res.text();
  const frames: { event: string; data: unknown }[] = [];
  for (const raw of text.split("\n\n")) {
    if (!raw.trim()) continue;
    const lines = raw.split("\n");
    const eventLine = lines.find((l) => l.startsWith("event:"));
    const dataLine = lines.find((l) => l.startsWith("data:"));
    if (!eventLine || !dataLine) continue;
    frames.push({
      event: eventLine.slice(6).trim(),
      data: JSON.parse(dataLine.slice(5).trim()),
    });
  }
  return frames;
}
