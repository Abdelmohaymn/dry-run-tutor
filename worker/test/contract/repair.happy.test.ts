import { SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  mintInstallId,
  setRepairConfig,
} from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

// US1 scenarios 1 and 4: a mangled declared term reaches the review step
// spelled as authored, and every occurrence is fixed.
describe("POST /v1/repair — happy path", () => {
  it("a mangled declared term comes back spelled as authored, rest byte-identical", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();

    // "brute force" and "two pointers" are glossary_terms for vp-0001 that
    // are NOT also a `never_say` term for any key_insight, so a correct
    // repair here cannot be discarded by guard 2 (containsNoGroundTruth) —
    // unlike "hash map"/"complement", which are both glossary terms AND
    // never_say terms, and so are a guard-2 rejection by design
    // (research.md R-005's benign false positive).
    const raw = "I could try too pointers first but broot force would also work if I check every pair";
    const repaired = "I could try two pointers first but brute force would also work if I check every pair";

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody(repaired));

    const res = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: raw }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { repaired: string; changed: boolean };
    expect(body).toEqual({ repaired, changed: true });
  });
});
