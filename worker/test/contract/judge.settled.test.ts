import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, mintInstallId } from "./helpers";
import { JUDGE_FEEDBACK_FALLBACK } from "../../src/prompts/judge";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// 2026-10-12, PLAN_07 D6-D9. The judge runs the progress check once more on
// the judged conversation and uses `stored ∪ final` as the insight lists. All
// on vp-0001 (required: complement_lookup, index_storage). Each stub is routed
// by the request's schema name, so the order the worker makes its calls in
// does not matter.

type Seen = { body?: any };

function route(schemaName: string, reply: { status: number; body: unknown }, seen: Seen = {}) {
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({
      path: GROQ_CHAT_PATH,
      method: "POST",
      body: (b: string) => JSON.parse(b).response_format?.json_schema?.name === schemaName,
    })
    .reply((opts) => {
      seen.body = JSON.parse(opts.body as string);
      return {
        statusCode: reply.status,
        data: JSON.stringify(reply.body),
        responseOptions: { headers: { "content-type": "application/json" } },
      };
    });
  return seen;
}

const finalCheck = (answer: Record<string, unknown>, seen?: Seen) =>
  route("finish_check", { status: 200, body: groqCompletionBody(JSON.stringify({ named: [], ...answer })) }, seen);
const finalCheckFails = (seen?: Seen) => route("finish_check", { status: 500, body: { error: "boom" } }, seen);

const COMPLEXITY = {
  user_claimed_time: null,
  user_claimed_space: null,
  reference_time: "O(n)",
  reference_space: "O(n)",
  assessment: "not_stated",
};

function judgeAnswer(overrides: Record<string, unknown> = {}) {
  return {
    approach_quote: "",
    matched_approach: "none",
    matched_verdict: "none",
    insights_hit: [],
    insights_missed: [],
    wrong_turns_taken: [],
    complexity: COMPLEXITY,
    verdict: "pass",
    confidence: 0.8,
    feedback: "Some feedback here.",
    ...overrides,
  };
}

const judgeReplies = (answer: Record<string, unknown>, seen?: Seen) =>
  route("assessment", { status: 200, body: groqCompletionBody(JSON.stringify(answer)) }, seen);

const LEARNER = "I would keep a map from each number to its index and look up the target minus the number";
const TUTOR_LAST = "You would also keep each number's index, so you can return the positions.";
const CONVERSATION = [
  { role: "user", text: LEARNER },
  { role: "tutor", text: TUTOR_LAST },
];

// 2026-10-13, PLAN_08: the progress check quotes its evidence and the server
// checks each quote against the conversation, so a stub quotes real words.
const own = (key: string, learner_quote: string) => ({ key, learner_quote, tutor_quote: "" });
const nudged = (key: string, tutor_quote: string) => ({ key, learner_quote: "", tutor_quote });
const LOOKUP = "look up the target minus the number";
const STORAGE = "keep a map from each number to its index";

async function seed(installId: string, reached: string[], assisted: string[]) {
  await env.DB
    .prepare(
      `INSERT INTO device_day (device_hash, problem_id, date, turns, reached_keys, assisted_keys)
       VALUES (?1, 'vp-0001', ?2, 2, ?3, ?4)`,
    )
    .bind(installId.split(".")[0], new Date().toISOString().slice(0, 10), JSON.stringify(reached), JSON.stringify(assisted))
    .run();
}

async function judge(installId: string, conversation: unknown[] = CONVERSATION) {
  const res = await SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
    body: JSON.stringify({ problem_id: "vp-0001", conversation, ended_by: "user" }),
  });
  expect(res.status).toBe(200);
  return (await res.json()) as any;
}

const userContentOf = (seen: Seen) => seen.body.messages.find((m: any) => m.role === "user").content as string;

