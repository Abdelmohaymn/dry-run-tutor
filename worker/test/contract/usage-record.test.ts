import { env, SELF, fetchMock } from "cloudflare:test";
import { afterEach, beforeAll, describe, expect, it } from "vitest";
import {
  GROQ_CHAT_PATH,
  GROQ_ORIGIN,
  groqCompletionBody,
  groqStreamBody,
  mintInstallId,
  readChatSSE,
  setRepairConfig,
} from "./helpers";

beforeAll(() => {
  fetchMock.activate();
  fetchMock.disableNetConnect();
});

afterEach(() => {
  fetchMock.assertNoPendingInterceptors();
});

async function usageRowsFor(installId: string): Promise<any[]> {
  const bareInstallId = installId.split(".")[0];
  const rows = await env.DB.prepare("SELECT * FROM usage WHERE install_id = ?1 ORDER BY id")
    .bind(bareInstallId)
    .all();
  return rows.results as any[];
}

// US6 scenario 5, FR-035, FR-023, FR-026.
describe("every relayed call writes a usage row, never a key or message content", () => {
  it("/v1/chat writes a usage row with every required column and no learner key / no message content", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("a reply about hash maps and lookups"), {
        headers: { "content-type": "text/event-stream" },
      });

    const res = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_super_secret_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "a hash map maybe" }] }),
    });
    await readChatSSE(res);

    const rows = await usageRowsFor(installId);
    const chatRow = rows.find((r) => r.endpoint === "chat")!;
    expect(chatRow).toBeDefined();
    expect(chatRow.problem_id).toBe("vp-0001");
    expect(chatRow.turn_index).toBe(1);
    expect(typeof chatRow.model).toBe("string");
    expect(typeof chatRow.provider).toBe("string");
    expect(typeof chatRow.input_tokens).toBe("number");
    expect(typeof chatRow.output_tokens).toBe("number");
    expect(typeof chatRow.latency_ms).toBe("number");

    const blob = JSON.stringify(rows);
    expect(blob).not.toContain("gsk_super_secret_learner_key");
    expect(blob).not.toContain("a hash map maybe");
    expect(blob).not.toContain("a reply about hash maps and lookups");
  });

  it("/v1/judge writes a usage row with endpoint judge and no learner key / no message content", async () => {
    const installId = await mintInstallId();
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
            feedback: "Some feedback here about the secret plan",
          }),
        ),
      );

    const res = await SELF.fetch("https://worker.test/v1/judge", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_super_secret_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        problem_id: "vp-0001",
        conversation: [{ role: "user", text: "the secret plan is a hash map" }],
        ended_by: "user",
      }),
    });
    await res.json();

    const rows = await usageRowsFor(installId);
    const judgeRow = rows.find((r) => r.endpoint === "judge")!;
    expect(judgeRow).toBeDefined();
    expect(judgeRow.problem_id).toBe("vp-0001");

    const blob = JSON.stringify(rows);
    expect(blob).not.toContain("gsk_super_secret_learner_key");
    expect(blob).not.toContain("the secret plan is a hash map");
  });

  it("/v1/trial writes a usage row with endpoint trial_chat and no learner key needed / no message content", async () => {
    const installId = await mintInstallId();
    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("trial reply about a secret idea"), {
        headers: { "content-type": "text/event-stream" },
      });

    const res = await SELF.fetch("https://worker.test/v1/trial", {
      method: "POST",
      headers: { "X-Install-Id": installId, "content-type": "application/json" },
      body: JSON.stringify({
        mode: "chat",
        problem_id: "vp-0001",
        messages: [{ role: "user", text: "trial idea about a secret plan" }],
      }),
    });
    await readChatSSE(res);

    const rows = await usageRowsFor(installId);
    const trialRow = rows.find((r) => r.endpoint === "trial_chat")!;
    expect(trialRow).toBeDefined();

    const blob = JSON.stringify(rows);
    expect(blob).not.toContain("trial idea about a secret plan");
    expect(blob).not.toContain("trial reply about a secret idea");
  });

  // FR-014. Sends one /v1/chat turn first so turn_counter.turns is 1, then
  // calls /v1/repair and asserts the repair row's turn_index is that SAME
  // value — the last COMPLETED turn, never from reserveTurn() (this route
  // never calls it).
  it("/v1/repair writes a usage row with endpoint repair, the resolved model/provider, and turn_index from the last completed turn", async () => {
    const installId = await mintInstallId();
    await setRepairConfig();

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqStreamBody("a reply"), { headers: { "content-type": "text/event-stream" } });
    const chatRes = await SELF.fetch("https://worker.test/v1/chat", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", messages: [{ role: "user", text: "a turn" }] }),
    });
    await readChatSSE(chatRes);

    fetchMock
      .get(GROQ_ORIGIN)
      .intercept({ path: GROQ_CHAT_PATH, method: "POST" })
      .reply(200, groqCompletionBody("I would use two pointers here to scan through the whole list of values"));
    const repairRes = await SELF.fetch("https://worker.test/v1/repair", {
      method: "POST",
      headers: {
        "X-Install-Id": installId,
        "X-User-Key": "gsk_test_learner_key",
        "content-type": "application/json",
      },
      body: JSON.stringify({ problem_id: "vp-0001", transcript: "I would use too pointers here to scan through the whole list of values" }),
    });
    expect(repairRes.status).toBe(200);

    const rows = await usageRowsFor(installId);
    const repairRow = rows.find((r) => r.endpoint === "repair")!;
    expect(repairRow).toBeDefined();
    expect(typeof repairRow.model).toBe("string");
    expect(typeof repairRow.provider).toBe("string");
    expect(repairRow.turn_index).toBe(1);
  });
});
