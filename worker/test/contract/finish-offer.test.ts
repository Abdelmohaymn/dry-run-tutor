import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  groqStreamBody,
  mintInstallId,
  readChatSSE,
} from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// Feature 005. The finish check runs alongside the tutor reply and reports
// on the meta frame; it never fails or delays the turn beyond its timeout.

async function setFinishOffer(overrides: Partial<{ enabled: boolean; min_turn: number; timeout_ms: number }> = {}) {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{ payload: string }>();
  const cfg = JSON.parse(row!.payload);
  cfg.finish_offer = { enabled: true, min_turn: 1, timeout_ms: 8000, ...overrides };
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1").bind(JSON.stringify(cfg)).run();
}

const isStream = (body: string) => JSON.parse(body).stream === true;

function mockTutor(text = "What would you look up?") {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST", body: isStream })
    .reply(200, groqStreamBody(text), { headers: { "content-type": "text/event-stream" } });
}

/** Captures the finish-check request body and replies with [reply]. */
function mockFinishCheck(reply: { status: number; body: unknown }, seen: { body?: any } = {}) {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST", body: (b: string) => !isStream(b) })
    .reply((opts) => {
      seen.body = JSON.parse(opts.body as string);
      return { statusCode: reply.status, data: JSON.stringify(reply.body), responseOptions: { headers: { "content-type": "application/json" } } };
    });
  return seen;
}

const LEARNER = "For each number I'd remember it with its index, and look up target minus the number to find its partner.";

