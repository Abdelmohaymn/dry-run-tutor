#!/usr/bin/env node
// T111 (SC-007a) — plot cumulative `condense` input tokens against turn count
// across live sessions of 6, 10 and 15 turns, and check the curve is linear
// rather than quadratic. Ad hoc measurement tooling for
// specs/001-proxy-content-contract/GATE-D-MEASUREMENT.md; not part of the
// test suite and not wired into CI.
//
//   npx wrangler dev --env dev            # local Worker, local D1
//   node gate-d-condense-plot.mjs         # this script, another terminal
//   node gate-d-condense-plot.mjs 6 10    # or a subset of the turn counts
//
// The learner key comes from GATE_D_KEY, or from TRIAL_KEY_GROQ in
// .dev.vars.dev. It travels as X-User-Key on the keyed path (/v1/chat), which
// is the only path that condenses at all — the trial profile sets
// trial.condense = false.
//
// Requests go through `curl` rather than Node's fetch: this sandbox's undici
// is intermittently unreliable against Cloudflare's edge (fourth addendum),
// and SSE is easier to drain from a subprocess than to unpick from a stream.
import { execFile } from "node:child_process";
import { readFileSync } from "node:fs";
import { promisify } from "node:util";
import { randomUUID } from "node:crypto";
import { fileURLToPath } from "node:url";

const execFileAsync = promisify(execFile);
// fileURLToPath, not URL.pathname — the repo path contains spaces, and a
// percent-encoded cwd surfaces as a bare ENOENT against the command itself.
const WORKER_DIR = fileURLToPath(new URL(".", import.meta.url));

const API = process.env.GATE_D_API ?? "http://127.0.0.1:8787";
const PROBLEM = process.env.GATE_D_PROBLEM ?? "vp-0001";
const PROVIDER = process.env.GATE_D_PROVIDER ?? "groq";
// Groq's free tier is tokens-per-minute limited (8k TPM on gpt-oss-120b), and
// a late turn plus its condensation runs several thousand. Spacing turns out
// is cheaper than absorbing 429s mid-session, which is what exhausted the key
// on the earlier attempts.
const TURN_SPACING_MS = Number(process.env.GATE_D_SPACING_MS ?? 20000);
const TURN_COUNTS = (process.argv.slice(2).length ? process.argv.slice(2) : ["6", "10", "15"]).map(Number);

function learnerKey() {
  if (process.env.GATE_D_KEY) return process.env.GATE_D_KEY;
  const vars = readFileSync(fileURLToPath(new URL(".dev.vars.dev", import.meta.url)), "utf8");
  const match = vars.match(/^TRIAL_KEY_GROQ=(.*)$/m);
  if (!match) throw new Error("no GATE_D_KEY and no TRIAL_KEY_GROQ in .dev.vars.dev");
  return match[1].trim().replace(/^"|"$/g, "");
}

// Fifteen learner turns that stay in the conversation without ever asking for
// the answer (solution_request_count stays 0, so no release, and the session
// runs to the cap). Content matters only in that it must be long enough to be
// worth condensing — a one-word turn would make the curve meaningless.
const LEARNER_TURNS = [
  "So I have a list of numbers and a target, and exactly one pair adds up to it. My first instinct is to check every pair with two nested loops and return the positions when the sum matches.",
  "Right, the nested loop is quadratic. For ten million numbers that would be far too slow, so I need something that does fewer comparisons per element.",
  "What if I sort the list first and then walk two pointers inward from both ends? That feels faster than checking every pair.",
  "Ah, but sorting moves the elements around, and I need the original positions, not the values. So sorting loses the very thing I have to return.",
  "Okay, so I need to keep the positions intact. Could I remember something about each number as I walk the list once, so I never have to look backwards?",
  "For each number I know exactly what its partner would have to be — the target minus the number. So the question is whether I have already seen that partner.",
  "Checking whether I have seen it by scanning what I have already walked is another loop, which puts me back at quadratic. I need that check to be cheap.",
  "So I want a structure where asking have I seen this value is roughly constant time, and where I can also get back the position it was at.",
  "That would be a dictionary keyed by the value, with the position as what I store against it. Then the partner check is one lookup.",
  "Walking once, for each position I look up the partner. If it is there I have my answer, and if not I record the current value and position and carry on.",
  "That gives me one pass over the list and one cheap lookup per element, so the total work grows in step with the length of the list rather than its square.",
  "The memory cost is the entries I record, which in the worst case is one per element, so the space grows with the input too. That seems like a fair trade for the speed.",
  "Negative numbers do not bother it, because subtraction works the same either way and I am only ever comparing values I have actually stored.",
  "Repeats are fine too, I think — if the pair is the same value twice, the first occurrence is already recorded by the time I reach the second one and the lookup finds it.",
  "And because I record each value only after checking for its partner, I can never match a position against itself, which was the one edge I was worried about.",
];

