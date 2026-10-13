import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  interceptEvidenceCheck,
  groqStreamBody,
  mintInstallId,
  readChatSSE,
  setRepairConfig,
  interceptFinalCheckUnusable,
} from "./helpers";

const GEMINI_ORIGIN = "https://generativelanguage.googleapis.com";
const GEMINI_CHAT_PATH = "/v1beta/openai/chat/completions";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function offerBothProviders() {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  const cfg = JSON.parse(row!.payload);
  cfg.keyed_providers = ["groq", "gemini"];
  cfg.providers = { gemini: { model: "gemini-flash-latest", condense_model: "gemini-flash-latest" } };
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();
  return cfg;
}

function sendChat(installId: string, provider?: string) {
  const headers: Record<string, string> = {
    "X-Install-Id": installId,
    "X-User-Key": "learner_key_for_that_provider",
    "content-type": "application/json",
  };
  if (provider !== undefined) headers["X-Provider"] = provider;
  return SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers,
    body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "I would use nested loops." }] }),
  });
}

function sendJudge(installId: string, provider?: string) {
  const headers: Record<string, string> = {
    "X-Install-Id": installId,
    "X-User-Key": "learner_key_for_that_provider",
    "content-type": "application/json",
  };
  if (provider !== undefined) headers["X-Provider"] = provider;
  return SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers,
    body: JSON.stringify({
      problem_id: "vp-0001",
      ended_by: "user",
      conversation: [{ role: "user", text: "I would use a hash map." }],
    }),
  });
}

// FR-008b. The learner picks the provider by picking which key to paste, so a
// single global cfg.provider cannot serve everyone: it sent a Gemini key to
// Groq, and the misroute surfaced as "your key was rejected".
describe("POST /v1/chat and /v1/judge — routed by the key's own provider", () => {
  it("routes the turn to the named provider's host, not the configured default", async () => {
    await offerBothProviders();
    const installId = await mintInstallId();

    // Only Gemini is mocked. A request to Groq fails the test outright.
    fetchMock
      .get(GEMINI_ORIGIN)
      .intercept({ path: GEMINI_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        expect(JSON.parse(opts.body as string).model).toBe("gemini-flash-latest");
        return groqStreamBody("Routed to Gemini.");
      }, { headers: { "content-type": "text/event-stream" } });

    const res = await sendChat(installId, "gemini");
    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    expect(frames.find((f) => f.event === "token")!.data).toEqual({ text: "Routed to Gemini." });
  });

  it("falls back to the configured provider when the app names none", async () => {
    await offerBothProviders();
    const installId = await mintInstallId();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("Routed to the default."), { headers: { "content-type": "text/event-stream" } });

    const res = await sendChat(installId);
    expect(res.status).toBe(200);
    await readChatSSE(res);
  });

  it("refuses an unknown provider instead of quietly relaying the key to the default", async () => {
    await offerBothProviders();
    const installId = await mintInstallId();

    // No interceptor: reaching any provider fails the test. A silent fallback
    // would send this learner's key to a host it does not belong to.
    const res = await sendChat(installId, "not-a-provider");
    expect(res.status).toBe(400);
    expect(((await res.json()) as any).error.code).toBe("BAD_REQUEST");
  });

  it("refuses a real provider the operator has not offered for key entry", async () => {
    const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
    const cfg = JSON.parse(row!.payload);
    cfg.keyed_providers = ["groq"];
    await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();

    const res = await sendChat(await mintInstallId(), "gemini");
    expect(res.status).toBe(400);
  });

  it("routes the assessment by the same rule, and sends the provider's own model", async () => {
    await offerBothProviders();
    const installId = await mintInstallId();

    let judgeBody = "";
    interceptFinalCheckUnusable({ origin: GEMINI_ORIGIN, path: GEMINI_CHAT_PATH });
    fetchMock
      .get(GEMINI_ORIGIN)
      .intercept({ path: GEMINI_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        judgeBody = opts.body as string;
        return groqCompletionBody(JSON.stringify({
        approach_quote: "I would use a hash map",
        matched_approach: "hashmap",
        matched_verdict: "optimal",
        insights_hit: [{ quote: "I would use a hash map", key: "complement_lookup" }],
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
        }));
      });
    interceptEvidenceCheck(true, { origin: GEMINI_ORIGIN, path: GEMINI_CHAT_PATH });

    expect((await sendJudge(installId, "gemini")).status).toBe(200);
    expect(JSON.parse(judgeBody).model).toBe("gemini-flash-latest");
  });

  it("ignores the header on /v1/trial — a learner cannot steer the operator's credential", async () => {
    await offerBothProviders();
    const installId = await mintInstallId();

    // The pool is seeded with Groq only. If X-Provider were honoured here, a
    // learner could aim the OPERATOR's key at a host of their choosing.
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("Pool decided, not the caller."), { headers: { "content-type": "text/event-stream" } });

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-Provider": "gemini", "content-type": "application/json" },
      body: JSON.stringify({ mode: "chat", problem_id: "vp-0001", messages: [{ role: "user", text: "nested loops" }] }),
    });
    expect(res.status).toBe(200);
    await readChatSSE(res);
  });

  it("/v1/repair uses providers[id].repair_model when set, and repair.model when not", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();
    const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
      payload: string;
    }>();
    const cfg = JSON.parse(row!.payload);
    cfg.providers = cfg.providers ?? {};
    cfg.providers.groq = { ...(cfg.providers.groq ?? {}), repair_model: "groq-repair-override" };
    await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        expect(JSON.parse(opts.body as string).model).toBe("groq-repair-override");
        return groqCompletionBody("I would use two pointers here to scan through the whole list of values");
      });

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: "I would use too pointers here to scan through the whole list of values" }),
    });
    expect(res.status).toBe(200);
  });

  it("/v1/repair falls back to repair.model when the provider has no repair_model override", async () => {
    const installId = await mintInstallId();
    await setRepairConfig({ model: "repair-default-model" });

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, (opts) => {
        expect(JSON.parse(opts.body as string).model).toBe("repair-default-model");
        return groqCompletionBody("I would use two pointers here to scan through the whole list of values");
      });

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: "I would use too pointers here to scan through the whole list of values" }),
    });
    expect(res.status).toBe(200);
  });
});
