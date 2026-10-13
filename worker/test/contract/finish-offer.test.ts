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

/** Like mockTutor, and records the request body (system prompt) it was sent. */
function mockTutorCapture(text: string, seen: { body?: any } = {}) {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST", body: isStream })
    .reply((opts) => {
      seen.body = JSON.parse(opts.body as string);
      return { statusCode: 200, data: groqStreamBody(text), responseOptions: { headers: { "content-type": "text/event-stream" } } };
    });
  return seen;
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

// 2026-10-13, PLAN_08: the progress check quotes its evidence and the server
// checks every quote against the conversation, so a stub that wants a key
// credited must quote words that are really in that test's messages.
const COMPLEMENT = "look up target minus the number to find its partner";
const INDEX = "remember it with its index";
const TUTOR_STATES = "You would also keep each number's index, so you can return the positions.";
const own = (key: string, learner_quote: string) => ({ key, learner_quote, tutor_quote: "" });
const nudged = (key: string, tutor_quote: string) => ({ key, learner_quote: "", tutor_quote });
const BOTH = [own("complement_lookup", COMPLEMENT), own("index_storage", INDEX)];
/** A v5 progress-check answer as the provider returns it. */
const finishBody = (insights: unknown[], named: string[] = [], usage?: { prompt_tokens: number; completion_tokens: number }) =>
  groqCompletionBody(JSON.stringify({ insights, named }), usage);

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
    mockFinishCheck({ status: 200, body: finishBody(BOTH) });
    expect((await chat()).ready_to_finish).toBe(true);
  });

  it("is false when the check answers not ready", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody([own("single_pass", "For each number I'd remember it")]) });
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

  // 2026-10-12, PLAN_07 D2: the check reads both roles, labelled, so a tutor
  // line that put an idea into words can produce `assisted`.
  it("sends the tutor's lines too, labelled, with a strict insights schema", async () => {
    await setFinishOffer();
    mockTutor();
    const seen = mockFinishCheck({ status: 200, body: finishBody([own("single_pass", "For each number I'd remember it")]) });
    await chat({}, [
      { role: "user", text: "Two loops over every pair?" },
      { role: "tutor", text: "TUTOR_ONLY_PHRASE about a lookup" },
      { role: "user", text: LEARNER },
    ]);
    const user = seen.body.messages.find((m: any) => m.role === "user").content as string;
    expect(user).toContain(`user: ${LEARNER}`);
    expect(user).toContain("tutor: TUTOR_ONLY_PHRASE about a lookup");
    expect(user.indexOf("user: Two loops")).toBeLessThan(user.indexOf("tutor: TUTOR_ONLY_PHRASE"));
    const schema = seen.body.response_format.json_schema.schema;
    expect(schema.required).toEqual(["insights", "named"]);
    const item = schema.properties.insights.items;
    expect(item.required).toEqual(["key", "learner_quote", "tutor_quote"]);
    expect(item.additionalProperties).toBe(false);
    expect(item.properties.key.enum).toEqual(["complement_lookup", "single_pass", "index_storage", "duplicates_ok"]);
    expect(schema.properties.named.items.enum).toContain("hash map");
    expect(user).toContain("- hash map");
  });

  it("runs no check and leaves the field off when disabled in config", async () => {
    await setFinishOffer({ enabled: false });
    mockTutor();
    const meta = await chat();
    expect(meta).not.toHaveProperty("ready_to_finish");
  });

  // 2026-10-12, PLAN_04: min_turn gates only the offer. The check also feeds
  // the leak filter, so it must run on turn 1.
  it("before min_turn: still checks (the leak filter needs the keys) but leaves the field off", async () => {
    await setFinishOffer({ min_turn: 2 });
    mockTutor();
    const seen = mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", COMPLEMENT)]) });
    const meta = await chat();
    expect(seen.body).toBeDefined();
    expect(meta).not.toHaveProperty("ready_to_finish");
  });

  it("before min_turn: the check's reached keys are still stored", async () => {
    await setFinishOffer({ min_turn: 2 });
    const installId = await mintInstallId();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", COMPLEMENT)]) });
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: LEARNER }] }),
    });
    await readChatSSE(res);
    const row = await env.DB.prepare("SELECT reached_keys FROM device_day WHERE device_hash = ?1").bind(installId.split(".")[0]).first<{ reached_keys: string }>();
    expect(JSON.parse(row!.reached_keys)).toEqual(["complement_lookup"]);
  });

  it("after Keep going, still checks (the leak filter needs the keys) but leaves the field off", async () => {
    await setFinishOffer();
    mockTutor();
    const seen = mockFinishCheck({ status: 200, body: finishBody(BOTH) });
    const meta = await chat({ finish_offer_dismissed: true });
    expect(seen.body).toBeDefined();
    expect(meta).not.toHaveProperty("ready_to_finish");
  });

  it("drops keys the problem does not author", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", COMPLEMENT), own("made_up_key", INDEX)]) });
    expect((await chat()).ready_to_finish).toBe(false);
  });

  // 2026-10-13, PLAN_08 D2: a key with no words behind it is not credited, so
  // it neither makes the card appear nor lands in the stored keys.
  it("drops a key whose quote is not in the conversation: not ready, nothing stored", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    mockTutor();
    mockFinishCheck({
      status: 200,
      body: finishBody([own("complement_lookup", "I would sort the array first"), own("index_storage", "binary search on the values")]),
    });
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: LEARNER }] }),
    });
    const meta = (await readChatSSE(res)).find((f) => f.event === "meta")!.data as Record<string, unknown>;
    expect(meta.ready_to_finish).toBe(false);
    const row = await env.DB.prepare("SELECT reached_keys, assisted_keys FROM device_day WHERE device_hash = ?1")
      .bind(installId.split(".")[0])
      .first<{ reached_keys: string | null; assisted_keys: string | null }>();
    expect(row!.reached_keys).toBeNull();
    expect(row!.assisted_keys).toBeNull();
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
    mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", "the partner is target minus it")]) });
    const turn1 = [{ role: "user", text: "for each number the partner is target minus it, I look it up fast" }];
    await send(turn1);
    const row = await env.DB.prepare("SELECT reached_keys FROM device_day WHERE device_hash = ?1").bind(installId.split(".")[0]).first<{ reached_keys: string }>();
    expect(JSON.parse(row!.reached_keys)).toEqual(["complement_lookup"]);

    // Turn 2: a reply naming "hash map" (complement_lookup's never_say) is
    // no longer blocked, though the learner never said the words.
    mockTutor("Yes -- a hash map does that. What does it need to hold?");
    mockFinishCheck({ status: 200, body: finishBody([]) });
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
    mockFinishCheck({ status: 200, body: finishBody([], ["hash map", "not-a-term"]) });
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
    mockFinishCheck({ status: 200, body: finishBody([]) });
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
    mockFinishCheck({ status: 200, body: groqCompletionBody(JSON.stringify({ insights: [], named: [said, "hash map"] })) });
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

  // 2026-10-13, PLAN_08 (privacy): quotes live in memory for one request. A
  // check that quotes the learner and the tutor leaves only authored keys behind.
  it("never stores quoted text: after a turn whose check quotes both roles, no device_day column holds it", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    const said = "MARKER_LEARNER_QUOTE we remember each number with its index";
    const tutorSaid = "MARKER_TUTOR_QUOTE so you look up target minus the number";
    mockTutor();
    mockFinishCheck({
      status: 200,
      body: finishBody([own("index_storage", said), nudged("complement_lookup", tutorSaid)]),
    });
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [
          { role: "user", text: said },
          { role: "tutor", text: tutorSaid },
          { role: "user", text: "yes" },
        ],
      }),
    });
    const meta = (await readChatSSE(res)).find((f) => f.event === "meta")!.data as Record<string, unknown>;
    expect(JSON.stringify(meta)).not.toContain("MARKER_");
    const rows = await env.DB.prepare("SELECT * FROM device_day WHERE device_hash = ?1").bind(installId.split(".")[0]).all();
    const stored = JSON.stringify(rows.results);
    expect(stored).not.toContain("MARKER_");
    const row = rows.results[0] as { reached_keys: string; assisted_keys: string };
    expect(JSON.parse(row.reached_keys)).toEqual(["index_storage"]);
    expect(JSON.parse(row.assisted_keys)).toEqual(["complement_lookup"]);
  });

  // 2026-10-12, PLAN_07 D4/D5: the card counts reached plus assisted, and the
  // assisted key is stored. vp-0001 equivalent of the vp-0003 session.
  it("is ready when the learner reached one required insight and accepted the other from the tutor, and stores it", async () => {
    await setFinishOffer();
    const installId = await mintInstallId();
    mockTutor();
    mockFinishCheck({
      status: 200,
      body: finishBody([own("complement_lookup", COMPLEMENT), nudged("index_storage", TUTOR_STATES)]),
    });
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({
        problem_id: "vp-0001",
        messages: [
          { role: "user", text: LEARNER },
          { role: "tutor", text: TUTOR_STATES },
          { role: "user", text: "yes, that" },
        ],
      }),
    });
    const meta = (await readChatSSE(res)).find((f) => f.event === "meta")!.data as Record<string, unknown>;
    expect(meta.ready_to_finish).toBe(true);
    const row = await env.DB.prepare("SELECT reached_keys, assisted_keys FROM device_day WHERE device_hash = ?1")
      .bind(installId.split(".")[0])
      .first<{ reached_keys: string; assisted_keys: string }>();
    expect(JSON.parse(row!.reached_keys)).toEqual(["complement_lookup"]);
    expect(JSON.parse(row!.assisted_keys)).toEqual(["index_storage"]);
  });

  it("assisted alone does not make the learner ready when a required insight is missing", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody([nudged("index_storage", TUTOR_STATES)]) });
    expect(
      (
        await chat({}, [
          { role: "user", text: LEARNER },
          { role: "tutor", text: TUTOR_STATES },
          { role: "user", text: "yes, that" },
        ])
      ).ready_to_finish,
    ).toBe(false);
  });

  it("makes the finish-check call on the keyed path and reports it", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody(BOTH) });
    const meta = await chat();
    expect(meta.ready_to_finish).toBe(true);
  });
});

