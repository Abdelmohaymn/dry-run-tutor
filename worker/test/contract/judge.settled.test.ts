import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import { GROQ_CHAT_PATH, GROQ_ORIGIN, groqCompletionBody, interceptEvidenceCheck, mintInstallId } from "./helpers";
import { JUDGE_FEEDBACK_FALLBACK } from "../../src/prompts/judge";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// 2026-10-12, PLAN_07 D6-D9, reworked 2026-10-13 by PLAN_08 D3/D5. The judge
// runs the progress check once more on the judged conversation; the check
// quotes its evidence, the server checks the quotes against the conversation,
// and a support check on them runs BEFORE the judge model is called. What
// survives is the insight lists. Stored keys are not read. Most cases are on
// vp-0001 (required: complement_lookup, index_storage). Each stub is routed
// by the request's schema name, and the two evidence checks by `only`, so the
// order the worker makes its calls in does not matter.

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

// The settled support check (insights), before the judge call.
const supportCheck = (supported: boolean | ((id: string) => boolean) = true) =>
  interceptEvidenceCheck(supported, undefined, "settled");
// The approach check, after the judge call.
const approachCheck = (supported: boolean | ((id: string) => boolean) = true) =>
  interceptEvidenceCheck(supported, undefined, "approach");

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

// The progress check quotes its evidence and the server checks each quote
// against the conversation, so a stub quotes real words.
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

async function judge(installId: string, conversation: unknown[] = CONVERSATION, problemId = "vp-0001") {
  const res = await SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: { "X-Install-Id": installId, "X-User-Key": "gsk_test_learner_key", "content-type": "application/json" },
    body: JSON.stringify({ problem_id: problemId, conversation, ended_by: "user" }),
  });
  expect(res.status).toBe(200);
  return (await res.json()) as any;
}

const userContentOf = (seen: Seen) => seen.body.messages.find((m: any) => m.role === "user").content as string;

