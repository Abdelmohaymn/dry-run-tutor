import { fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { AppError } from "../../src/lib/errors";
import { groqProvider } from "../../src/lib/provider-groq";

const BASE_URL = "https://api.groq.test/openai/v1";
const ORIGIN = "https://api.groq.test";
const PATH = "/openai/v1/chat/completions";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function expectAppError(promise: Promise<unknown>): Promise<AppError> {
  try {
    await promise;
  } catch (err) {
    expect(err).toBeInstanceOf(AppError);
    return err as AppError;
  }
  throw new Error("expected promise to reject with an AppError");
}

function callStructured() {
  return groqProvider.structuredCompletion({
    baseUrl: BASE_URL,
    model: "test-model",
    apiKey: "gsk_test_key_should_never_be_read_from_body",
    systemPrompt: "system",
    userContent: "user",
    maxTokens: 200,
    temperature: 0,
  });
}

describe("provider-groq error mapping (error-catalog.md §Mapping upstream to ours)", () => {
  it("401 -> INVALID_KEY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(401, { error: "unauthorized, secret upstream detail" });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("INVALID_KEY");
  });

  it("400 naming the API key (Gemini's shape) -> INVALID_KEY", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(400, [{ error: { code: 400, message: "Please pass a valid API key", status: "INVALID_ARGUMENT" } }]);
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("INVALID_KEY");
  });

  it("any other 400 -> UNCLEAR_RETRY", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(400, { error: { message: "messages: too many items" } });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  it("403 -> INVALID_KEY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(403, { error: "forbidden" });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("INVALID_KEY");
  });

  it("429 with a daily/quota body -> QUOTA_EXHAUSTED", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(429, "You have exceeded your daily quota for this model");
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("QUOTA_EXHAUSTED");
  });

  it("429 without a daily/quota body -> RATE_LIMITED, retry_after_ms from Retry-After", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(429, "too many requests, slow down", { headers: { "retry-after": "20" } });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("RATE_LIMITED");
    expect(err.retryAfterMs).toBe(20000);
  });

  it("408 -> UNCLEAR_RETRY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(408, "timeout");
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  it("5xx -> UNCLEAR_RETRY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(500, "internal server error, stack trace here");
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  // docs/errors/2026-09-25-trial-judge-unclear-retry.md, bug 1: Gemini's
  // "high demand" 503 is about that provider, not the request, so another
  // pool member may well answer it.
  it("503 is flagged tryElsewhere, and a 400 is not", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(503, "high demand");
    expect((await expectAppError(callStructured())).tryElsewhere).toBe(true);

    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(400, "bad request");
    expect((await expectAppError(callStructured())).tryElsewhere).toBe(false);
  });

  it("a 200 whose content is not the requested JSON is flagged tryElsewhere", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(200, {
        choices: [{ message: { content: '{"matched_approach": "hash' }, finish_reason: "length" }],
        usage: { prompt_tokens: 10, completion_tokens: 2000 },
      });
    const err = await expectAppError(
      groqProvider.structuredCompletion({
        baseUrl: BASE_URL,
        model: "test-model",
        apiKey: "gsk_test_key_should_never_be_read_from_body",
        systemPrompt: "system",
        userContent: "user",
        maxTokens: 200,
        temperature: 0,
        jsonSchema: { name: "assessment", schema: { type: "object" } },
      }),
    );
    expect(err.code).toBe("UNCLEAR_RETRY");
    expect(err.tryElsewhere).toBe(true);
  });

  it("a network error -> UNCLEAR_RETRY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).replyWithError(new TypeError("network down"));
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  it("200 with an unparseable body -> UNCLEAR_RETRY", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(200, "not json at all", { headers: { "content-type": "text/plain" } });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  it("200 with a provider refusal -> UNCLEAR_RETRY", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(200, {
        choices: [{ message: { refusal: "I cannot assist with this request." } }],
        usage: { prompt_tokens: 10, completion_tokens: 0 },
      });
    const err = await expectAppError(callStructured());
    expect(err.code).toBe("UNCLEAR_RETRY");
  });

  it("no provider body text reaches the AppError envelope", async () => {
    const secretUpstreamText = "SECRET_UPSTREAM_DIAGNOSTIC_TEXT_12345";
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(500, secretUpstreamText);
    const err = await expectAppError(callStructured());
    expect(err.message).not.toContain(secretUpstreamText);
  });
});

