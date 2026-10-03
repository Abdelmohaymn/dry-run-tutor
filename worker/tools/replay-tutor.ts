// Replays one tutor turn against a live provider and reports what the leak
// filter does with each draft: sent clean, rewritten (chat-core.ts's one
// retry with rewriteNote()), cut to its clean lead, or replaced by the
// fallback. For reproducing a conversation from a device without the app.
//
//   GROQ_API_KEY=gsk_... npm run replay:tutor -- tools/replay-samples/pair-sum-full-answer.json
//   GROQ_API_KEY=gsk_... npm run replay:tutor -- conv.json --problem vp-0001 --runs 8 --gap 5
//
// The conversation file is a JSON array of {"role": "user" | "tutor", "text"}
// turns, oldest first, ending on the learner's turn: the same shape as
// `messages` on POST /v1/chat. Pull a real one from a debug build's
// `messages` table (only `kind = 'turn'` rows are replayed as context).
//
// The system prompt is built the way runConversationalTurn() builds it,
// with the runtime_config values below. Keep those in step with the
// environment being reproduced. Every run spends real tokens on the key.
import { readFileSync } from "node:fs";
import { setDefaultAutoSelectFamilyAttemptTimeout } from "node:net";
import { getPrivate, getPublicManifest } from "../src/lib/content";
import { learnerNamedTerms, reachedInsightKeys, renderGroundTruth, selectSlice } from "../src/lib/ground-truth";
import { blockedTermsIn, buildBlockedTerms, cleanLead } from "../src/lib/leak-filter";
import type { RuntimeConfig } from "../src/lib/runtime-config";
import type { Turn } from "../src/lib/schemas";
import { TUTOR_PROMPT, rewriteNote } from "../src/prompts/tutor";
import type { Problem } from "../../tools/problem-types";

// The dev runtime_config's values on 2026-09-25.
const TURN_CAP = 15;
const CFG = {
  trim: { verbatim_turns: 6, narrow_after_turn: 3, narrow_margin: 0.15 },
  chat: { wrap_up_at_turn: 12 },
} as unknown as RuntimeConfig;

const BASE_URL = "https://api.groq.com/openai/v1";

// Node gives each of a host's addresses 250 ms to connect before trying the
// next. On a slow link every attempt times out and fetch fails outright,
// while curl to the same host works.
setDefaultAutoSelectFamilyAttemptTimeout(3000);

function usage(message: string): never {
  console.error(`${message}\n\nUsage: npm run replay:tutor -- <conversation.json> [--problem vp-0001] [--runs 6] [--gap 4] [--model openai/gpt-oss-120b]`);
  process.exit(1);
}

function parseArgs(argv: string[]) {
  const opts = { file: "", problem: "vp-0001", runs: 6, gapSeconds: 4, model: "openai/gpt-oss-120b" };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    const value = () => argv[++i] ?? usage(`${arg} needs a value`);
    if (arg === "--problem") opts.problem = value();
    else if (arg === "--runs") opts.runs = Number(value());
    else if (arg === "--gap") opts.gapSeconds = Number(value());
    else if (arg === "--model") opts.model = value();
    else if (arg.startsWith("--")) usage(`Unknown option ${arg}`);
    else opts.file = arg;
  }
  if (!opts.file) usage("No conversation file given.");
  return opts;
}

const opts = parseArgs(process.argv.slice(2));
const apiKey = process.env.GROQ_API_KEY ?? usage("GROQ_API_KEY is not set. This makes live provider calls.");

const publicHalf = getPublicManifest().problems.find((p) => p.id === opts.problem);
const privateHalf = getPrivate(opts.problem);
if (!publicHalf || !privateHalf) usage(`No problem ${opts.problem} in the built content. Run npm run build:content.`);
const problem: Problem = { public: publicHalf!, private: privateHalf! };

const messages = JSON.parse(readFileSync(opts.file, "utf8")) as Turn[];
if (messages.at(-1)?.role !== "user") usage("The conversation must end on the learner's turn.");

const turnIndex = messages.filter((m) => m.role === "user").length;
const systemPrompt = TUTOR_PROMPT.replace("{{SOLUTION_REQUEST_COUNT}}", "0")
  .replace("{{TURNS_REMAINING}}", String(Math.max(0, TURN_CAP - turnIndex)))
  .replace("{{WRAP_UP}}", "")
  .replace("{{GROUND_TRUTH}}", renderGroundTruth(selectSlice(problem, messages, turnIndex, CFG, "AB")));
const blocked = buildBlockedTerms(
  problem,
  reachedInsightKeys(problem, messages, CFG),
  learnerNamedTerms(problem, messages),
  null,
);

const sleep = (seconds: number) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));
const oneLine = (text: string) => text.replace(/\s+/g, " ").trim();

/** One completion. `null` when the call failed or was refused (the reason is printed). */
async function draft(system: string): Promise<string | null> {
  let res: Response;
  try {
    res = await fetch(`${BASE_URL}/chat/completions`, {
      method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: opts.model,
        messages: [
          { role: "system", content: system },
          ...messages.map((m) => ({ role: m.role === "user" ? "user" : "assistant", content: m.text })),
        ],
      }),
    });
  } catch (err) {
    console.log(`   NETWORK: ${(err as Error).cause ?? err}`);
    return null;
  }
  const body = (await res.json().catch(() => ({}))) as {
    choices?: Array<{ message?: { content?: string } }>;
    error?: { message?: string };
  };
  if (!res.ok) {
    console.log(`   HTTP ${res.status}: ${oneLine(body.error?.message ?? "").slice(0, 120)}`);
    return null;
  }
  return body.choices?.[0]?.message?.content ?? "";
}

console.log(`Problem ${opts.problem}, learner turn ${turnIndex}, ${opts.runs} runs on ${opts.model}`);
console.log(`Blocked terms: ${blocked.length ? blocked.join(" | ") : "(none)"}\n`);

const tally: Record<string, number> = {};
for (let run = 1; run <= opts.runs; run++) {
  if (run > 1) await sleep(opts.gapSeconds);
  const first = await draft(systemPrompt);
  let outcome: string;
  if (first === null) {
    outcome = "PROVIDER ERROR";
  } else {
    const hits = blockedTermsIn(first, blocked);
    if (hits.length === 0) {
      outcome = first.trim() ? "CLEAN" : "EMPTY";
      console.log(`#${run} ${outcome}: ${oneLine(first)}`);
    } else {
      await sleep(opts.gapSeconds);
      const second = await draft(systemPrompt + rewriteNote(hits));
      const stillBlocked = second === null ? [] : blockedTermsIn(second, blocked);
      const lead = cleanLead(first, blocked);
      outcome =
        second !== null && second.trim() && stillBlocked.length === 0
          ? "REWRITTEN"
          : lead.trim()
            ? "CUT TO CLEAN LEAD"
            : "FALLBACK";
      console.log(`#${run} ${outcome} (blocked on ${hits.join(", ")})`);
      console.log(`   draft:   ${oneLine(first)}`);
      if (second !== null) {
        console.log(`   rewrite: ${oneLine(second)}${stillBlocked.length ? `  [still blocked: ${stillBlocked.join(", ")}]` : ""}`);
      }
    }
  }
  tally[outcome] = (tally[outcome] ?? 0) + 1;
}

console.log(`\n${Object.entries(tally).map(([k, v]) => `${k}: ${v}`).join("   ")}`);
