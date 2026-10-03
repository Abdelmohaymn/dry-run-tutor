import { env } from "cloudflare:test";
import { describe, expect, it, vi } from "vitest";
import { condense } from "../../src/lib/condense";
import { getRuntimeConfig } from "../../src/lib/runtime-config";
import type { Provider, StructuredCompletionParams } from "../../src/lib/provider";
import type { Turn } from "../../src/lib/schemas";

// SC-007a: cumulative condensation INPUT tokens must grow linearly with
// turn count, never quadratically. Proven precisely rather than by eyeballing
// a curve: replaying a 15-turn session, every turn that ever falls out of
// the verbatim window must be condensed EXACTLY ONCE across the whole
// session. If that holds, total cost is bounded by a constant factor times
// the turn count by construction — the only way to violate linearity here
// would be re-sending an already-condensed turn on a later call.

function turn(i: number): Turn {
  return { role: "user", text: `TURN_MARKER_${i}` };
}

function countTurnMarkers(text: string): number {
  return (text.match(/TURN_MARKER_\d+/g) ?? []).length;
}

describe("condense() cumulative cost is linear in turn count (SC-007a)", () => {
  it("each overflowing turn is condensed exactly once across a 15-turn session", async () => {
    const cfg = await getRuntimeConfig(env.DB);
    const K = cfg.trim.verbatim_turns;

    const seenMarkersAcrossCalls: string[] = [];
    const provider: Provider = {
      streamChat: vi.fn(),
      structuredCompletion: vi.fn(async (params: StructuredCompletionParams) => {
        const markers = params.userContent.match(/TURN_MARKER_\d+/g) ?? [];
        seenMarkersAcrossCalls.push(...markers);
        return { text: `summary covering ${markers.length} turns`, usage: { inputTokens: params.userContent.length, outputTokens: 20 } };
      }),
    };

    let summary: string | undefined;
    let clientMessages: Turn[] = [];
    let callCount = 0;
    let totalFallingTurnsProcessed = 0;

    for (let n = 1; n <= 15; n++) {
      // The app holds only the turns not covered by `summary` and replays
      // both on the next request — exactly what data-model.md §A2 describes.
      clientMessages = [...clientMessages, turn(n)];
      const result = await condense(
        summary,
        clientMessages,
        cfg,
        provider,
        { baseUrl: "https://example.test", apiKey: "k", model: "test-condense-model" },
        { db: env.DB, installId: "install-linear", problemId: "vp-0001", date: "2026-08-20", turnIndex: n },
      );
      if (result.called) {
        callCount += 1;
        summary = result.summary;
      }
      clientMessages = result.verbatim;
    }

    // Every marker that was ever sent to the provider is sent exactly once —
    // no turn is re-condensed on a later call.
    const counts = new Map<string, number>();
    for (const marker of seenMarkersAcrossCalls) {
      counts.set(marker, (counts.get(marker) ?? 0) + 1);
    }
    for (const [marker, count] of counts) {
      expect(count, `marker ${marker} was condensed ${count} times, expected exactly 1`).toBe(1);
    }

    totalFallingTurnsProcessed = seenMarkersAcrossCalls.length;
    // Exactly the turns that ever fell out of the K-wide verbatim window,
    // each counted once. A quadratic re-send would inflate this well past
    // 15 - K; a linear windowing scheme lands exactly on it.
    expect(totalFallingTurnsProcessed).toBe(15 - K);
    expect(callCount).toBeGreaterThan(0);
  });
});
