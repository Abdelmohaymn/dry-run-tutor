import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, interceptEvidenceCheck, mintInstallId, readChatSSE, interceptFinalCheckUnusable } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

const CONVERSATION = [{ role: "user", text: "I would use a hash map." }];

const ASSESSMENT = JSON.stringify({
  approach_quote: "I would use a hash map",
  matched_approach: "hashmap",
  matched_verdict: "optimal",
  insights_hit: [{ quote: "I would use a hash map", key: "complement_lookup" }],
  insights_missed: [],
  wrong_turns_taken: [],
  complexity: { user_claimed_time: null, user_claimed_space: null, reference_time: "O(n)", reference_space: "O(n)", assessment: "not_stated" },
  verdict: "unclear",
  confidence: 0.5,
  feedback: "Some feedback here.",
});

function interceptJudgeOnce() {
  interceptFinalCheckUnusable();
  fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(200, groqCompletionBody(ASSESSMENT));
  interceptEvidenceCheck();
}

function keyedJudge(installId: string) {
  return SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
    body: JSON.stringify({ problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" }),
  });
}

function trialJudge(installId: string) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "judge", problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" }),
  });
}

// A real trial session starts with a chat turn: that is what claims the
// device's taster slot (devices.trial_problem_id / trial_date).
async function startTrialSession(installId: string) {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqStreamBody("Go on."), { headers: { "content-type": "text/event-stream" } });
  const res = await SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "chat", problem_id: "vp-0001", messages: CONVERSATION }),
  });
  await readChatSSE(res);
}

function reset(installId: string, body: unknown = { problem_id: "vp-0001" }) {
  return SELF.fetch("https://worker.test/v1/session/reset", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function trialRow(installId: string) {
  return env.DB
    .prepare(
      `SELECT trial_sessions_done AS done, trial_problem_id AS problem, trial_day_sessions AS daySessions
         FROM devices WHERE device_hash = ?1`,
    )
    .bind(installId.split(".")[0]) // the install id is `<device_hash>.<sig>`
    .first<{ done: number; problem: string | null; daySessions: number }>();
}

// The app's recovery path for a verdict that was produced and lost on the
// way back: clear the claim, then judge the locally kept conversation again.
describe("POST /v1/session/reset", () => {
  it("rejects a malformed body", async () => {
    const res = await reset(await mintInstallId(), { nope: true });
    expect(res.status).toBe(400);
  });

  it("keyed: a judged session can be judged again after a reset", async () => {
    const installId = await mintInstallId();
    interceptJudgeOnce();
    expect((await keyedJudge(installId)).status).toBe(200);

    // No interceptor: a provider call on the refused judge fails the test.
    const refused = await keyedJudge(installId);
    expect(refused.status).toBe(409);
    expect(((await refused.json()) as any).error.code).toBe("SESSION_ALREADY_JUDGED");

    const res = await reset(installId, { problem_id: "vp-0001", reason: "recover" });
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });

    interceptJudgeOnce();
    expect((await keyedJudge(installId)).status).toBe(200);
  });

  it("recover keeps today's turn counters; practice clears them", async () => {
    const installId = await mintInstallId();
    const deviceHash = installId.split(".")[0];
    const date = new Date().toISOString().slice(0, 10);
    await env.DB
      .prepare(
        `INSERT INTO device_day (device_hash, problem_id, date, turns, judged_at)
         VALUES (?1, 'vp-0001', ?2, 5, '2026-01-01T00:00:00Z')`,
      )
      .bind(deviceHash, date)
      .run();
    const row = () =>
      env.DB
        .prepare("SELECT turns, judged_at FROM device_day WHERE device_hash = ?1 AND problem_id = 'vp-0001'")
        .bind(deviceHash)
        .first<{ turns: number; judged_at: string | null }>();

    expect((await reset(installId, { problem_id: "vp-0001", reason: "recover" })).status).toBe(200);
    expect(await row()).toEqual({ turns: 5, judged_at: null });

    expect((await reset(installId, { problem_id: "vp-0001", reason: "practice" })).status).toBe(200);
    expect(await row()).toBeNull();
  });

  it("rejects an unknown reason", async () => {
    const res = await reset(await mintInstallId(), { problem_id: "vp-0001", reason: "replay" });
    expect(res.status).toBe(400);
  });

  it("trial: a recover reset lets the same session be judged again without using up another trial session", async () => {
    const installId = await mintInstallId();
    await startTrialSession(installId);
    interceptJudgeOnce();
    expect((await trialJudge(installId)).status).toBe(200);
    const before = await trialRow(installId);
    expect(before?.problem).toBe("vp-0001");

    expect((await reset(installId, { problem_id: "vp-0001", reason: "recover" })).status).toBe(200);

    // The canned judge reply leaves the pool member in its 60 s cooldown
    // (judge-core treats it as unusable); that is the pool's business, not
    // the reset's, so lift it before the second provider call.
    await env.DB.prepare("UPDATE provider_day SET cooldown_until = NULL").run();
    interceptJudgeOnce();
    expect((await trialJudge(installId)).status).toBe(200);
    const after = await trialRow(installId);
    expect(after?.problem).toBe("vp-0001");
    expect(after?.done).toBe(before?.done);
    expect(after?.daySessions).toBe(before?.daySessions);
  });

  it("trial: a practice reset retires the session and counts it", async () => {
    const installId = await mintInstallId();
    await startTrialSession(installId);
    interceptJudgeOnce();
    expect((await trialJudge(installId)).status).toBe(200);
    const before = await trialRow(installId);

    expect((await reset(installId)).status).toBe(200);

    const after = await trialRow(installId);
    expect(after?.problem).toBeNull();
    expect(after?.done).toBe((before?.done ?? 0) + 1);
  });
});
