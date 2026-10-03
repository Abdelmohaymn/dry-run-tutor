import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { writeUsage } from "../../src/lib/usage";

const KNOWN_KEY = "gsk_abcdefghijklmnopqrstuvwxyz012345";
const MESSAGE_CONTENT = "the learner said they would use a hash map here";

describe("writeUsage()", () => {
  it("writes every required column", async () => {
    await writeUsage(env.DB, {
      installId: "install-abc",
      date: "2026-08-20",
      endpoint: "chat",
      problemId: "vp-0001",
      turnIndex: 3,
      model: "openai/gpt-oss-120b",
      provider: "groq",
      inputTokens: 1200,
      outputTokens: 80,
      latencyMs: 900,
      leakBlocked: false,
      verdictOverridden: false,
    });

    const row = await env.DB.prepare(
      "SELECT * FROM usage WHERE install_id = ? AND date = ?",
    )
      .bind("install-abc", "2026-08-20")
      .first<Record<string, unknown>>();

    expect(row).toMatchObject({
      install_id: "install-abc",
      date: "2026-08-20",
      endpoint: "chat",
      problem_id: "vp-0001",
      turn_index: 3,
      model: "openai/gpt-oss-120b",
      provider: "groq",
      input_tokens: 1200,
      output_tokens: 80,
      latency_ms: 900,
      leak_blocked: 0,
      verdict_overridden: 0,
    });
    expect(row!.created_at).toEqual(expect.any(String));
  });

  it("a written row contains no learner key and no message content under any field (FR-023, FR-026)", async () => {
    await writeUsage(env.DB, {
      installId: "install-privacy-check",
      date: "2026-08-20",
      endpoint: "judge",
      problemId: "vp-0001",
      turnIndex: 5,
      model: "openai/gpt-oss-120b",
      provider: "groq",
      inputTokens: 6200,
      outputTokens: 300,
      latencyMs: 4000,
    });

    const row = await env.DB.prepare(
      "SELECT * FROM usage WHERE install_id = ?",
    )
      .bind("install-privacy-check")
      .first<Record<string, unknown>>();

    const serialised = JSON.stringify(row);
    expect(serialised).not.toContain(KNOWN_KEY);
    expect(serialised).not.toContain(MESSAGE_CONTENT);
  });

  it("leak_blocked and verdict_overridden default to 0 when omitted", async () => {
    await writeUsage(env.DB, {
      installId: "install-defaults",
      date: "2026-08-20",
      endpoint: "hint",
      problemId: "vp-0001",
      turnIndex: 1,
      model: "n/a",
      provider: "n/a",
      inputTokens: 0,
      outputTokens: 0,
      latencyMs: 5,
    });

    const row = await env.DB.prepare("SELECT * FROM usage WHERE install_id = ?")
      .bind("install-defaults")
      .first<Record<string, unknown>>();

    expect(row!.leak_blocked).toBe(0);
    expect(row!.verdict_overridden).toBe(0);
  });
});
