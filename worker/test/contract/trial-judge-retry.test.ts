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

const CONVERSATION = [
  { role: "user", text: "I'd keep a map from each value to its index." },
  { role: "tutor", text: "And what do you look up?" },
  { role: "user", text: "Target minus the current number." },
];

const ASSESSMENT = JSON.stringify({
  matched_approach: "hashmap",
  matched_verdict: "optimal",
  insights_hit: ["complement_lookup"],
  insights_missed: [],
  wrong_turns_taken: [],
  complexity: { user_claimed_time: null, user_claimed_space: null, reference_time: "O(n)", reference_space: "O(n)", assessment: "not_stated" },
  verdict: "unclear",
  confidence: 0.5,
  feedback: "Some feedback here.",
});

function trial(installId: string, body: unknown) {
  return SELF.fetch("https://worker.test/v1/trial", {
    method: "POST",
    headers: { "X-Install-Id": installId, "content-type": "application/json" },
    body: JSON.stringify(body),
  });
}

async function setPoolExtras(extra: Record<string, unknown>) {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  const cfg = JSON.parse(row!.payload);
  cfg.trial.pool = cfg.trial.pool.map((m: any) => ({ ...m, structured_extra_body: extra }));
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();
}

describe("POST /v1/trial judge — after the session is already judged", () => {
  it("a retried judge for the same problem and day is SESSION_ALREADY_JUDGED, never TRIAL_CONSUMED", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("Go on."), { headers: { "content-type": "text/event-stream" } });
    await readChatSSE(await trial(installId, { mode: "chat", problem_id: "vp-0001", messages: [CONVERSATION[0]] }));

    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(200, groqCompletionBody(ASSESSMENT));
    const judge = { mode: "judge", problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" };
    expect((await trial(installId, judge)).status).toBe(200);

    const retry = await trial(installId, judge);
    expect(retry.status).toBe(409);
    expect(((await retry.json()) as any).error.code).toBe("SESSION_ALREADY_JUDGED");
  });

  it("a new chat after the judged session is still TRIAL_CONSUMED", async () => {
    const installId = await mintInstallId();
    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(200, groqCompletionBody(ASSESSMENT));
    expect((await trial(installId, { mode: "judge", problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" })).status).toBe(200);

    const res = await trial(installId, { mode: "chat", problem_id: "vp-0001", messages: [{ role: "user", text: "One more?" }] });
    expect(res.status).toBe(409);
    expect(((await res.json()) as any).error.code).toBe("TRIAL_CONSUMED");
  });
});

describe("judge request shape", () => {
  it("puts the conversation in the user message and applies the member's structured_extra_body", async () => {
    await setPoolExtras({ chat_template_kwargs: { enable_thinking: false } });
    const installId = await mintInstallId();
    let sent: any;
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply((opts) => {
        sent = JSON.parse(opts.body as string);
        return { statusCode: 200, data: JSON.stringify(groqCompletionBody(ASSESSMENT)), responseOptions: { headers: { "content-type": "application/json" } } };
      });
    expect((await trial(installId, { mode: "judge", problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" })).status).toBe(200);

    const system = sent.messages.find((m: any) => m.role === "system").content as string;
    const user = sent.messages.find((m: any) => m.role === "user").content as string;
    expect(user).toContain("Target minus the current number.");
    expect(system).not.toContain("Target minus the current number.");
    expect(sent.chat_template_kwargs).toEqual({ enable_thinking: false });
    expect(sent.model).toBeTypeOf("string");
  });

  it("never applies structured_extra_body to the tutor stream", async () => {
    await setPoolExtras({ chat_template_kwargs: { enable_thinking: false } });
    const installId = await mintInstallId();
    let sent: any;
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply((opts) => {
        sent = JSON.parse(opts.body as string);
        return { statusCode: 200, data: groqStreamBody("Go on."), responseOptions: { headers: { "content-type": "text/event-stream" } } };
      });
    await readChatSSE(await trial(installId, { mode: "chat", problem_id: "vp-0001", messages: [CONVERSATION[0]] }));
    expect(sent.stream).toBe(true);
    expect(sent).not.toHaveProperty("chat_template_kwargs");
  });
});

describe("judge retries once on a self-contradictory answer", () => {
  it("asks again when the optimal approach comes back with no insights, and keeps the consistent answer", async () => {
    const hollow = JSON.parse(ASSESSMENT);
    hollow.insights_hit = [];
    hollow.feedback = "...";
    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(200, groqCompletionBody(JSON.stringify(hollow)));
    fetchMock.get(GROQ_ORIGIN).intercept({ path: GROQ_CHAT_PATH, method: "POST" }).reply(200, groqCompletionBody(ASSESSMENT));

    const res = await trial(await mintInstallId(), { mode: "judge", problem_id: "vp-0001", conversation: CONVERSATION, ended_by: "user" });
    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.insights_hit).toEqual(["complement_lookup"]);
  });
});
