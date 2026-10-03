import { env } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import { condense } from "../../src/lib/condense";
import { getRuntimeConfig } from "../../src/lib/runtime-config";
import type { Provider, StructuredCompletionParams } from "../../src/lib/provider";
import type { Turn } from "../../src/lib/schemas";

function turn(i: number, role: "user" | "tutor" = "user"): Turn {
  return { role, text: `turn ${i}` };
}

function makeMockProvider(replyText = "a condensed summary") {
  const calls: StructuredCompletionParams[] = [];
  const provider: Provider = {
    streamChat: vi.fn(),
    structuredCompletion: vi.fn(async (params: StructuredCompletionParams) => {
      calls.push(params);
      return { text: replyText, usage: { inputTokens: params.userContent.length, outputTokens: 10 } };
    }),
  };
  return { provider, calls };
}

let counter = 0;
function freshKey() {
  counter += 1;
  return { installId: `install-condense-${counter}`, problemId: "vp-0001", date: "2026-08-20" };
}

describe("condense()", () => {
  it("does not call the provider when messages.length <= K, and passes the prior summary through unchanged", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const { provider } = makeMockProvider();
    const messages = Array.from({ length: cfg.trim.verbatim_turns }, (_, i) => turn(i));

    const result = await condense(
      "an existing summary",
      messages,
      cfg,
      provider,
      { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
      { db: env.DB, ...freshKey(), turnIndex: 1 },
    );

    expect(result.called).toBe(false);
    expect(result.covered).toBe(0);
    expect(result.summary).toBe("an existing summary");
    expect(result.verbatim).toEqual(messages);
    expect(provider.structuredCompletion).not.toHaveBeenCalled();
  });

  it("selects exactly the overflow turns as `falling`, and the newest K as verbatim", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const K = cfg.trim.verbatim_turns;
    const { provider, calls } = makeMockProvider();
    const total = K + 4;
    const messages = Array.from({ length: total }, (_, i) => turn(i));

    const result = await condense(
      undefined,
      messages,
      cfg,
      provider,
      { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
      { db: env.DB, ...freshKey(), turnIndex: 1 },
    );

    expect(result.called).toBe(true);
    expect(result.covered).toBe(4);
    expect(result.verbatim).toEqual(messages.slice(total - K));
    expect(calls).toHaveLength(1);
    const sentText = calls[0].userContent;
    for (const overflow of messages.slice(0, total - K)) {
      expect(sentText).toContain(overflow.text);
    }
    for (const kept of messages.slice(total - K)) {
      expect(sentText).not.toContain(kept.text);
    }
  });

  it("includes the prior summary exactly once in the call input", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const K = cfg.trim.verbatim_turns;
    const { provider, calls } = makeMockProvider();
    const messages = Array.from({ length: K + 2 }, (_, i) => turn(i));
    const priorSummary = "UNIQUE_PRIOR_SUMMARY_MARKER";

    await condense(
      priorSummary,
      messages,
      cfg,
      provider,
      { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
      { db: env.DB, ...freshKey(), turnIndex: 1 },
    );

    const sentText = calls[0].userContent;
    const occurrences = sentText.split(priorSummary).length - 1;
    expect(occurrences).toBe(1);
  });

  it("writes nothing to D1 when condensation is not triggered", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const { provider } = makeMockProvider();
    const key = freshKey();
    const messages = Array.from({ length: cfg.trim.verbatim_turns }, (_, i) => turn(i));

    await condense(
      undefined,
      messages,
      cfg,
      provider,
      { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
      { db: env.DB, ...key, turnIndex: 1 },
    );

    const usageRows = await env.DB.prepare("SELECT COUNT(*) as n FROM usage WHERE install_id = ?")
      .bind(key.installId)
      .first<{ n: number }>();
    expect(usageRows!.n).toBe(0);
  });

  it("writes exactly one `condense` usage row when it is triggered", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const K = cfg.trim.verbatim_turns;
    const { provider } = makeMockProvider();
    const key = freshKey();
    const messages = Array.from({ length: K + 3 }, (_, i) => turn(i));

    await condense(
      undefined,
      messages,
      cfg,
      provider,
      { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
      { db: env.DB, ...key, turnIndex: 2 },
    );

    const row = await env.DB.prepare("SELECT endpoint, turn_index FROM usage WHERE install_id = ?")
      .bind(key.installId)
      .first<{ endpoint: string; turn_index: number }>();
    expect(row).toMatchObject({ endpoint: "condense", turn_index: 2 });
  });
});