async function chat(extra: Record<string, unknown> = {}, messages = [{ role: "user", text: LEARNER }]) {
  const res = await SELF.fetch("https://worker.test/v1/chat", {
    method: "POST",
    headers: { "X-Install-Id": await mintInstallId(), "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
    body: JSON.stringify({ problem_id: "vp-0001", messages, ...extra }),
  });
  expect(res.status).toBe(200);
  const frames = await readChatSSE(res);
  return frames.find((f) => f.event === "meta")!.data as Record<string, unknown>;
}

describe("finish offer — ready_to_finish on the meta frame", () => {
  it("is true when the check answers ready", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup","index_storage"]}') });
    expect((await chat()).ready_to_finish).toBe(true);
  });

  it("is false when the check answers not ready", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["single_pass"]}') });
    expect((await chat()).ready_to_finish).toBe(false);
  });

  it("is false, and the turn is still served, when the check fails", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 500, body: { error: "boom" } });
    const meta = await chat();
    expect(meta.ready_to_finish).toBe(false);
    expect(meta.turn_index).toBe(1);
  });

  it("sends the learner's turns only, never the tutor's, with a strict reached-keys schema", async () => {
    await setFinishOffer();
    mockTutor();
    const seen = mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["single_pass"]}') });
    await chat({}, [
      { role: "user", text: "Two loops over every pair?" },
      { role: "tutor", text: "TUTOR_ONLY_PHRASE about a lookup" },
      { role: "user", text: LEARNER },
    ]);
    const user = seen.body.messages.find((m: any) => m.role === "user").content as string;
    expect(user).toContain(LEARNER);
    expect(user).not.toContain("TUTOR_ONLY_PHRASE");
    const schema = seen.body.response_format.json_schema.schema;
    expect(schema.required).toEqual(["reached", "named"]);
    expect(schema.properties.reached.items.enum).toEqual(["complement_lookup", "single_pass", "index_storage", "duplicates_ok"]);
    expect(schema.properties.named.items.enum).toContain("hash map");
    expect(user).toContain("- hash map");
  });

  it.each([
    ["disabled in config", { enabled: false }],
    ["before min_turn", { min_turn: 2 }],
  ])("runs no check and leaves the field off when %s", async (_label, cfg) => {
    await setFinishOffer(cfg);
    mockTutor();
    const meta = await chat();
    expect(meta).not.toHaveProperty("ready_to_finish");
  });

  it("after Keep going, still checks (the leak filter needs the keys) but leaves the field off", async () => {
    await setFinishOffer();
    mockTutor();
    const seen = mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup","index_storage"]}') });
    const meta = await chat({ finish_offer_dismissed: true });
    expect(seen.body).toBeDefined();
    expect(meta).not.toHaveProperty("ready_to_finish");
  });

  it("drops keys the problem does not author", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup","made_up_key"]}') });
    expect((await chat()).ready_to_finish).toBe(false);
  });

  it("stores the reached keys, and the next turn stops blocking those insights' words", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    const send = async (messages: { role: string; text: string }[]) => {
      const res = await SELF.fetch("https://worker.test/v1/chat", {
        method: "POST",
        headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
        body: JSON.stringify({ problem_id: "vp-0001", messages }),
      });
      return readChatSSE(res);
    };

    // Turn 1: the check finds complement_lookup stated in the learner's own words.
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup"]}') });
    const turn1 = [{ role: "user", text: "for each number the partner is target minus it, I look it up fast" }];
    await send(turn1);
    const row = await env.DB.prepare("SELECT reached_keys FROM device_day WHERE device_hash = ?1").bind(installId.split(".")[0]).first<{ reached_keys: string }>();
    expect(JSON.parse(row!.reached_keys)).toEqual(["complement_lookup"]);

    // Turn 2: a reply naming "hash map" (complement_lookup's never_say) is
    // no longer blocked, though the learner never said the words.
    mockTutor("Yes -- a hash map does that. What does it need to hold?");
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":[]}') });
    const frames = await send([...turn1, { role: "tutor", text: "Yes. How?" }, { role: "user", text: "keep the seen ones somewhere" }]);
    const text = frames.filter((f) => f.event === "token").map((f) => (f.data as { text: string }).text).join("");
    expect(text).toContain("hash map");
  });

  // docs/tutor-focus-issues.md Issue 1: "DP" for dynamic programming, a
  // mangling, another language. The literal-word filter cannot tell; the
  // check can, and its answer unblocks the term from the next turn.
  it("stores the terms the check says the learner named, and the next turn's reply may use them", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    const send = async (messages: { role: string; text: string }[]) => {
      const res = await SELF.fetch("https://worker.test/v1/chat", {
        method: "POST",
        headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
        body: JSON.stringify({ problem_id: "vp-0001", messages }),
      });
      return readChatSSE(res);
    };

    // Turn 1: no literal never_say word, but the check recognises one.
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":[],"named":["hash map","not-a-term"]}') });
    const turn1 = [{ role: "user", text: "I'd keep a dictionary of what I have seen so far" }];
    await send(turn1);
    const row = await env.DB.prepare("SELECT named_terms, reached_keys FROM device_day WHERE device_hash = ?1")
      .bind(installId.split(".")[0])
      .first<{ named_terms: string; reached_keys: string | null }>();
    expect(JSON.parse(row!.named_terms)).toEqual(["hash map"]);
    // Naming a term is not having the idea.
    expect(row!.reached_keys).toBeNull();

    // Turn 2: the draft says "hash map". It is not blocked, so there is no
    // rewrite call (an unstubbed second tutor call would fail the test).
    mockTutor("Yes, a hash map fits. What would you store in it?");
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":[],"named":[]}') });
    const frames = await send([...turn1, { role: "tutor", text: "Go on." }, { role: "user", text: "the numbers I passed" }]);
    const text = frames.filter((f) => f.event === "token").map((f) => (f.data as { text: string }).text).join("");
    expect(text).toContain("hash map");
    const meta = frames.find((f) => f.event === "meta")!.data as Record<string, unknown>;
    expect(meta.leak_blocked).toBe(false);
    expect(meta.ready_to_finish).toBe(false);
  });

  it("never stores learner text in named_terms, even if the check echoes it back", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    const said = "MARKER_LEARNER_SAID_THIS_EXACT_PHRASE about a dictionary";
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody(JSON.stringify({ reached: [], named: [said, "hash map"] })) });
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: said }] }),
    });
    await readChatSSE(res);
    const rows = await env.DB.prepare("SELECT * FROM device_day WHERE device_hash = ?1").bind(installId.split(".")[0]).all();
    expect(JSON.stringify(rows.results)).not.toContain("MARKER_LEARNER_SAID");
    expect(JSON.parse((rows.results[0] as { named_terms: string }).named_terms)).toEqual(["hash map"]);
  });

  it("makes the finish-check call on the keyed path and reports it", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup","index_storage"]}') });
    const meta = await chat();
    expect(meta.ready_to_finish).toBe(true);
  });
});

describe("finish offer — trial path", () => {
  it("runs on the operator pool, spends the trial budget", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: groqCompletionBody('{"reached":["complement_lookup","index_storage"]}', { prompt_tokens: 300, completion_tokens: 40 }) });
    const date = new Date().toISOString().slice(0, 10);
    const before = await env.DB.prepare("SELECT COALESCE(SUM(tokens_spent),0) AS t FROM provider_day WHERE date = ?1").bind(date).first<{ t: number }>();

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": await mintInstallId(), "content-type": "application/json" },
      body: JSON.stringify({ mode: "chat", problem_id: "vp-0001", messages: [{ role: "user", text: LEARNER }] }),
    });
    const meta = (await readChatSSE(res)).find((f) => f.event === "meta")!.data as Record<string, unknown>;
    expect(meta.ready_to_finish).toBe(true);

    const after = await env.DB.prepare("SELECT COALESCE(SUM(tokens_spent),0) AS t FROM provider_day WHERE date = ?1").bind(date).first<{ t: number }>();
    // tutor turn (550) + finish check (340)
    expect(after!.t - before!.t).toBe(890);
  });
});