describe("provider-groq structuredCompletion happy path", () => {
  it("returns parsed json and real usage when a json schema is supplied", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(200, {
        choices: [{ message: { content: JSON.stringify({ verdict: "pass" }) } }],
        usage: { prompt_tokens: 123, completion_tokens: 45 },
      });

    const result = await groqProvider.structuredCompletion({
      baseUrl: BASE_URL,
      model: "test-model",
      apiKey: "gsk_test_key",
      systemPrompt: "system",
      userContent: "user",
      maxTokens: 200,
      temperature: 0,
      jsonSchema: { name: "assessment", schema: { type: "object" } },
    });

    expect(result.json).toEqual({ verdict: "pass" });
    expect(result.usage).toEqual({ inputTokens: 123, outputTokens: 45 });
  });

  it("returns plain text with no json field when no schema is supplied (the condense shape)", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST" })
      .reply(200, {
        choices: [{ message: { content: "a condensed summary" } }],
        usage: { prompt_tokens: 10, completion_tokens: 5 },
      });

    const result = await callStructured();
    expect(result.text).toBe("a condensed summary");
    expect(result.json).toBeUndefined();
  });
});

describe("provider-groq streamChat", () => {
  it("sends the tutor stream's sampling and token ceiling explicitly (review F6)", async () => {
    let sent: any;
    fetchMock
      .get(ORIGIN)
      .intercept({ path: PATH, method: "POST", body: (raw: string) => ((sent = JSON.parse(raw)), true) })
      .reply(200, `data: ${JSON.stringify({ choices: [{ delta: { content: "ok" } }] })}\n\ndata: [DONE]\n\n`, {
        headers: { "content-type": "text/event-stream" },
      });
    const result = await groqProvider.streamChat({
      baseUrl: BASE_URL,
      model: "test-model",
      apiKey: "gsk_test_key",
      systemPrompt: "system",
      messages: [{ role: "user", text: "hi" }],
    });
    for await (const _ of result.deltas) {
      // drain
    }
    expect(sent.temperature).toBe(0.6);
    expect(sent.top_p).toBe(0.95);
    expect(sent.max_tokens).toBe(2500);
  });

  it("yields deltas and translates tutor -> assistant in the outbound body", async () => {
    fetchMock
      .get(ORIGIN)
      .intercept({
        path: PATH,
        method: "POST",
        body: (rawBody: string) => {
          const parsed = JSON.parse(rawBody);
          return parsed.messages[2].role === "assistant" && parsed.messages[1].role === "user";
        },
      })
      .reply(
        200,
        [
          `data: ${JSON.stringify({ choices: [{ delta: { content: "Hello" } }] })}\n\n`,
          `data: ${JSON.stringify({ choices: [{ delta: { content: " world" } }] })}\n\n`,
          `data: ${JSON.stringify({ choices: [{ delta: {} }], usage: { prompt_tokens: 7, completion_tokens: 2 } })}\n\n`,
          `data: [DONE]\n\n`,
        ].join(""),
        { headers: { "content-type": "text/event-stream" } },
      );

    const result = await groqProvider.streamChat({
      baseUrl: BASE_URL,
      model: "test-model",
      apiKey: "gsk_test_key",
      systemPrompt: "system",
      messages: [
        { role: "user", text: "hi" },
        { role: "tutor", text: "hello there" },
      ],
    });

    const collected: string[] = [];
    for await (const delta of result.deltas) {
      collected.push(delta);
    }
    expect(collected.join("")).toBe("Hello world");
    expect(await result.usage()).toEqual({ inputTokens: 7, outputTokens: 2 });
  });

  it("401 on the streaming call -> INVALID_KEY", async () => {
    fetchMock.get(ORIGIN).intercept({ path: PATH, method: "POST" }).reply(401, "unauthorized");
    const err = await expectAppError(
      groqProvider.streamChat({
        baseUrl: BASE_URL,
        model: "test-model",
        apiKey: "gsk_test_key",
        systemPrompt: "system",
        messages: [{ role: "user", text: "hi" }],
      }),
    );
    expect(err.code).toBe("INVALID_KEY");
  });
});
