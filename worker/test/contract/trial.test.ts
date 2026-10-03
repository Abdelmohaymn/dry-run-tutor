import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, groqStreamBody, mintInstallId, readChatSSE } from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function sendTrialChat(installId: string, messages: { role: "user" | "tutor"; text: string }[], extra: Record<string, unknown> = {}) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "chat", problem_id: "vp-0001", messages, ...extra }),
  });
}

async function sendTrialJudge(installId: string, conversation: { role: "user" | "tutor"; text: string }[]) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify({ mode: "judge", problem_id: "vp-0001", conversation, ended_by: "user" }),
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

// US5 scenario 1, FR-031, FR-032.
describe("POST /v1/trial — one complete session, no learner key", () => {
  it("a fresh install gets a complete multi-turn session including assessment and reveal, and turn 2 is not refused", async () => {
    const installId = await mintInstallId();

    mockChatReply("First reply.");
    const turn1 = await sendTrialChat(installId, [{ role: "user", text: "I would use a hash map." }]);
    expect(turn1.status).toBe(200);
    const frames1 = await readChatSSE(turn1);
    const meta1 = frames1.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta1.turn_index).toBe(1);

    mockChatReply("Second reply.");
    const turn2 = await sendTrialChat(installId, [
      { role: "user", text: "I would use a hash map." },
      { role: "tutor", text: "First reply." },
      { role: "user", text: "Because lookups are O(1)." },
    ]);
    expect(turn2.status).toBe(200);
    const frames2 = await readChatSSE(turn2);
    const meta2 = frames2.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta2.turn_index).toBe(2);

    mockJudgeReply();
    const judged = await sendTrialJudge(installId, [{ role: "user", text: "I would use a hash map." }]);
    expect(judged.status).toBe(200);
    const assessment = (await judged.json()) as any;
    expect(typeof assessment.editorial).toBe("string");
  });

  // T096: usage.provider is the pool member's id, so
  // SELECT provider, SUM(input_tokens+output_tokens) ... GROUP BY provider
  // answers "how much of whose allowance did we spend today" (SC-010a).
  it("usage rows for the trial carry endpoint trial_chat/trial_judge and provider = the pool member id", async () => {
    const installId = await mintInstallId();
    const bareInstallId = installId.split(".")[0];

    mockChatReply();
    const turn1 = await sendTrialChat(installId, [{ role: "user", text: "hash map idea" }]);
    await turn1.text();

    mockJudgeReply();
    const judged = await sendTrialJudge(installId, [{ role: "user", text: "hash map idea" }]);
    await judged.json();

    const rows = await env.DB.prepare(
      "SELECT endpoint, provider FROM usage WHERE install_id = ?1 ORDER BY id",
    )
      .bind(bareInstallId)
      .all();
    const endpoints = rows.results.map((r: any) => r.endpoint);
    expect(endpoints).toContain("trial_chat");
    expect(endpoints).toContain("trial_judge");
    for (const row of rows.results as any[]) {
      expect(row.provider).toBe("groq");
    }
  });

  it("a second trial session after completion is refused 100% of the time (SC-010)", async () => {
    const installId = await mintInstallId();

    mockChatReply();
    const turn1 = await sendTrialChat(installId, [{ role: "user", text: "hash map idea" }]);
    await turn1.text();

    mockJudgeReply();
    const judged = await sendTrialJudge(installId, [{ role: "user", text: "hash map idea" }]);
    expect(judged.status).toBe(200);
    await judged.json();

    const secondChat = await sendTrialChat(installId, [{ role: "user", text: "starting again" }]);
    expect(secondChat.status).toBe(409);
    const body = (await secondChat.json()) as any;
    expect(body.error.code).toBe("TRIAL_CONSUMED");

    const secondJudge = await sendTrialJudge(installId, [{ role: "user", text: "starting again" }]);
    expect(secondJudge.status).toBe(409);
    const judgeBody = (await secondJudge.json()) as any;
    expect(judgeBody.error.code).toBe("TRIAL_CONSUMED");
  });

  it("an abandoned trial stops at cfg.trial.turn_cap turns (default 6)", async () => {
    const installId = await mintInstallId();
    let lastMeta: { turn_index: number } | undefined;

    for (let n = 1; n <= 6; n++) {
      mockChatReply(`reply ${n}`);
      const res = await sendTrialChat(installId, [{ role: "user", text: `turn ${n}` }]);
      const frames = await readChatSSE(res);
      lastMeta = frames.find((f) => f.event === "meta")!.data as { turn_index: number };
    }
    expect(lastMeta?.turn_index).toBe(6);

    const seventh = await sendTrialChat(installId, [{ role: "user", text: "turn 7" }]);
    expect(seventh.status).toBe(409);
    const body = (await seventh.json()) as any;
    expect(body.error.code).toBe("TURN_CAP_REACHED");
  });

  it("a hint pull as the very first trial action leaves the full session still available (US5 scenario 2a, FR-032a)", async () => {
    const installId = await mintInstallId();

    const hintRes = await sendTrialChat(installId, [{ role: "user", text: "hint please" }], { hint_requested: true });
    expect(hintRes.status).toBe(200);
    const hintFrames = await readChatSSE(hintRes);
    expect(hintFrames.find((f) => f.event === "token")).toBeDefined();

    mockChatReply();
    const turn1 = await sendTrialChat(installId, [{ role: "user", text: "now for real" }]);
    expect(turn1.status).toBe(200);
    const frames1 = await readChatSSE(turn1);
    const meta1 = frames1.find((f) => f.event === "meta")!.data as { turn_index: number };
    expect(meta1.turn_index).toBe(1);

    mockJudgeReply();
    const judged = await sendTrialJudge(installId, [{ role: "user", text: "now for real" }]);
    expect(judged.status).toBe(200);
    await judged.json();
  });
});