describe("POST /v1/judge — the settled insights", () => {
  it("insights_hit is the stored keys plus the final check's, and insights_assisted the accepted ones", async () => {
    const installId = await mintInstallId();
    await seed(installId, ["complement_lookup"], []);
    const checkSeen = finalCheck({ insights: [nudged("index_storage", TUTOR_LAST)] });
    const judgeSeen = judgeReplies(
      judgeAnswer({
        approach_quote: LEARNER,
        matched_approach: "hashmap",
        matched_verdict: "optimal",
        // The model's own lists differ from the settled ones: they lose.
        insights_hit: [{ quote: "keep a map from each number", key: "single_pass" }],
      }),
    );
    // Only the approach is sent to the evidence check; no insight claims.
    const evidenceSeen = route("evidence_check", {
      status: 200,
      body: groqCompletionBody(JSON.stringify({ results: [{ id: "approach:hashmap", why: "stub", supported: true }] })),
    });

    const body = await judge(installId);

    expect(body.insights_hit.sort()).toEqual(["complement_lookup", "index_storage"]);
    expect(body.insights_missed.sort()).toEqual(["duplicates_ok", "single_pass"]);
    expect(body.insights_assisted).toEqual(["index_storage"]);
    expect(body.matched_approach).toBe("hashmap");
    expect(body.verdict).toBe("pass"); // an assisted required insight caps it below strong_pass
    // The model's insights_hit disagreed with the settled set.
    expect(body.feedback).toBe(JUDGE_FEEDBACK_FALLBACK);

    // The final check read the judged conversation, including the last tutor reply.
    expect(userContentOf(checkSeen)).toContain(`tutor: ${TUTOR_LAST}`);
    // The judge was shown the settled lists, before the closing instruction.
    const content = userContentOf(judgeSeen);
    expect(content).toContain(
      "Settled insights:\n" +
        "- reached in their own words: complement_lookup\n" +
        "- reached with the tutor's help: index_storage\n" +
        "- not reached: single_pass, duplicates_ok\n\n" +
        "Return the assessment now.",
    );
    expect(content.endsWith("Return the assessment now.")).toBe(true);
    // No insight claims reached the evidence check.
    expect(
      evidenceSeen.body.response_format.json_schema.schema.properties.results.items.properties.id.enum,
    ).toEqual(["approach:hashmap"]);
  });

  it("a model whose lists agree with the settled ones keeps its feedback", async () => {
    const installId = await mintInstallId();
    await seed(installId, ["complement_lookup", "index_storage"], []);
    finalCheck({ insights: [own("complement_lookup", LOOKUP), own("index_storage", STORAGE)] });
    judgeReplies(
      judgeAnswer({
        insights_hit: [
          { quote: "", key: "complement_lookup" },
          { quote: "", key: "index_storage" },
        ],
        feedback: "You described the lookup and the index storage.",
      }),
    );

    const body = await judge(installId);

    expect(body.insights_hit.sort()).toEqual(["complement_lookup", "index_storage"]);
    expect(body.insights_assisted).toEqual([]);
    expect(body.feedback).toBe("You described the lookup and the index storage.");
    expect(body.verdict).toBe("pass");
  });

  it("the final check fails (500) and nothing is stored: today's evidence path, no settled block", async () => {
    const installId = await mintInstallId();
    finalCheckFails();
    const judgeSeen = judgeReplies(
      judgeAnswer({ insights_hit: [{ quote: LEARNER, key: "complement_lookup" }] }),
    );
    route("evidence_check", {
      status: 200,
      body: groqCompletionBody(JSON.stringify({ results: [{ id: "insight:complement_lookup", why: "stub", supported: true }] })),
    });

    const body = await judge(installId);

    expect(body.insights_hit).toEqual(["complement_lookup"]);
    expect(body.insights_assisted).toEqual([]);
    expect(userContentOf(judgeSeen)).not.toContain("Settled insights");
  });

  it("the final check fails but keys are stored: the settled lists come from the stored keys", async () => {
    const installId = await mintInstallId();
    await seed(installId, ["complement_lookup"], ["index_storage"]);
    finalCheckFails();
    const judgeSeen = judgeReplies(judgeAnswer());

    const body = await judge(installId);

    expect(body.insights_hit.sort()).toEqual(["complement_lookup", "index_storage"]);
    expect(body.insights_assisted).toEqual(["index_storage"]);
    expect(userContentOf(judgeSeen)).toContain("- reached with the tutor's help: index_storage");
  });

  it("a key stored as assisted that the final check finds reached is reached only", async () => {
    const installId = await mintInstallId();
    await seed(installId, [], ["index_storage"]);
    finalCheck({ insights: [own("index_storage", STORAGE)] });
    judgeReplies(judgeAnswer());

    const body = await judge(installId);

    expect(body.insights_hit).toEqual(["index_storage"]);
    expect(body.insights_assisted).toEqual([]);
  });

  it("D9: an approach the evidence demotes is restored when the settled insights cover it", async () => {
    const installId = await mintInstallId();
    await seed(installId, [], ["index_storage"]);
    finalCheck({ insights: [nudged("index_storage", TUTOR_LAST)] });
    judgeReplies(
      judgeAnswer({ approach_quote: LEARNER, matched_approach: "sort_two_pointer", matched_verdict: "acceptable" }),
    );
    route("evidence_check", {
      status: 200,
      body: groqCompletionBody(JSON.stringify({ results: [{ id: "approach:sort_two_pointer", why: "stub", supported: false }] })),
    });

    const body = await judge(installId);

    expect(body.matched_approach).toBe("sort_two_pointer");
    expect(body.verdict).toBe("pass");
  });
});