describe("POST /v1/judge — the verified insights", () => {
  it("shows the judge the verified lists, and the model's own insight claims lose", async () => {
    const installId = await mintInstallId();
    const checkSeen = finalCheck({ insights: [own("complement_lookup", LOOKUP), nudged("index_storage", TUTOR_LAST)] });
    supportCheck();
    const judgeSeen = judgeReplies(
      judgeAnswer({
        approach_quote: LEARNER,
        matched_approach: "hashmap",
        matched_verdict: "optimal",
        // The model's own lists differ from the verified ones: they lose.
        insights_hit: [{ quote: "keep a map from each number", key: "single_pass" }],
      }),
    );
    approachCheck();

    const body = await judge(installId);

    expect(body.insights_hit.sort()).toEqual(["complement_lookup", "index_storage"]);
    expect(body.insights_missed.sort()).toEqual(["duplicates_ok", "single_pass"]);
    expect(body.insights_assisted).toEqual(["index_storage"]);
    expect(body.matched_approach).toBe("hashmap");
    expect(body.verdict).toBe("pass"); // an assisted required insight caps it below strong_pass
    // The model's insights_hit disagreed with the verified set.
    expect(body.feedback).toBe(JUDGE_FEEDBACK_FALLBACK);

    // The final check read the judged conversation, including the last tutor reply.
    expect(userContentOf(checkSeen)).toContain(`tutor: ${TUTOR_LAST}`);
    // The judge was shown the verified lists, before the closing instruction.
    const content = userContentOf(judgeSeen);
    expect(content).toContain(
      "Settled insights:\n" +
        "- reached in their own words: complement_lookup\n" +
        "- reached with the tutor's help: index_storage\n" +
        "- not reached: single_pass, duplicates_ok\n\n" +
        "Return the assessment now.",
    );
    expect(content.endsWith("Return the assessment now.")).toBe(true);
  });

  it("a model whose lists agree with the verified ones keeps its feedback", async () => {
    const installId = await mintInstallId();
    finalCheck({ insights: [own("complement_lookup", LOOKUP), own("index_storage", STORAGE)] });
    supportCheck();
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

  // PLAN_08 §1 session A (vp-0001). The learner said "nested loop", the tutor
  // asked an open question, the learner tapped Finish. The final check read
  // the open question as an accepted idea; the support check does not.
  it("session A replay: an open tutor question after \"nested loop\" credits nothing", async () => {
    const installId = await mintInstallId();
    const OPEN_QUESTION =
      "Using a nested loop means checking every possible pair – with 10⁷ numbers that's on the order of 10¹⁴ comparisons. " +
      "How long would that take to finish within the required sub-second limit? " +
      "What could you do to avoid examining all those pairs?";
    finalCheck({
      insights: [nudged("complement_lookup", "What could you do to avoid examining all those pairs?")],
    });
    // Provenance passes (the words are in the tutor line); the support check
    // does not: a line that asks for the idea does not state it.
    supportCheck((id) => id !== "assisted:complement_lookup");
    const judgeSeen = judgeReplies(
      judgeAnswer({ matched_approach: "none", matched_verdict: "none", verdict: "unclear", confidence: 0.7 }),
    );

    const body = await judge(installId, [
      { role: "user", text: "nested loop" },
      { role: "tutor", text: OPEN_QUESTION },
    ]);

    expect(body.verdict).toBe("unclear");
    expect(body.insights_hit).toEqual([]);
    expect(body.insights_assisted).toEqual([]);
    const content = userContentOf(judgeSeen);
    expect(content).toContain("- reached in their own words: none");
    expect(content).toContain("- reached with the tutor's help: none");
  });

  it("a tutor quote found in no tutor line is dropped by provenance: the judge sees every key as not reached", async () => {
    const installId = await mintInstallId();
    // No support-check stub: nothing survives provenance, so nothing is sent.
    finalCheck({ insights: [nudged("complement_lookup", "Sort the array and use two pointers from both ends.")] });
    const judgeSeen = judgeReplies(judgeAnswer({ verdict: "unclear" }));

    const body = await judge(installId);

    expect(body.insights_hit).toEqual([]);
    expect(body.insights_assisted).toEqual([]);
    expect(userContentOf(judgeSeen)).toContain(
      "Settled insights:\n" +
        "- reached in their own words: none\n" +
        "- reached with the tutor's help: none\n" +
        "- not reached: complement_lookup, single_pass, index_storage, duplicates_ok\n\n",
    );
  });

  // PLAN_08 §1 session B (vp-0003): "scan in array order" was only ever said
  // by the tutor, and the screen showed it as the learner's own words.
  it("session B class: an idea the final check quotes from the tutor's turn is assisted, never in their own words", async () => {
    const installId = await mintInstallId();
    const TUTOR_TURN_2 =
      "Brute-force scanning each word and testing if it reads the same forward and backward will solve the problem. " +
      "How would you check whether a single word is a palindrome?";
    finalCheck({
      insights: [
        // The model copied a sentence of the tutor's into the learner's quote.
        own(
          "scan_in_array_order",
          "Brute-force scanning each word and testing if it reads the same forward and backward will solve the problem.",
        ),
      ],
    });
    supportCheck();
    judgeReplies(judgeAnswer({ verdict: "borderline" }));

    const body = await judge(
      installId,
      [
        { role: "user", text: "brute force" },
        { role: "tutor", text: TUTOR_TURN_2 },
        { role: "user", text: "two pointer technique" },
        {
          role: "tutor",
          text: "You'll go through the words one by one; when the two-pointer check shows a word is a palindrome, what do you do next?",
        },
      ],
      "vp-0003",
    );

    expect(body.insights_hit).toContain("scan_in_array_order");
    expect(body.insights_assisted).toContain("scan_in_array_order");
  });

  it("a learner quote the support check rejects, plus a tutor quote it accepts, is assisted", async () => {
    const installId = await mintInstallId();
    finalCheck({ insights: [{ key: "index_storage", learner_quote: STORAGE, tutor_quote: TUTOR_LAST }] });
    supportCheck((id) => id === "assisted:index_storage");
    judgeReplies(judgeAnswer());

    const body = await judge(installId);

    expect(body.insights_hit).toEqual(["index_storage"]);
    expect(body.insights_assisted).toEqual(["index_storage"]);
  });

  it("the support check fails (500): the provenance-only lists stand", async () => {
    const installId = await mintInstallId();
    finalCheck({ insights: [own("complement_lookup", LOOKUP), nudged("index_storage", TUTOR_LAST)] });
    route("evidence_check", { status: 500, body: { error: "boom" } });
    judgeReplies(judgeAnswer());

    const body = await judge(installId);

    expect(body.insights_hit.sort()).toEqual(["complement_lookup", "index_storage"]);
    expect(body.insights_assisted).toEqual(["index_storage"]);
  });

  it("stored keys are not credited: only the final check's verified insights count", async () => {
    const installId = await mintInstallId();
    await seed(installId, ["index_storage"], []);
    finalCheck({ insights: [own("complement_lookup", LOOKUP)] });
    supportCheck();
    judgeReplies(judgeAnswer());

    const body = await judge(installId);

    expect(body.insights_hit).toEqual(["complement_lookup"]);
    expect(body.insights_missed).toContain("index_storage");
  });

  it("the final check fails (500) and nothing is stored: today's evidence path, no settled block", async () => {
    const installId = await mintInstallId();
    finalCheckFails();
    const judgeSeen = judgeReplies(
      judgeAnswer({ insights_hit: [{ quote: LEARNER, key: "complement_lookup" }] }),
    );
    interceptEvidenceCheck(true);

    const body = await judge(installId);

    expect(body.insights_hit).toEqual(["complement_lookup"]);
    expect(body.insights_assisted).toEqual([]);
    expect(userContentOf(judgeSeen)).not.toContain("Settled insights");
  });

  it("the final check fails (500) and keys are stored: the PLAN_06 path, stored keys unread, insights_assisted empty", async () => {
    const installId = await mintInstallId();
    await seed(installId, ["complement_lookup"], ["index_storage"]);
    finalCheckFails();
    const judgeSeen = judgeReplies(
      judgeAnswer({ insights_hit: [{ quote: LEARNER, key: "single_pass" }] }),
    );
    interceptEvidenceCheck(true);

    const body = await judge(installId);

    expect(userContentOf(judgeSeen)).not.toContain("Settled insights");
    // The model's quoted list plus the evidence check, nothing from D1.
    expect(body.insights_hit).toEqual(["single_pass"]);
    expect(body.insights_missed.sort()).toEqual(["complement_lookup", "duplicates_ok", "index_storage"]);
    expect(body.insights_assisted).toEqual([]);
  });

  // 2026-10-13, PLAN_08 D8: a demoted approach is re-derived from the verified
  // insights. Here they pin hashmap down, so it is still the result.
  it("D8: an approach the evidence demotes is re-derived from the verified insights", async () => {
    const installId = await mintInstallId();
    finalCheck({ insights: [own("complement_lookup", LOOKUP), own("index_storage", STORAGE)] });
    supportCheck();
    judgeReplies(
      judgeAnswer({
        approach_quote: LEARNER,
        matched_approach: "hashmap",
        matched_verdict: "optimal",
        insights_hit: [
          { quote: "", key: "complement_lookup" },
          { quote: "", key: "index_storage" },
        ],
      }),
    );
    approachCheck(false);

    const body = await judge(installId);

    expect(body.matched_approach).toBe("hashmap");
    expect(body.verdict).toBe("pass");
  });
});
