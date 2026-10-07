# Review brief: Dry Run tutor and judge (pre-release)

You are reviewing the AI core of **Dry Run**, a mobile app where a developer talks through a coding problem out loud. An AI **tutor** nudges them without giving the answer, and an AI **judge** assesses them at the end. The team wants it better, cheaper and faster before release.

Your job: find what makes the tutor or judge behave badly or waste money. For every finding, say **why** it happens and **how to fix it**. Above all, say whether a better model would fix it or whether **our rules, code or content** are the problem.

You are reviewing, not shipping. Do not deploy, do not commit, do not edit `content/` or the D1 database. You may write scratch scripts and run tests.

---

## 1. What exists

Repo root: the Flutter app is in `lib/` and the Cloudflare Worker (all AI logic) is in `worker/`.

### One tutor turn (`worker/src/lib/chat-core.ts` → `runConversationalTurn`)
1. **Reserve a turn** against the daily cap (`turn-cap.ts`).
2. **Condense.** Once the history passes `trim.verbatim_turns` (default 6), older turns are summarised by a second model call (`lib/condense.ts`, `prompts/condense.ts`).
3. **Ground-truth slice** (`lib/ground-truth.ts`):
   - `selectSlice` picks what the tutor may see.
   - `reachedInsightKeys` guesses which key insights the learner has stated, **by word overlap** (`score()`, threshold `trim.narrow_margin`).
   - Approach narrowing and repeated-wrong-turn detection also use word overlap.
4. **System prompt.** `prompts/tutor.ts` with substitutions for solution-request count, turns left, wrap-up and ground truth.
5. **Recency notes.** `lib/reply-language.ts` appends a reply-language note and a no-repeat note to the last learner message.
6. **Main call.** The whole reply is generated before anything is sent.
7. **Leak filter** (`lib/leak-filter.ts`). If the reply uses a blocked term (`never_say` of an unreached insight, not yet said by the learner), one **rewrite** call follows. If that also fails, the clean lead sentences or a fixed fallback are sent instead.
8. **Finish check** (`lib/finish-check.ts`, `prompts/finish-check.ts`). This is a parallel model call deciding whether every required insight has been stated (paraphrase counts).
9. **Hints** (`lib/hint-ladder.ts`) are authored text sent verbatim. They use no model call and no turn.

### Judge
- `routes/judge.ts`, `lib/judge-core.ts`, `prompts/judge.ts`, `lib/judge-schema.ts`, `lib/judge-postprocess.ts`, `lib/verdict-map.ts`.
- It gets the full ground truth (`judgeSlice`), but never the hints or the editorial.

### Other model calls
- **Transcript repair**: `lib/repair.ts`, `prompts/repair.ts`.
- **Speech-to-text**: `lib/stt-groq.ts`, Whisper on Groq.

### Models and config
- Runtime config lives in the D1 `config` table. Schema and defaults: `lib/runtime-config.ts`, `specs/001-proxy-content-contract/contracts/config.schema.json`.
- **Production, as read on 2026-10-07:**
  - Tutor, judge, finish check and condense all run `nvidia/nemotron-3-super-120b-a12b` on **Nebius** (`https://api.tokenfactory.nebius.com/v1`).
  - Transcript repair runs `meta-llama/Llama-3.3-70B-Instruct`.
  - Speech-to-text is Groq Whisper.
  - Real users are on the **trial path**: ground-truth tier "A" (no approach sketches, no failing cases), `condense: false`, 15 turns per session (wrap-up at 12), and 1M tokens per day for the pool.
  - Finish check runs from turn 2 with an 8 s timeout. `trim`: `verbatim_turns` 6, `narrow_margin` 0.15.
- The local test seed (migration) defaults to `openai/gpt-oss-120b` on Groq. **Always run the harness with the production model** (see "Running live" below), or your results won't describe what users get.
- Temperature is 0 everywhere.

### Running live
The key is already exported in the shell. **Never print, echo or log it**, and never run `env` or `printenv` unfiltered.
- `GROQ_API_KEY` holds a **Nebius** key. The variable name is historical; the harness sends it to whatever `HARNESS_PROVIDER` says.
- `HARNESS_PROVIDER=nebius`, `HARNESS_MODEL=nvidia/nemotron-3-super-120b-a12b`.
- To compare models, override `HARNESS_MODEL` per run with other models from the Nebius Token Factory catalogue (one stronger, one cheaper or faster). Only Nebius models are reachable with this key. Say so in the report rather than guessing about other providers.
- Note: `applyProviderOverride` changes `provider` and `model` only, not `trial.pool` or `providers.nebius.structured_extra_body`. Check which code path the harness actually runs (keyed or trial), and make it match production's trial path where that matters.

