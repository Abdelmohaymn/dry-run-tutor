import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

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

// FR-032, SC-010. The regression net for migrations/0002_trial_session_identity.sql:
// before it, completed_at IS NULL alone meant "in flight", and since completed_at
// is written only after a SUCCESSFUL mode=judge, an abandoned session stayed in
// flight for good — a fresh trial.turn_cap on every new problem_id, and the
// new-session budget gate skipped every time.
describe("POST /v1/trial — the taster is one session, not one open row", () => {
  it("an ABANDONED session does not license a second one on another problem", async () => {
    const installId = await mintInstallId();

    mockChatReply("First reply.");
    const started = await trialChat(installId, "vp-0001", "I could use two nested loops.");
    expect(started.status).toBe(200);
    await readChatSSE(started);

    // The learner walks away — no judge call, so completed_at stays NULL.
    // No interceptor is registered below: reaching the provider fails the test,
    // which is the point. This must be refused before any credential is spent.
    const second = await trialChat(installId, "vp-0002", "a whole new problem");
    const body = (await second.json()) as any;
    expect(body.error.code).toBe("TRIAL_CONSUMED");
    expect(second.status).toBe(409);
  });

  it("the session already in flight still runs to its end on its own problem", async () => {
    const installId = await mintInstallId();

    mockChatReply("First reply.");
    await readChatSSE(await trialChat(installId, "vp-0001", "I could use two nested loops."));

    mockChatReply("Second reply.");
    const turn2 = await trialChat(installId, "vp-0001", "Quadratic, so too slow.");
    expect(turn2.status).toBe(200);
    const meta = (await readChatSSE(turn2)).find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta.turn_index).toBe(2);
  });

  it("a COMPLETED session refuses a second one, on the same problem or any other", async () => {
    const installId = await mintInstallId();

    mockChatReply("First reply.");
    await readChatSSE(await trialChat(installId, "vp-0001", "I could use two nested loops."));

    mockJudgeReply();
    expect((await trialJudge(installId, "vp-0001")).status).toBe(200);

    const sameProblem = await trialChat(installId, "vp-0001", "one more");
    expect(((await sameProblem.json()) as any).error.code).toBe("TRIAL_CONSUMED");

    const otherProblem = await trialChat(installId, "vp-0002", "a whole new problem");
    expect(((await otherProblem.json()) as any).error.code).toBe("TRIAL_CONSUMED");
    expect(otherProblem.status).toBe(409);
  });

  it("a first trial call the provider never answered does not forfeit the taster", async () => {
    const installId = await mintInstallId();

    // A 500 is not a pool routing signal, so it surfaces straight to the
    // caller with no member cooled down and nothing served.
    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(500, { error: "boom" });
    const failed = await trialChat(installId, "vp-0001", "I could use two nested loops.");
    expect((await readChatSSE(failed))[0].event).toBe("error");

    // The taster is untouched, so it is still spendable — including on a
    // DIFFERENT problem, which is the case the (problem_id, date) pin would
    // otherwise forfeit over a transient upstream fault (Constitution VIII).
    mockChatReply("First reply.");
    const elsewhere = await trialChat(installId, "vp-0002", "let me try this one instead");
    expect(elsewhere.status).toBe(200);
    const meta = (await readChatSSE(elsewhere)).find((f) => f.event === "meta")!.data as {
      turn_index: number;
      turns_remaining: number;
    };
    expect(meta.turn_index).toBe(1);
    expect(meta.turns_remaining).toBe(5); // the trial's own 6-turn profile, first turn spent

    // ...and that second attempt is now the one session it has.
    const third = await trialChat(installId, "vp-0003", "and now a third");
    expect(((await third.json()) as any).error.code).toBe("TRIAL_CONSUMED");
  });
});
