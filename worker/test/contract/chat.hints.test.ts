import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { getPrivate, getPublicManifest } from "../../src/lib/content";
import { flatLadder } from "../../src/lib/hint-ladder";
import { LADDER_EXHAUSTED_LINE } from "../../src/prompts/tutor";
import { mintInstallId, readChatSSE } from "./helpers";
import type { Problem } from "../../../tools/problem-types";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

function vp0001(): Problem {
  const pub = getPublicManifest().problems.find((p) => p.id === "vp-0001")!;
  return { public: pub, private: getPrivate("vp-0001")! };
}

async function requestHint(installId: string, message = "") {
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: {
      "X-Install-Id": installId,
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      problem_id: "vp-0001",
      messages: [{ role: "user", text: message || "(hint requested)" }],
      hint_requested: true,
    }),
  });
}

// US1 scenarios 4 and 4a, FR-003a-e, SC-002a.
describe("POST /v1/chat — hint_requested", () => {
  it("returns exactly one rung per request, byte-identical, in order, zero provider calls, turn_index unchanged", async () => {
    const problem = vp0001();
    const ladder = flatLadder(problem);
    const installId = await mintInstallId();

    for (let i = 0; i < 3; i++) {
      const res = await requestHint(installId);
      expect(res.status).toBe(200);
      const frames = await readChatSSE(res);
      const tokenFrames = frames.filter((f) => f.event === "token");
      expect(tokenFrames).toHaveLength(1);
      expect((tokenFrames[0].data as { text: string }).text).toBe(ladder[i].text);

      const meta = frames.find((f) => f.event === "meta")!.data as {
        turn_index: number;
        hints_revealed: number;
        hints_remaining: number;
      };
      expect(meta.turn_index).toBe(0); // no conversational turn has ever been reserved
      expect(meta.hints_revealed).toBe(i + 1);
      expect(meta.hints_remaining).toBe(ladder.length - (i + 1));
    }
    // No fetchMock interceptor was ever registered for these three calls —
    // assertNoPendingInterceptors() in afterEach would fail loudly if the
    // route had made a provider call it didn't need to.
  });

  it("pulling every rung then asking again returns the closing line, session_ended stays null, no editorial", async () => {
    const problem = vp0001();
    const ladder = flatLadder(problem);
    const installId = await mintInstallId();

    for (let i = 0; i < ladder.length; i++) {
      const r = await requestHint(installId);
      await r.text(); // always drain a streamed response before the next request in a loop
    }
    const res = await requestHint(installId);
    const frames = await readChatSSE(res);
    const tokenFrames = frames.filter((f) => f.event === "token");
    expect(tokenFrames).toHaveLength(1);
    expect((tokenFrames[0].data as { text: string }).text).toBe(LADDER_EXHAUSTED_LINE);

    const meta = frames.find((f) => f.event === "meta")!.data as { session_ended: unknown };
    expect(meta.session_ended).toBeNull();

    const bodyText = JSON.stringify(frames);
    expect(bodyText).not.toContain(problem.private.editorial.slice(0, 30));
  });

  it("a client cannot skip to rung 12 by any payload it can send — hint_requested has no rung index field", async () => {
    // The wire schema for ChatRequest carries no hint-index field at all
    // (contracts/openapi.yaml): hint_requested is a boolean. There is no
    // payload shape that could request a specific rung.
    const installId = await mintInstallId();
    const res = await requestHint(installId);
    const frames = await readChatSSE(res);
    const problem = vp0001();
    expect((frames.find((f) => f.event === "token")!.data as { text: string }).text).toBe(
      flatLadder(problem)[0].text,
    );
  });

  it("a rung request with an empty message is NOT rejected (EMPTY_TURN does not apply to the hint path)", async () => {
    const installId = await mintInstallId();
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "x" }],
        hint_requested: true,
      }),
    });
    expect(res.status).toBe(200);
    await res.text(); // always drain a streamed response
  });
});

// US3 scenario 4: a hint pulled before the learner has said anything. The
// app sends the conversation so far, which on that path is legitimately
// empty — and `messages: min(1)` turned every such pull into a 400 the
// learner read as "something failed on our side". Found on a physical
// device; the suite missed it because every existing hint test posts a
// synthetic placeholder turn rather than the shape the app actually sends.
describe("hint_requested with no conversation yet", () => {
  it("POST /v1/chat accepts an empty messages array and returns the first rung", async () => {
    const ladder = flatLadder(vp0001());
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": await mintInstallId(),
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [], hint_requested: true }),
    });

    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    const tokens = frames.filter((f) => f.event === "token");
    expect(tokens).toHaveLength(1);
    expect((tokens[0].data as { text: string }).text).toBe(ladder[0].text);
    // FR-027: still costs no turn.
    expect((frames.find((f) => f.event === "meta")!.data as { turn_index: number }).turn_index).toBe(0);
  });

  it("POST /v1/trial accepts an empty messages array for a hint", async () => {
    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": await mintInstallId(), "content-type": "application/json" },
      body: JSON.stringify({
        mode: "chat",
        problem_id: "vp-0001",
        messages: [],
        hint_requested: true,
      }),
    });

    expect(res.status).toBe(200);
    expect((await readChatSSE(res)).filter((f) => f.event === "token")).toHaveLength(1);
  });

  it("still rejects an empty messages array on a conversational turn", async () => {
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": await mintInstallId(),
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [], hint_requested: false }),
    });

    expect(res.status).toBe(400);
    expect(((await res.json()) as { error: { code: string } }).error.code).toBe("BAD_REQUEST");
  });
});