### Content (the tutor's knowledge)
- `content/problems/vp-NNNN.json`, hand-authored per `content/AUTHORING.md`.
- `public` holds the statement, constraints and examples.
- `private` holds `reference_approaches`, `key_insights` (key, text, `never_say`, required), `common_wrong_turns` (text, `why_it_fails`, `counter_question`, `failing_case`), hints, `edge_cases` and `editorial`.
- It is built into `worker/src/generated/private-store.ts` by `tools/build-content.ts`.

### Contracts
Prompts are byte-identical to contract files under `specs/*/contracts/`, enforced by `worker/test/unit/prompts-verbatim.test.ts`. A prompt fix means changing the contract file **and** the `.ts` file. Say which contract in each recommendation.

### Tests
- From `worker/`, `npx vitest run` runs the unit and contract tests with stubbed providers.
- `npm run test:harness` runs **live** replays (`test/harness/tutor.harness.test.ts`, `test/harness/judge.harness.test.ts`, corpus in `test/harness/corpus/`). It needs `GROQ_API_KEY`. `test/harness/lib/live-client.ts` supports a provider/model override, which you need for model comparisons.

---

## 2. Known symptoms (start here, then find more)

1. **Re-asking settled points.** Seen live on two problems. In one, the learner said "loop with a suffix max; if the max is lower or equal, continue". The tutor answered "Yes, that's the right idea", then asked how they'd handle "when the future price is not higher". In the other, the tutor asked twice how to compare adjacent elements after sorting, while the learner kept giving that exact answer.
   - Suspected cause: `reachedInsightKeys` misses paraphrases. The slice then tells the tutor the insight is unreached, and the tutor steers back to it.
   - A mitigation landed on 2026-10-07: the list is now labelled a guess, and a no-repeat recency note was added. Check whether it is enough.
2. **Nemotron thinking left on for structured calls.**
   - `lib/provider.ts:21` says Nemotron needs `chat_template_kwargs: { enable_thinking: false }` on structured calls (judge, finish check). With thinking on, the judge sometimes came back hollow: empty insight lists, feedback "...".
   - The production config sets no `structured_extra_body` on `trial.pool[0]`, and `providers.nebius` is `{}`.
   - Measure the hollow-result rate and the token and latency cost, with the setting and without it.
3. **Content mismatch.** The live problems ("Any Repeats?", "Best Day to Buy, Best Day to Sell") are not in `content/problems/`, which holds only vp-0000 to vp-0003. Note what this means for reproducibility, but review with what is here.

---

## 3. What to check

### A. Tutor conversation quality
Score real or replayed conversations against these rules, which are the prompt's own:
- One nudge per reply, 2 to 4 sentences, in the learner's language and dialect.
- Says "yes" plainly when the learner is right, then moves on.
- **Never re-asks what was answered**, even loosely.
- Never states or names an insight, an approach or a term before the learner does.
- Handles wrong ideas with a question or a small failing input, not "that's wrong".
- Answers concept questions fully.
- Stays on topic.
- Follows the solution-request rule (0 or 1 asks: no answer; 2 or more: full answer).
- Steers to wrap-up near the turn cap.

Look especially at:
- **Paraphrase and other approaches.** Does it understand the same idea in different words, broken English, Egyptian Arabic, or mangled speech-to-text? Does it accept a valid approach that is **not** in `reference_approaches`, or push the learner towards the authored one?
- **Instruction conflicts.** Does any part of the prompt or the injected slice contradict another? For example, "steer toward unreached insights" against "never re-ask", or "never use a term" against "explain concepts fully". Which part wins, and why?
- **Leak filter side effects.** How often does the rewrite or fallback fire? Does the fallback line ("what happens … if the input gets much larger?") make sense mid-conversation, or does it read as a non-sequitur? Are the `never_say` lists too broad, for example `map`, `index` or `duplicate`, so that ordinary words get blocked?
- **Condensation.** Does the summary keep what the learner already settled? Does quality drop right after the 6-turn window?

### B. Judge quality
- Run every judge corpus case. Does the verdict match what a fair human examiner would say?
- Does it credit paraphrased insights and valid non-reference approaches?
- Does it penalise things the learner never had a chance to say?
- Is the output schema robust (malformed JSON, refusals)?
- Check `judge-postprocess.ts` and `verdict-map.ts` for logic that overrides a correct model judgement.
- Check consistency: run the same transcript 3 times. With temperature 0 the verdict should be stable. Report any flips.