// 2026-10-12, PLAN_04: a draft blocked only by words for ideas the learner
// stated THIS turn is let through, using this turn's progress check.
describe("finish offer — same-turn unblock", () => {
  const turn = async (messages = [{ role: "user", text: LEARNER }]) => {
    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: { "X-Install-Id": await mintInstallId(), "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
      body: JSON.stringify({ problem_id: "vp-0001", messages }),
    });
    expect(res.status).toBe(200);
    const frames = await readChatSSE(res);
    const text = frames.filter((f) => f.event === "token").map((f) => (f.data as { text: string }).text).join("");
    const meta = frames.find((f) => f.event === "meta")!.data as Record<string, unknown>;
    return { text, meta };
  };
  const DRAFT = "Right, that complement idea works. What do you return when you find it?";

  it("sends the draft as-is when the check says the idea was reached this turn", async () => {
    await setFinishOffer();
    mockTutor(DRAFT);
    mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", COMPLEMENT)]) });
    const { text, meta } = await turn();
    expect(text).toBe(DRAFT);
    expect(meta.leak_blocked).toBe(false);
  });

  it("sends the draft as-is when the check says the term was named this turn", async () => {
    await setFinishOffer();
    mockTutor(DRAFT);
    mockFinishCheck({ status: 200, body: finishBody([], ["complement"]) });
    const { text, meta } = await turn();
    expect(text).toBe(DRAFT);
    expect(meta.leak_blocked).toBe(false);
  });

  it("rewrites when still blocked after the recheck, listing only the remaining words", async () => {
    await setFinishOffer();
    mockTutor("The complement idea works, so store the index. What next?");
    mockFinishCheck({ status: 200, body: finishBody([own("complement_lookup", COMPLEMENT)]) });
    const seen = mockTutorCapture("Good. What do you return?");
    const { text } = await turn();
    expect(text).toBe("Good. What do you return?");
    const note = (seen.body.messages[0].content as string).split("FOR THIS REPLY ONLY")[1];
    expect(note).toContain("store the index");
    expect(note).not.toContain("complement");
  });

  it("keeps today's behavior when the check fails: the rewrite runs", async () => {
    await setFinishOffer();
    mockTutor(DRAFT);
    mockFinishCheck({ status: 500, body: { error: "boom" } });
    mockTutor("Good. What do you return when you find it?");
    const { text } = await turn();
    expect(text).toBe("Good. What do you return when you find it?");
  });
});

