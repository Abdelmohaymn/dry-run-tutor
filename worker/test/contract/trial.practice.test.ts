import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const PRACTICE = "vp-0000";

function trialChat(installId: string, problemId: string, text: string) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "chat", problem_id: problemId, messages: [{ role: "user", text }] }),
  });
}

function mockChatReply(text = "How much work does that do as the list grows?") {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqStreamBody(text), { headers: { "content-type": "text/event-stream" } });
}

/** `mintInstallId()` hands back `<device_hash>.<hmac>`; the tables key on the hash. */
function bare(installId: string): string {
  return installId.split(".")[0];
}

async function practiceTurnsOf(installId: string): Promise<number | null> {
  const row = await env.DB.prepare("SELECT practice_turns FROM devices WHERE device_hash = ?1")
    .bind(bare(installId))
    .first<{ practice_turns: number }>();
  return row?.practice_turns ?? null;
}

// The walkthrough is a real conversation drawn from the taster's own
// allowance (migrations/0003). Two properties carry the whole design, and
// neither is visible from the client:
//
//   1. practice does not CLAIM the taster — today's real problem is still
//      there afterwards, which is the entire reason the walkthrough is not
//      just another problem_id;
//   2. practice cannot be FARMED — 0002's note explains why a per-(problem,
//      date) counter cannot bound it: it renews every day.
describe("POST /v1/trial — the onboarding walkthrough", () => {
  it("runs a real turn against the warm-up and counts it on the taster row", async () => {
    const installId = await mintInstallId();
    mockChatReply();

    const res = await trialChat(installId, PRACTICE, "I would sort it and take the last one.");

    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    expect(frames.some((f) => f.event === "token")).toBe(true);
    expect(await practiceTurnsOf(installId)).toBe(1);
  });

  it("leaves the taster unclaimed — today's real problem still runs afterwards", async () => {
    const installId = await mintInstallId();
    mockChatReply();
    await readChatSSE(await trialChat(installId, PRACTICE, "I would walk the list once."));

    // The row exists, but names no problem and no day: the taster is intact.
    const row = await env.DB.prepare(
      "SELECT trial_problem_id AS problem_id, trial_date AS date, trial_completed_at AS completed_at FROM devices WHERE device_hash = ?1",
    )
      .bind(bare(installId))
      .first<{ problem_id: string | null; date: string | null; completed_at: string | null }>();
    expect(row?.problem_id).toBeNull();
    expect(row?.completed_at).toBeNull();

    mockChatReply();
    const real = await trialChat(installId, "vp-0001", "I would use a hash map.");
    expect(real.status).toBe(200);
    // Drained: an unconsumed SSE body outlives the test and trips the
    // pool's isolated-storage check.
    await readChatSSE(real);

    // And the real session claimed it, on the same row.
    const after = await env.DB.prepare(
      "SELECT trial_problem_id AS problem_id, practice_turns FROM devices WHERE device_hash = ?1",
    )
      .bind(bare(installId))
      .first<{ problem_id: string | null; practice_turns: number }>();
    expect(after?.problem_id).toBe("vp-0001");
    expect(after?.practice_turns).toBe(1);
  });

  it("is bounded for the life of the install, not per day", async () => {
    const installId = await mintInstallId();

    // Spend the cap (5).
    for (let i = 0; i < 5; i++) {
      mockChatReply();
      const res = await trialChat(installId, PRACTICE, `Turn number ${i + 1} of the walkthrough.`);
      expect(res.status).toBe(200);
      await readChatSSE(res);
    }
    expect(await practiceTurnsOf(installId)).toBe(5);

    // A sixth is refused with no provider call at all — the missing
    // mockChatReply() here is the assertion, via assertNoPendingInterceptors.
    const sixth = await trialChat(installId, PRACTICE, "One more turn please.");
    expect(sixth.status).toBe(409);
    expect(((await sixth.json()) as any).error.code).toBe("TRIAL_CONSUMED");

    // device_day rolls over daily; this row does not, so tomorrow is the
    // same refusal. Clearing the per-(problem, date) counter proves the
    // bound is not coming from there.
    await env.DB.prepare("DELETE FROM device_day WHERE device_hash = ?1").bind(bare(installId)).run();
    const tomorrow = await trialChat(installId, PRACTICE, "Trying again on a new day.");
    expect(tomorrow.status).toBe(409);
    expect(((await tomorrow.json()) as any).error.code).toBe("TRIAL_CONSUMED");
  });

  it("refuses to judge the warm-up — the walkthrough has no Finish", async () => {
    const installId = await mintInstallId();

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": installId, "content-type": "application/json" },
      body: JSON.stringify({
        mode: "judge",
        problem_id: PRACTICE,
        ended_by: "user",
        conversation: [{ role: "user", text: "I would walk the list once." }],
      }),
    });

    expect(res.status).toBe(400);
    expect(await practiceTurnsOf(installId)).toBe(0);
  });
});