async function curlJson(args) {
  const { stdout } = await execFileAsync("curl", ["-s", "--max-time", "180", ...args], { maxBuffer: 32 * 1024 * 1024 });
  return stdout;
}

async function mintInstall() {
  const body = await curlJson([
    "-X", "POST", `${API}/v1/install`,
    "-H", "content-type: application/json",
    "-d", JSON.stringify({ install_uuid: randomUUID() }),
  ]);
  const parsed = JSON.parse(body);
  if (!parsed.install_id) throw new Error(`install failed: ${body}`);
  return parsed.install_id;
}

async function getConfig() {
  return JSON.parse(await curlJson([`${API}/v1/config`]));
}

/** Drains one SSE response into { text, meta, error }. */
function parseSse(raw) {
  let text = "";
  let meta = null;
  let error = null;
  let event = null;
  for (const line of raw.split("\n")) {
    if (line.startsWith("event:")) event = line.slice(6).trim();
    else if (line.startsWith("data:")) {
      const data = line.slice(5).trim();
      if (!data) continue;
      let payload;
      try { payload = JSON.parse(data); } catch { continue; }
      if (event === "token") text += payload.text ?? "";
      else if (event === "meta") meta = payload;
      else if (event === "error") error = payload.error ?? payload;
    }
  }
  return { text, meta, error };
}

