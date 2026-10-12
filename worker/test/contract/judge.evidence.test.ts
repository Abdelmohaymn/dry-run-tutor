import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  interceptEvidenceCheck,
  mintInstallId,
  interceptFinalCheckUnusable,
} from "./helpers";
import { JUDGE_FEEDBACK_FALLBACK } from "../../src/prompts/judge";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// docs/judge-evidence-issues.md, 2026-10-11. All on vp-0002: the loop approach
// (iterative_digit_sum, acceptable) requires the insight process_shrinks_fast.
type Turn = { role: "user" | "tutor"; text: string };

const COMPLEXITY = {
  user_claimed_time: null,
  user_claimed_space: null,
  reference_time: "O(1)",
  reference_space: "O(1)",
  assessment: "not_stated",
};

/** The over-crediting judge answer observed in the bug report, unless overridden. */
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

function interceptJudge(answer: Record<string, unknown>) {
  interceptFinalCheckUnusable();
  fetchMock
    .get(GROQ_ORIGIN)
    .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
    .reply(200, groqCompletionBody(JSON.stringify(answer)));
}

async function judge(conversation: Turn[]) {
  const res = await SELF.fetch("https://worker.test/v1/judge", {
    method: "POST",
    headers: {
      "X-Install-Id": await mintInstallId(),
      "X-User-Key": "gsk_test_learner_key",
      "content-type": "application/json",
    },
    body: JSON.stringify({ problem_id: "vp-0002", conversation, ended_by: "user" }),
  });
  expect(res.status).toBe(200);
  return (await res.json()) as any;
}

/** "nested loop" and "brute force": a technique's name, credited with an insight it never states. */
function overCredited(said: string) {
  return judgeAnswer({
    approach_quote: said,
    matched_approach: "iterative_digit_sum",
    matched_verdict: "acceptable",
    insights_hit: [{ quote: said, key: "process_shrinks_fast" }],
    verdict: "pass",
  });
}

const FULL_EXPLANATION =
  "loop summing digits while it's over 9; it shrinks fast since a 10-digit number sums to under 100";

describe("POST /v1/judge — credit needs the learner's own words", () => {
  it("'nested loop' alone: a verbatim quote that does not state the idea is not a pass", async () => {
    interceptJudge(overCredited("nested loop"));
    interceptEvidenceCheck(false);

    const body = await judge([{ role: "user", text: "nested loop" }]);

    expect(body.verdict).toBe("unclear");
    expect(body.matched_approach).toBe("none");
    expect(body.matched_verdict).toBe("none");
    expect(body.insights_hit).toEqual([]);
  });

  it("'brute force' alone is not a pass either", async () => {
    interceptJudge(overCredited("brute force"));
    interceptEvidenceCheck(false);

    const body = await judge([{ role: "user", text: "brute force" }]);

    expect(body.verdict).toBe("unclear");
    expect(body.matched_verdict).toBe("none");
  });

  it("'hash map': no approach matched, so there is no tier to show beside 'Approach: None'", async () => {
    // The model's own contradiction (none + acceptable). Nothing is quoted, so there
    // is nothing to check and no evidence call.
    interceptJudge(judgeAnswer({ matched_verdict: "acceptable", verdict: "unclear", confidence: 0.4 }));

    const body = await judge([{ role: "user", text: "hash map" }]);

    expect(body.verdict).toBe("unclear");
    expect(body.matched_approach).toBe("none");
    expect(body.matched_verdict).toBe("none");
  });

  it("a full explanation whose quotes the support check accepts still passes", async () => {
    interceptJudge(
      judgeAnswer({
        approach_quote: "loop summing digits while it's over 9",
        matched_approach: "iterative_digit_sum",
        matched_verdict: "acceptable",
        insights_hit: [
          { quote: "it shrinks fast since a 10-digit number sums to under 100", key: "process_shrinks_fast" },
        ],
      }),
    );
    interceptEvidenceCheck(true);

    const body = await judge([{ role: "user", text: FULL_EXPLANATION }]);

    expect(body.verdict).toBe("pass");
    expect(body.matched_approach).toBe("iterative_digit_sum");
    expect(body.insights_hit).toEqual(["process_shrinks_fast"]);
  });

  it("when the support check rejects the only claimed insight, the feedback is the fallback", async () => {
    // PLAN_06 D7: the model wrote this praise before the claim was dropped.
    interceptJudge(
      judgeAnswer({
        insights_hit: [{ quote: "nested loop", key: "process_shrinks_fast" }],
        feedback: "You explained why the process shrinks fast.",
      }),
    );
    interceptEvidenceCheck(false);

    const body = await judge([{ role: "user", text: "nested loop" }]);

    expect(body.insights_hit).toEqual([]);
    expect(body.feedback).toBe(JUDGE_FEEDBACK_FALLBACK);
  });

  it("an idea only the tutor said never counts for the learner", async () => {
    interceptJudge(
      judgeAnswer({
        approach_quote: "loop until one digit",
        matched_approach: "iterative_digit_sum",
        matched_verdict: "acceptable",
        insights_hit: [{ quote: "it shrinks fast", key: "process_shrinks_fast" }],
      }),
    );
    // Only the approach has learner words behind it, so only it is sent.
    interceptEvidenceCheck(true);

    const body = await judge([
      { role: "user", text: "loop until one digit" },
      { role: "tutor", text: "And does it shrink fast, so the loop stops soon?" },
      { role: "user", text: "I guess" },
    ]);

    expect(body.insights_hit).not.toContain("process_shrinks_fast");
    expect(body.insights_missed).toContain("process_shrinks_fast");
    expect(body.matched_approach).toBe("iterative_digit_sum");
  });

  it("when the evidence call fails the answer stands on provenance alone (fail-open)", async () => {
    interceptJudge(
      judgeAnswer({
        approach_quote: "loop summing digits while it's over 9",
        matched_approach: "iterative_digit_sum",
        matched_verdict: "acceptable",
        insights_hit: [
          { quote: "it shrinks fast since a 10-digit number sums to under 100", key: "process_shrinks_fast" },
        ],
      }),
    );
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(500, { error: { message: "boom" } });

    const body = await judge([{ role: "user", text: FULL_EXPLANATION }]);

    expect(body.verdict).toBe("pass");
    expect(body.insights_hit).toEqual(["process_shrinks_fast"]);
  });
});

describe("POST /v1/trial mode: judge — the same rule on the shared trial key", () => {
  it("'nested loop' alone is not a pass", async () => {
    interceptJudge(overCredited("nested loop"));
    interceptEvidenceCheck(false);

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": await mintInstallId(), "content-type": "application/json" },
      body: JSON.stringify({
        mode: "judge",
        problem_id: "vp-0002",
        conversation: [{ role: "user", text: "nested loop" }],
        ended_by: "user",
      }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as any;
    expect(body.verdict).toBe("unclear");
    expect(body.matched_verdict).toBe("none");
    expect(body.insights_hit).toEqual([]);
  });
});