### C. Deterministic code (word-matching heuristics)
For `score()`, `reachedInsightKeys`, `learnerNamedTerms`, `isRepeatedWrongTurn` and approach narrowing:
- Build a small paraphrase set: for each insight in vp-0001 to vp-0003, write 5 ways a learner might say it, including one in Egyptian Arabic and one transcribed badly.
- Measure recall (paraphrases caught) and false positives (unrelated sentences that count as "reached").
- Report the numbers. This decides whether the heuristic should be replaced, for example by having the finish-check call return per-insight reached keys.

### D. Content quality
- Are insight `text`s phrased the way a learner would say them, or like an editorial?
- Are any `counter_question`s leading or answer-revealing?
- Do `never_say` lists include common words?
- Does any problem lack `required` flags, or have more than 4 or 5 insights?
- Is the content itself causing bad tutor behaviour? If so, say what to change in `AUTHORING.md` so new problems avoid it.

### E. Efficiency (cost and latency per turn)
Count the model calls and tokens in a typical 10-turn session: main reply, rewrite, condense and finish check.
- Size of the system prompt plus slice per turn. Is anything sent that the tutor doesn't use?
- Does generating the whole reply before sending it (for the leak filter) add noticeable latency? Measure time to first token against total time.
- Is the finish check worth one call per turn? Could it be skipped on some turns, or merged with something else?
- Is `gpt-oss-120b` (a reasoning model) paying for hidden reasoning tokens that a non-reasoning model would not need for this task? Check the `usage()` numbers.
- Could prompt caching (a stable prefix first, variable parts last) cut cost? Is the prompt ordered to allow it?

---

## 4. Is it the model or our rules? (required for every finding)

Do not guess. Test it:

1. **Reproduce** the failure with the current model on a fixed transcript, three runs.
2. **Swap the model** using the harness override. Run the same transcript on at least one clearly stronger model (for example the strongest model available on Groq, or another provider the code supports) and one cheaper or faster model.
3. **Swap the rules.** Keep the current model and apply the smallest prompt, slice or code change you believe fixes it.
4. Classify:

| Label | Meaning | Evidence pattern |
|---|---|---|
| **MODEL** | The rules are clear; the model lacks the capacity to follow them | Stronger model fixes it, rule change does not |
| **RULES** | The prompt is ambiguous, contradictory or missing | Rule change fixes it on the current model; a stronger model may also fail |
| **PIPELINE** | Code feeds the model wrong or misleading input (slice, heuristics, condensation, leak filter, notes) | The model behaves correctly once the input is right |
| **CONTENT** | Authored problem data is wrong, leading or too broad | Fixing the JSON fixes it |
| **MIXED** | More than one of the above | State the proportions |

If a stronger model fixes it, also give the cost and latency difference, so the team can decide between upgrading and fixing the rules. Prefer fixes that work on the **cheaper** model.

Also answer once, overall: **would switching the default tutor model and/or judge model be worth it?** Give a recommendation with numbers: quality pass rate on your test set, cost per session, and p50 latency per turn.

---

## 5. Output

Write the report to `specs/review-tutor-judge-findings.md`:

1. **Verdict (5 lines max).** Ready to release or not, the top 3 problems, and the model recommendation.
2. **Findings**, ranked by impact on the learner. One block each:
   - **Title.** Severity: blocker / major / minor. Area: tutor / judge / heuristics / content / efficiency.
   - **Evidence.** A transcript excerpt or test output (short), plus `file:line`.
   - **Root cause.** One or two sentences.
   - **Classification.** MODEL / RULES / PIPELINE / CONTENT / MIXED, with the experiment that proves it.
   - **Fix.** The concrete change: a diff sketch for code, exact new wording for prompts (naming the contract file to update), or the JSON change for content.
   - **Expected effect and how to verify.** Which test or harness case should flip.
   - **Effort.** In hours.
3. **Efficiency table.** Calls per turn, tokens per turn, cost per 10-turn session and p50/p95 latency, now and after the recommended changes.
4. **Model comparison table.** The models tested × pass rate, cost and latency, for the tutor and the judge separately.
5. **New test cases.** The transcripts you built that should be added to `test/harness/corpus/` so each regression stays caught.

## Rules
- Evidence over opinion. Each finding needs a reproduction or a code reference. Mark anything untested as **UNVERIFIED**.
- Never paste API keys or `.dev.vars` contents into the report. The repo is public.
- Keep the product's core rule intact: the tutor must not give the answer away. A fix that makes the tutor "smarter" by leaking insights is not a fix.
- Report failing tests and failed experiments honestly, including ones that disproved your own hypothesis.