// 2026-10-12, PLAN_07 D5: the leak filter keeps using `reached` only. An idea
// the tutor put into words and the learner accepted does not release the
// words for it.
describe("finish offer — assisted does not unblock words", () => {
  it("a key only in assisted keeps its never_say words blocked on the next turn", async () => {
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

    // Turn 1: complement_lookup (never_say includes "hash map") is only assisted.
    mockTutor();
    const stated = "You would look up target minus the number in a table.";
    mockFinishCheck({ status: 200, body: finishBody([nudged("complement_lookup", stated)]) });
    const turn1 = [
      { role: "user", text: "so how?" },
      { role: "tutor", text: stated },
      { role: "user", text: "yes, that" },
    ];
    await send(turn1);
    const row = await env.DB.prepare("SELECT reached_keys, assisted_keys FROM device_day WHERE device_hash = ?1")
      .bind(installId.split(".")[0])
      .first<{ reached_keys: string | null; assisted_keys: string }>();
    expect(JSON.parse(row!.assisted_keys)).toEqual(["complement_lookup"]);
    expect(row!.reached_keys).toBeNull();

    // Turn 2: the draft says "hash map". Still blocked, so a rewrite call is
    // made (the pattern of the still-blocked test in PLAN_04).
    mockTutor("Yes -- a hash map does that. What does it need to hold?");
    mockFinishCheck({ status: 200, body: finishBody([]) });
    const seen = mockTutorCapture("Good. What does it need to hold?");
    const frames = await send([...turn1, { role: "tutor", text: "Go on." }, { role: "user", text: "okay" }]);
    const text = frames.filter((f) => f.event === "token").map((f) => (f.data as { text: string }).text).join("");
    expect(text).toBe("Good. What does it need to hold?");
    const note = (seen.body.messages[0].content as string).split("FOR THIS REPLY ONLY")[1];
    expect(note).toContain("hash map");
  });
});

describe("finish offer — trial path", () => {
  it("runs on the operator pool, spends the trial budget", async () => {
    await setFinishOffer();
    mockTutor();
    mockFinishCheck({ status: 200, body: finishBody(BOTH, [], { prompt_tokens: 300, completion_tokens: 40 }) });
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
