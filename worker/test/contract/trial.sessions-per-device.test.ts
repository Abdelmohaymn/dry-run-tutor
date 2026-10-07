import { SELF, env, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

/** Sets trial.sessions_per_device on the stored config row (absent = default 1). */
async function setSessionsPerDevice(n: number | undefined): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  const cfg = JSON.parse(row!.payload);
  if (n === undefined) delete cfg.trial.sessions_per_device;
  else cfg.trial.sessions_per_device = n;
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();
}

function trialChat(installId: string, problemId: string, text: string) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "chat", problem_id: problemId, messages: [{ role: "user", text }] }),
  });
}

function trialJudge(installId: string, problemId: string) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({
      mode: "judge",
      problem_id: problemId,
      ended_by: "user",
      conversation: [{ role: "user", text: "I would use a hash map." }],
    }),
  });
}

function mockChatReply(text = "Let's think this through.") {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqStreamBody(text), { headers: { "content-type": "text/event-stream" } });
}

function mockJudgeReply() {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(
      200,
      groqCompletionBody(
        JSON.stringify({
          matched_approach: "hashmap",
          matched_verdict: "optimal",
          insights_hit: [],
          insights_missed: [],
          wrong_turns_taken: [],
          complexity: {
            user_claimed_time: null,
            user_claimed_space: null,
            reference_time: "O(n)",
            reference_space: "O(n)",
            assessment: "not_stated",
          },
          verdict: "unclear",
          confidence: 0.5,
          feedback: "Some feedback here.",
        }),
      ),
    );
}

/**
 * The judge mock used across the trial tests leaves the pool member in its
 * 60 s cooldown (judge-core treats the canned reply as an unusable answer
 * and routes around the member). That is the pool's business, not this
 * lever's, so a test that goes on to a SECOND provider call lifts it.
 */
async function clearPoolCooldown(): Promise<void> {
  await env.DB.prepare("UPDATE provider_day SET cooldown_until = NULL").run();
}

/** The install id is `<device_hash>.<sig>`; the devices row is keyed by the hash. */
async function sessionsDone(installId: string): Promise<number> {
  const row = await env.DB.prepare("SELECT trial_sessions_done AS n FROM devices WHERE device_hash = ?1")
    .bind(installId.split(".")[0])
    .first<{ n: number }>();
  return row?.n ?? 0;
}

async function expectConsumed(res: Response): Promise<void> {
  expect(((await res.json()) as any).error.code).toBe("TRIAL_CONSUMED");
  expect(res.status).toBe(409);
}

// trial.sessions_per_device (migration 0008). The slot on `devices` is the
// CURRENT session; trial_sessions_done counts the ones retired out of it.
describe("POST /v1/trial — trial.sessions_per_device", () => {
  it("with the lever absent a device still gets exactly one session", async () => {
    await setSessionsPerDevice(undefined);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));

    await expectConsumed(await trialChat(installId, "vp-0002", "another problem"));
    expect(await sessionsDone(installId)).toBe(0);
  });

  it("2 lets an abandoned session be followed by a second, and refuses the third", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply("First.");
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));

    mockChatReply("Second.");
    const second = await trialChat(installId, "vp-0002", "second problem");
    expect(second.status).toBe(200);
    const meta = (await readChatSSE(second)).find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(1); // a fresh session, not a continuation
    expect(await sessionsDone(installId)).toBe(1);

    await expectConsumed(await trialChat(installId, "vp-0003", "third problem"));
    expect(await sessionsDone(installId)).toBe(1);
  });

  it("2: a judged session is followed by a second, whose own judge call is not 'already judged'", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));
    mockJudgeReply();
    expect((await trialJudge(installId, "vp-0001")).status).toBe(200);
    await clearPoolCooldown();

    mockChatReply("Second.");
    expect((await trialChat(installId, "vp-0002", "second problem")).status).toBe(200);

    mockJudgeReply();
    expect((await trialJudge(installId, "vp-0002")).status).toBe(200);

    await expectConsumed(await trialChat(installId, "vp-0003", "third problem"));
  });

  it("2: the session in flight keeps running on its own problem and uses no extra session", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));

    mockChatReply("Second turn.");
    const turn2 = await trialChat(installId, "vp-0001", "still the first problem");
    const meta = (await readChatSSE(turn2)).find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(2);
    expect(await sessionsDone(installId)).toBe(0);
  });

  it("2: a finished session can't be replayed on the same problem and day", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));
    mockJudgeReply();
    expect((await trialJudge(installId, "vp-0001")).status).toBe(200);

    await expectConsumed(await trialChat(installId, "vp-0001", "again"));

    const again = await trialJudge(installId, "vp-0001");
    expect(((await again.json()) as any).error.code).toBe("SESSION_ALREADY_JUDGED");
  });

  it("2: a second session the provider never answered does not spend it", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));

    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(500, { error: "boom" });
    const failed = await trialChat(installId, "vp-0002", "second problem");
    expect((await readChatSSE(failed))[0].event).toBe("error");

    // The failed start was released, so one session is still available...
    mockChatReply("Second, for real.");
    expect((await trialChat(installId, "vp-0003", "third problem, first served")).status).toBe(200);

    // ...and only one.
    await expectConsumed(await trialChat(installId, "vp-0001", "back to the first problem"));
  });

  it("lowering the lever back to 1 takes effect on the next request", async () => {
    await setSessionsPerDevice(2);
    const installId = await mintInstallId();

    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0001", "first problem"));
    mockChatReply();
    await readChatSSE(await trialChat(installId, "vp-0002", "second problem"));

    await setSessionsPerDevice(1);
    await expectConsumed(await trialChat(installId, "vp-0003", "third problem"));
  });
});