async function chatTurn({ installId, key, messages, summary }) {
  const body = { problem_id: PROBLEM, messages, solution_request_count: 0 };
  if (summary) body.summary = summary;
  const raw = await curlJson([
    "-X", "POST", `${API}/v1/chat`,
    "-H", `X-Install-Id: ${installId}`,
    "-H", `X-User-Key: ${key}`,
    "-H", `X-Provider: ${PROVIDER}`,
    "-H", "content-type: application/json",
    "-d", JSON.stringify(body),
  ]);
  // A non-2xx comes back as a plain JSON envelope, not SSE.
  if (raw.trimStart().startsWith("{")) {
    const parsed = JSON.parse(raw);
    return { text: "", meta: null, error: parsed.error ?? parsed };
  }
  return parseSse(raw);
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// SC-007 counts the assessment call too. Off by default because it costs
// another ~3k tokens of a free tier per session; GATE_D_JUDGE=1 turns it on.
const WITH_JUDGE = process.env.GATE_D_JUDGE === "1";

async function judgeSession(installId, key, conversation) {
  const raw = await curlJson([
    "-X", "POST", `${API}/v1/judge`,
    "-H", `X-Install-Id: ${installId}`,
    "-H", `X-User-Key: ${key}`,
    "-H", `X-Provider: ${PROVIDER}`,
    "-H", "content-type: application/json",
    "-d", JSON.stringify({ problem_id: PROBLEM, conversation, ended_by: "cap" }),
  ]);
  const parsed = JSON.parse(raw);
  return parsed.error ? { error: parsed.error } : { assessment: parsed };
}

async function runSession(turns, key, K) {
  const installId = await mintInstall();
  console.log(`\n=== ${turns}-turn session — install ${installId.slice(0, 8)}…`);
  let messages = [];
  const conversation = []; // never trimmed — what the judge leg is handed
  let summary;
  for (let n = 1; n <= turns; n++) {
    const learnerText = LEARNER_TURNS[(n - 1) % LEARNER_TURNS.length];
    messages = [...messages, { role: "user", text: learnerText }];
    conversation.push({ role: "user", text: learnerText });
    let result;
    for (let attempt = 1; attempt <= 4; attempt++) {
      result = await chatTurn({ installId, key, messages, summary });
      if (!result.error) break;
      const { code, retry_after_ms: retryAfterMs } = result.error;
      if (code === "RATE_LIMITED" || code === "UNCLEAR_RETRY") {
        const wait = Math.min(retryAfterMs ?? 30000, 600000);
        console.log(`  turn ${n}: ${code}, waiting ${Math.round(wait / 1000)}s (attempt ${attempt})`);
        await sleep(wait + 2000);
        continue;
      }
      throw new Error(`turn ${n} failed: ${JSON.stringify(result.error)}`);
    }
    if (result.error) throw new Error(`turn ${n} exhausted retries: ${JSON.stringify(result.error)}`);

    const meta = result.meta ?? {};
    if (meta.summary) {
      // The app keeps only what the summary does not already cover, and
      // replays both next turn (data-model.md §A2, §B6).
      summary = meta.summary;
      messages = messages.slice(-K);
    }
    messages = [...messages, { role: "tutor", text: result.text }];
    conversation.push({ role: "tutor", text: result.text });
    console.log(
      `  turn ${n}: turn_index=${meta.turn_index} condensed=${meta.summary ? "yes" : "no"} ` +
      `leak_blocked=${meta.leak_blocked} reply=${result.text.length} chars`,
    );
    if (n < turns) await sleep(TURN_SPACING_MS);
  }

  if (WITH_JUDGE) {
    await sleep(TURN_SPACING_MS);
    let judged;
    for (let attempt = 1; attempt <= 4; attempt++) {
      judged = await judgeSession(installId, key, conversation.slice(0, 40));
      if (!judged.error) break;
      const wait = Math.min(judged.error.retry_after_ms ?? 30000, 600000);
      console.log(`  judge: ${judged.error.code}, waiting ${Math.round(wait / 1000)}s (attempt ${attempt})`);
      await sleep(wait + 2000);
    }
    console.log(`  judge: ${judged.error ? JSON.stringify(judged.error) : "assessment returned"}`);
  }
  return installId;
}

// usage.install_id holds the UUID half only — the middleware verifies and
// strips the signature before anything downstream sees it.
const installUuid = (installId) => installId.split(".")[0];

async function condenseRows(installId) {
  const sql =
    `SELECT turn_index, input_tokens, output_tokens FROM usage ` +
    `WHERE install_id='${installUuid(installId)}' AND endpoint='condense' ORDER BY turn_index`;
  const { stdout } = await execFileAsync(
    "npx",
    ["wrangler", "d1", "execute", "dry-run-dev", "--env", "dev", "--local", "--json", "--command", sql],
    { cwd: WORKER_DIR, maxBuffer: 16 * 1024 * 1024 },
  );
  const json = JSON.parse(stdout.slice(stdout.indexOf("[")));
  return json[0].results;
}

async function sessionTotals(installId) {
  const sql =
    `SELECT SUM(input_tokens+output_tokens) AS session_tokens, COUNT(*) AS calls, ` +
    `SUM(CASE WHEN endpoint='condense' THEN input_tokens ELSE 0 END) AS condense_tokens ` +
    `FROM usage WHERE install_id='${installUuid(installId)}'`;
  const { stdout } = await execFileAsync(
    "npx",
    ["wrangler", "d1", "execute", "dry-run-dev", "--env", "dev", "--local", "--json", "--command", sql],
    { cwd: WORKER_DIR, maxBuffer: 16 * 1024 * 1024 },
  );
  const json = JSON.parse(stdout.slice(stdout.indexOf("[")));
  return json[0].results[0];
}

const key = learnerKey();
const cfg = await getConfig();
const K = cfg.trim.verbatim_turns;
console.log(`API ${API} · problem ${PROBLEM} · verbatim_turns K=${K} · spacing ${TURN_SPACING_MS}ms`);

const report = [];
for (const turns of TURN_COUNTS) {
  const installId = await runSession(turns, key, K);
  const rows = await condenseRows(installId);
  const totals = await sessionTotals(installId);
  const condenseInput = rows.reduce((sum, r) => sum + r.input_tokens, 0);
  report.push({ turns, installId, calls: rows.length, rows, condenseInput, totals });
  console.log(`  → ${rows.length} condense calls, input tokens ${rows.map((r) => r.input_tokens).join(" → ")}`);
}

console.log("\n=== SC-007a — condense input tokens vs turn count ===");
console.log("turns  calls  condense_input  per_turn  session_tokens");
for (const r of report) {
  console.log(
    `${String(r.turns).padStart(5)}  ${String(r.calls).padStart(5)}  ` +
    `${String(r.condenseInput).padStart(14)}  ${(r.condenseInput / r.turns).toFixed(1).padStart(8)}  ` +
    `${String(r.totals.session_tokens ?? 0).padStart(14)}`,
  );
}
// Linear growth keeps condense_input/turns roughly flat as turns rise;
// quadratic growth makes it climb in proportion to the turn count.
if (report.length > 1) {
  const first = report[0];
  const last = report[report.length - 1];
  const perTurnRatio = (last.condenseInput / last.turns) / (first.condenseInput / first.turns);
  const turnRatio = last.turns / first.turns;
  console.log(
    `\nper-turn cost ratio ${first.turns}→${last.turns} turns: ${perTurnRatio.toFixed(2)}× ` +
    `(linear ≈ 1.0×, quadratic ≈ ${turnRatio.toFixed(1)}×)`,
  );
}
console.log(`\n${JSON.stringify(report, null, 2)}`);
