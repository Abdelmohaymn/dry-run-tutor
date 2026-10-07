# Review findings: Dry Run tutor and judge (pre-release, 2026-10-07)

Brief: `specs/review-tutor-judge-prompt.md`. Nothing was deployed or committed. `content/` and D1 were not touched.

## 0. Fixes applied (2026-10-07, after this review)

All findings below were then fixed in the working tree. Nothing is committed or deployed. Unit and contract tests: **518/518 pass**. Content check passes.

### Verified live on Nebius (Nemotron-3-Super, production body)

| Check | Before | After |
|---|---|---|
| Tutor scenarios S1–S9 (45 replies, grader + hand check) | 21/27 (S1–S9 × 3) | **39/45** |
| S4 valid non-reference approach (no hand-over) | 2/5 | **5/5** |
| S7 suffix-max kept, not pushed to the reference | 3/5 | **5/5** |
| Second solution request releases the solution | 0/3 | **passes** (harness) |
| Judge, 31 corpus cases × 3 (thinking off) | 60/75 on the 25-case set | **90/93** |
| Hollow assessments | 19% | **0** |
| Progress check: paraphrase recall / Arabic / cross-insight / unrelated | 62% / 0% / 42% / 16% (word overlap) | **100% / 100% / 4% / 0%** |
| Live harness (`test:harness`, Nebius + thinking-off structured body) | not run on the production model | **46/48** (final run) |

The two harness failures left:

- **`vp-0002:garbled` (judge).** The model answers `borderline` at confidence 0.5 where `unclear` is expected. This is the same result as before any change (MODEL).
- **`vp-0003:concept_question` (tutor).** Asked "what do you mean by two pointers?", the tutor explains it on a word, and the sketch-overlap detector fires on 2 of 8 runs. The rate is the same 2/8 with the old prompt, so this is a pre-existing flake, not a regression. A stricter "use a generic example" wording got 1/8, which is not a significant difference.

### What changed, by finding

| Finding | Change |
|---|---|
| F1 | Tutor prompt **v7**: the "IF THEIR APPROACH WORKS, IT IS THE ANSWER" rule is added and the "use that to steer" paragraph removed. `renderGroundTruth` no longer shows unreached insight keys. A concept answer must not tie the concept to the solution. The internal spec reference is removed. |
| F2 | `structured_extra_body` is documented in `config.schema.json` and the `worker/README.md` lever table, with a ready `wrangler d1 execute` command. The harness takes `HARNESS_STRUCTURED_EXTRA_BODY` and the judge harness fails on hollow feedback. **The production D1 config is not changed: run the README command.** |
| F3 | `reference_approaches[].requires` is added to the schema, types and contract. `requiredKeysFor()` is used in `mapVerdict`, `isSelfContradictory` and the judge ground truth ("needs insights: …"). Judge prompt **v4** caps borderline on the learner's own approach. A guard was added after the live run: below confidence 0.6 the map may not lift a verdict to pass. Content: `sort_two_pointer` → `index_storage`, `iterative_digit_sum` → `process_shrinks_fast`, `reverse_compare_scan` → `scan_in_array_order`. |
| F4 | Finish-check prompt **v2** returns `reached` keys, and `ready` is derived server-side. Migration `0010_reached_insights.sql` adds `device_day.reached_keys`. The leak filter uses the keys found on earlier turns instead of word overlap. The check keeps running after "Keep going"; only the offer is hidden. |
| F5 | `SOLUTION_RELEASE_NOTE` is appended on the release turn and documented in the tutor contract §Substitutions. |
| F6 | The tutor stream sends `temperature 0.6`, `top_p 0.95` and `max_tokens 2500`; 27/30, as good as the default, with shorter replies. An empty reply is now `UNCLEAR_RETRY` and the turn is refunded. |
| F7 | `never_say` for vp-0001, vp-0002 and vp-0003 no longer blocks ordinary words. `complement` is **kept** because it names the insight; with F4 it is unblocked once the learner states the idea. The fallback is now "Let me put that another way -- what would you do next from here?" |
| F8 | `mapVerdict` lets the model's own `unclear` stand when no insight was hit, and keeps `incorrect` when nothing matched. |
| F9 | Insight texts are rewritten to 25 words or fewer. vp-0002 `plain_mod_nine` no longer contains "mod 9". Validator rules 13 to 16 are added (`requires` on acceptable approaches, no `never_say` in wrong-turn text, no common words, insight length), and `AUTHORING.md` is updated. The proposed glossary rule was **dropped**: the app shows glossary chips only on a near-match in the learner's own draft, so they are a correction aid, not a leak. |
| §5 | New tutor regression cases (fixed history, with regex checks) and the two-ask release case, plus 6 judge cases, are in `worker/test/harness/corpus/`. |

### Before deploy

1. Apply migration `0010` to the prod D1. `reserveTurn` reads `reached_keys`, so deploying without it breaks every chat turn.
2. Run the README's `structured_extra_body` command on the prod config.
3. `npm run build:content`, then deploy.

### Not done

- **Prompt-cache reordering.** Nebius does not cache Nemotron, so there is no saving.
- **Condensation, wrap-up and off-topic handling.** Still untested.
- **Repair guard 2** (`routes/repair.ts:68`). It rejects any repaired transcript that contains a `never_say` term, including the glossary's own "hash map". So the repair's headline case ("hash mop" → "hash map") is always discarded on vp-0001. Keyed path only; not fixed.

---

## 1. Verdict

1. **Not ready to release.** The fixes are small, about 1.5 to 2 days in total. Most are config, prompt wording or content edits. No model change is needed.
2. **Top problem 1: the tutor gives the approach away in plain words.** The word filter cannot catch this. On a valid non-reference approach, Nemotron described the reference approach in 3 of 5 runs and pushed a correct suffix-max solution towards the authored one. Classified **RULES**. A two-part prompt fix took these scenarios from 23/30 to 27/30.
3. **Top problem 2: thinking is on for the judge and finish check.** 19% of assessments came back hollow and 12% had empty or `..` feedback, at 3.4× the latency. Classified **PIPELINE** (config). Setting `structured_extra_body` gives 0 hollow results with the same accuracy.
4. **Top problem 3: an "acceptable" approach can never pass.** Required insights are global, so the sort+two-pointer, loop and reverse-compare solutions are always capped at `borderline`. This happened in 100% of runs, on all 6 models tested. Classified **CONTENT + PIPELINE**. Per-approach required insights take the judge from 61/75 to 70/75 on the current model.
5. **Models:** keep Nemotron-3-Super for the **tutor**, with thinking **on**. Turning thinking off cut quality by about 30%, and DeepSeek-V4-Pro did worse on the same rules at 3.6× the cost. Run the **judge** on Nemotron with thinking **off**. DeepSeek-V4-Pro is an optional judge upgrade: 74/75 against 70/75 after the content fix, for about +0.3¢ per session.

---

## How the evidence was produced

- **Production trial path, reproduced outside the Worker.** Scratch scripts import the real `selectSlice` (tier A), `renderGroundTruth`, `TUTOR_PROMPT`, `withReplyLanguageNote`, `buildBlockedTerms`/`blockedTermsIn`/`cleanLead`/`rewriteNote`, `FINISH_CHECK_PROMPT`, `JUDGE_PROMPT`, `buildJudgeSchema`, `postprocessJudge`, `isSelfContradictory` and `mapVerdict`. They mirror `runConversationalTurn` and `runJudge`.
- **Same request bodies as production.** The scripts send what `provider-groq.ts` sends to Nebius (`api.tokenfactory.nebius.com`): no `temperature` or `max_tokens` on the tutor stream, and `temperature: 0` plus a strict JSON schema on structured calls. Config: `condense:false`, turn cap 15, wrap-up at 12, `narrow_margin` 0.15.
- **Why not `npm run test:harness`.** It runs the **keyed** path: tier AB, no finish check, and `applyProviderOverride` leaves `structured_extra_body` alone. It does not describe what users get, so it was not used for the numbers below.
- **Grading tutor replies.** DeepSeek-V4-Pro graded each reply against the prompt's own rules plus a per-scenario failure condition. I read every failing reply and a sample of passing ones. Grader noise is about ±2 per 30, and it is visibly strict on S7: it marks "can you do it in O(1) space?" as a hand-over in some runs and not in others. Treat tutor pass rates as directional, and the hand-read excerpts as the evidence.
- **Prices.** Nebius `GET /v1/models?verbose=true`, per 1M tokens, input/output:

  | Model | Input $/1M | Output $/1M |
  |---|---|---|
  | Nemotron-3-Super | 0.30 | 0.90 |
  | DeepSeek-V4-Pro | 1.75 | 3.50 |
  | Qwen3-30B-A3B-Instruct | 0.10 | 0.30 |
  | Qwen3-235B-A22B-Instruct | 0.20 | 0.60 |
  | gpt-oss-120b | 0.15 | 0.60 |

  No cached-input price is listed for any of them.
- **Only Nebius models were tested.** The key reaches nothing else. Every claim about other providers is UNVERIFIED.
- **The two live problems are not in `content/`** (symptom 3). I wrote scratch stand-ins for "Any Repeats?" and "Best Day to Buy, Best Day to Sell" in the vp-0001 house style to replay those symptoms. Results on S7 and S8 are approximations of production content.
- **Unit and contract tests:** `npx vitest run --project unit --project contract` passes 504/504 on the current working tree.

---

## 2. Findings (ranked by impact on the learner)

### F1. The tutor hands over the reference approach in plain words, and steers valid approaches towards it
**Severity:** blocker. **Area:** tutor.

**Evidence.** Prod config, 5 runs per scenario. S4 is a learner with a correct O(n log n) binary-search solution to vp-0001, which is not in `reference_approaches`:
> "You could keep track of the numbers you've already seen and, for each new number, ask whether the value that would complete the target is among those seen. How would you store the seen numbers to answer that question quickly?"

- **S4:** 3/5 replies describe the optimal approach before the learner has said it. 0 filter hits, because no `never_say` word is used.
- **S7 (stock, valid backward suffix-max):** prod failed 2/5 and pushed towards the forward or O(1) solution. DeepSeek-V4-Pro failed 3/3 with the current rules and 5/5 with the fix ("can you track something as you scan forward instead…").
- **Solution request at count 1:** 3/3 "nudges" spell out the approach: "think about walking through the list once and, for each number, checking whether the value you need…".

Code references:
- `worker/src/prompts/tutor.ts:70`: "You are told which insights they have not reached yet… **Use that to steer what you ask about.**"
- `worker/src/lib/ground-truth.ts:310`: the unreached-keys list.

Nothing in the tutor prompt says that a correct and fast-enough approach is a finished answer. The judge prompt has that rule; the tutor prompt does not.

**Root cause.** The prompt tells the tutor to steer towards unreached authored insights. Those insights belong to the reference approach, so for a learner on a different valid path the instruction reads as "move them to ours". The word filter only blocks exact terms, so a paraphrased hand-over passes it.

**Classification: RULES (about 80%) + PIPELINE (about 20%: the list's content).**

| Variant (prod model, 5 runs each) | S4 | S7 |
|---|---|---|
| prod | 2/5 | 3/5 |
| `accept` rule only | 5/5 | 1/5 |
| `nolist` (unreached list removed) | 4/5 | 4/5 |
| `fix` = accept + nolist | **5/5** | **5/5** |

- **Overall:** prod 23/30 → fix 27/30. In batch A (9 scenarios × 3), nolist alone went from 21/27 to 24/27.
- **A stronger model does not fix it:** DeepSeek-V4-Pro with the fix scores 20/30, with S7 at 0/5.
- **Pipeline experiment:** a perfect reached-set (oracle) changed little, 22/27 against 21/27. The list itself, and the instruction to steer by it, is the problem, not only its accuracy.

**Fix.** Update `specs/001-proxy-content-contract/contracts/tutor-system-prompt.md` §Prompt and `worker/src/prompts/tutor.ts` together.

1. Insert before "NEVER ASK AGAIN…":
   ```
   IF THEIR APPROACH WORKS, IT IS THE ANSWER. An approach that is correct and fast enough for the stated constraints is a valid solution even if it is not one you were given. Do not steer them toward a different approach. Ask only about what their own approach still leaves open -- an edge case, its complexity, or a detail they have not covered -- or tell them they have it.
   ```
2. Delete the HINTS-section paragraph "You are told which insights they have not reached yet, by name only. Use that to steer what you ask about. Never say the name itself."
3. In `renderGroundTruth` (`ground-truth.ts:306-313`), stop sending the unreached-keys line to the tutor. Keep computing the set for the leak filter (see F4). `GroundTruthSlice.insightKeys` stays and is simply not rendered.

**Expected effect and how to verify.** Add S4 and S7 (section 5) to the tutor corpus with a "no hand-over" check (an LLM-graded assertion, or a fixed list of hand-over phrases per case). Expect S4 and S7 to pass ≥4/5 on Nemotron.

**Effort.** 2 h, plus 2 h to add an LLM-graded harness assertion.

---

### F2. Thinking left on for structured calls (judge and finish check): hollow assessments, flips, 3.4× latency
**Severity:** major. **Area:** judge, efficiency.

**Evidence.** All 25 judge cases (19 corpus + 6 new) × 3 runs on the production body:

| | thinking on (prod today) | `enable_thinking:false` |
|---|---|---|
| matches expected verdict | 61/75 | 60/75 |
| hollow (empty lists, or feedback `""`/`..`) | **14/75 (19%)** | 0/75 |
| feedback empty or `..` shown to the learner | **9/75 (12%)** | 0/75 |
| verdict flips across 3 identical runs | 3 cases (vp-0002 optimal: strong_pass/borderline; vp-0003 optimal; vp-0003 explored) | 2 cases (vp-0001 garbled, NEW binary search) |
| self-contradiction re-asks (2nd call) | 6 | 2 |
| latency p50 / p95 | 5.9 s / 10.0 s | **1.7 s / 2.4 s** |
| output tokens p50 / p95 | 923 / 1625 | 183 / 218 |
| $ per assessment | 0.00140 | 0.00069 |

- **Hollow output with thinking on**, verbatim: `vp-0003:optimal` → model verdict `incorrect`, `insights_hit: []`, feedback "Your response does not address the problem." Another run returned feedback `".."`.
- **Finish check** (10-turn sessions): 171 output tokens and 1.73 s p50 with thinking on, against 6 tokens and 0.66 s off. Readiness was the same: ready at turns 7 to 10 in both, which is correct because `index_storage` is first stated at turn 7.
- **Code references:** `lib/provider.ts:21-26`, `lib/trial-pool.ts:173`, `routes/trial.ts:234-253` and `:280-295`.

**Root cause.** Production `trial.pool[0]` has no `structured_extra_body`, so Nemotron reasons inside a strict-schema call with `max_tokens` 2000 (1500 for the finish check). Sometimes it spends its effort in the reasoning channel and emits a degenerate JSON object.

**Classification: PIPELINE (config).** The same model with the flag gives 0 hollow results at equal accuracy.

**Fix.** Config only. In D1, set on every Nemotron pool member (and on `providers.nebius` for the keyed path):
```json
"structured_extra_body": { "chat_template_kwargs": { "enable_thinking": false } }
```
- **Do not** apply it to the tutor stream. It is not wired there, which is correct; see F6.
- Make the harness match production: `applyProviderOverride` (`test/harness/lib/live-client.ts:26`) should also copy a `HARNESS_STRUCTURED_EXTRA_BODY` JSON env var into `providers[provider].structured_extra_body` and `trial.pool[*]`.

**Expected effect and how to verify.**
- `judge.harness`: no `feedback` equal to `..` and no empty insight lists. Add an assertion: `insights_hit.length + insights_missed.length === key_insights.length` **before** post-processing repair (log the raw output).
- Rerun 3× and expect no verdict flips on the `optimal` cases.

**Effort.** 0.5 h for the config, 1 h for the harness assertion and override.

---

### F3. An "acceptable" reference approach can never reach `pass`
**Severity:** major. **Area:** judge, content.

**Evidence.** New judge cases, each a correct and complete explanation of the problem's `acceptable` approach. Results across all 6 models × 3 runs:

| Case | Verdict |
|---|---|
| vp-0001 sort + two pointers keeping original indices | borderline 18/18 |
| vp-0002 iterative digit sum (constant rounds, zero handled) | borderline 18/18 |
| vp-0003 `word == word[::-1]` scan in order | borderline 18/18 |

In every run the model matched the right approach. The verdict was capped because a required insight belongs to the optimal approach only:
- vp-0001 requires `complement_lookup` ("turns a scan into a lookup").
- vp-0002 requires `digital_root_congruence` and `nine_maps_to_nine`.
- vp-0003 requires `two_pointer_no_copy`.

`verdict-map.ts:49` `if (!allRequiredHit) return "borderline"` runs before the `acceptable → pass` row.

**Root cause.** `required` is global per problem, but it describes what the **optimal** approach needs. The `acceptable` verdict in `reference_approaches` is therefore unreachable.

**Classification: CONTENT + PIPELINE (50/50).** The same model outputs, re-mapped offline with per-approach required sets, matched the expected verdict much more often:

| Model | Now | With per-approach required |
|---|---|---|
| prod | 61/75 | **70/75** |
| nothink | 60/75 | 67/75 |
| dsv4pro | 62/75 | 74/75 |
| qwen235b | 68/75 | 74/75 |
| gpt-oss | 62/70 | 70/70 |

No model change is needed.

**Fix.**
1. **Schema.** Add `requires: string[]` (insight keys) to each `reference_approaches[]` entry in `specs/001-proxy-content-contract/contracts/problem.schema.json` and `tools/problem-schema.ts`. Default: the problem's `required: true` keys.
2. **Mapping** (`lib/verdict-map.ts`):
   ```ts
   const approach = problem.private.reference_approaches.find((a) => a.key === out.matched_approach);
   const requiredKeys = new Set(approach?.requires ?? problem.private.key_insights.filter((i) => i.required).map((i) => i.key));
   ```
   Apply the same change in `isSelfContradictory` (`judge-postprocess.ts:170`) and `finish-check.ts` (ready = the requirements of the approach the learner is on, or keep the optimal set; a product call).
3. **Content:**
   - vp-0001 `sort_two_pointer.requires = ["index_storage"]`
   - vp-0002 `iterative_digit_sum.requires = []`
   - vp-0003 `reverse_compare_scan.requires = ["scan_in_array_order"]`
4. **`AUTHORING.md`:** "Every `acceptable` approach lists in `requires` only the insights that approach itself needs. Check that a perfect explanation of it maps to `pass`." Add this to the review checklist.

**Expected effect and how to verify.** The three `NEW_acceptable_*` judge cases (section 5) flip from `borderline` to `pass`. Add a unit test that feeds `mapVerdict` a perfect acceptable-approach output.

**Effort.** 3 h for the code, the 3 problems and the tests.

---

### F4. `reachedInsightKeys` word overlap: 62% recall, 0% Arabic, 42% cross-insight false positives, and it switches the leak filter off
**Severity:** major. **Area:** heuristics.

**Evidence (section C).** 60 paraphrases (5 per insight for vp-0001 to vp-0003: 3 English, 1 Egyptian Arabic, 1 bad STT) and 10 unrelated sentences:

| | word overlap (today) | finish-check LLM returning keys, Nemotron thinking on | same, thinking off |
|---|---|---|---|
| recall (paraphrase marks its insight) | 37/60 = **62%** | 59/60 = 98% | 54/60 = 90% |
| — English / Egyptian Arabic / bad STT | 28/36 · **0/12** · 9/12 | 35/36 · 12/12 · 12/12 | 33/36 · 11/12 · 10/12 |
| cross-insight false positive (a paraphrase of A marks B) | 75/180 = **42%** | 4/180 = 2% | 14/180 = 8% |
| unrelated sentence marks something | 19/120 = 16% | 0/120 | 0/120 |

Qwen3-30B scored 100% recall but 46/180 (26%) false positives, which is too loose.

Real failures:
- **vp-0001 `complement_lookup` (required) is never reached by any of its 5 paraphrases.** "for each number I know exactly what other number I need, target minus it" scores 0.00. That is the "re-ask a settled point" mechanism.
- "is the number always positive?" marks 3 of 4 vp-0002 insights reached. Ten unrelated sentences in one session mark **all 4** vp-0002 insights reached.
- **Leak through the false positive (S2, Egyptian Arabic):** the English word "lookup" inside an Arabic sentence marks `complement_lookup` reached. That unblocks `hash map`/`map`/`dictionary`, and the thinking-off tutor replied "تمام، structure الـ lookup ده هو الـ **hash map**" in 2/3 runs. The learner never said it.

Code references:
- `ground-truth.ts:56-65`: `overlap / sqrt(n)`. With n ≤ 44 content tokens, **one** shared word clears 0.15, so the threshold does nothing for any real insight text.
- `ground-truth.ts:30-46`.
- `text-match.ts:6`: `normalise` strips every non-ASCII letter, so Arabic scores 0.

**Root cause.** A bag-of-words score cannot tell paraphrase from coincidence. The length normalisation makes a single token enough.

**Classification: PIPELINE.** Measured above: the same insights judged by the model the product already calls every turn are 98% right. On the tutor side, after the F1 fix the list is no longer sent, so this only matters for the **leak filter** and Tier B.

**Fix.**
1. Extend the finish check into a "progress check" returning `{ "reached": [enum of keys], "ready": bool }`. `ready` is derived server-side from `reached` ⊇ required keys.
   - This changes the contract `specs/005-finish-offer/contracts/finish-check-system-prompt.md`; the prompt used in the experiment is in the scratch script `reach-llm.ts`.
   - It costs about +10 output tokens.
2. Persist `reached` per session in D1, or echo it to the client in the `meta` frame and back in the next request. Use the **previous** turn's result for `buildBlockedTerms`, since the call runs alongside the reply. A one-turn lag only keeps a term blocked one turn longer, which is the safe direction.
3. Delete `reachedInsightKeys` as the source of `insightsAlreadyHit`. Keep `learnerNamedTerms`, which is a different, lexical job and works.
4. Until this ships, a cheap stopgap is to require ≥2 shared content tokens (`overlap >= 2 && score >= margin`). UNVERIFIED for recall.

**Expected effect and how to verify.**
- Add `worker/test/unit/reached-keys.test.ts` with the 60-paraphrase set (section 5) against a stubbed provider, to fix the parsing.
- Add a harness case S2 (Egyptian Arabic) that asserts no `hash map`/`map`/`dictionary` in the reply.

**Effort.** 6 h: prompt, schema, D1 column or meta echo, tests.

---

### F5. The solution-request rule fails on Nemotron: a second request does not get the solution
**Severity:** major. **Area:** tutor.

**Evidence.** vp-0001, the learner asks "please, just give me the full solution now" with `{{SOLUTION_REQUEST_COUNT}}` = 2:

| Model, variant | Full solution given |
|---|---|
| Nemotron, current rules | **0/3** ("I hear you want the answer, but I'll hold back for now…") |
| DeepSeek-V4-Pro, current rules | 3/3 |
| Nemotron + one recency note | 2/2 readable runs gave a full Python solution* |

\* The third run hit my harness's leak filter. Production clears the filter on release (`buildBlockedTerms(..., "solution")`), so that run is a harness artefact.

Code reference: `prompts/tutor.ts:58-62`.

**Root cause.** The count rule sits mid-prompt and is outweighed by six "never state the approach" rules, the same recency problem `reply-language.ts` already works around for language.

**Classification: MIXED (50% MODEL, 50% RULES).** A stronger model obeys; a recency note fixes it on the current model.

**Fix.** In `reply-language.ts` / `chat-core.ts`, when `released` is true, append to the last learner message:
```
[They have now asked for the solution twice. Give the full solution now, clearly and completely, and say the session is ending. The rules about not stating the approach no longer apply.]
```
Name it in the tutor contract's §Substitutions (`tutor-system-prompt.md`), as is done for `WRAP_UP_SENTENCE`.

**Expected effect and how to verify.** New harness case `second_solution_request`: two asks, then expect `session_ended: "solution"` and a reply containing code or the full approach.

**Effort.** 1.5 h.

---

### F6. Tutor latency and cost are dominated by hidden reasoning, and the stream is not at temperature 0
**Severity:** major (latency). **Area:** efficiency, tutor.

**Evidence.** The 10-turn trial-path session, prod config, 2 runs:

| Per turn | Value |
|---|---|
| reply latency p50 / p95 | **3.1 s / 8.2 s** |
| time to first visible token p50 | 2.6 s |
| tutor output tokens p50 | 280, for replies of about 40 words, so most of it is reasoning |

In the first probe, a single turn spent 1,489 reasoning characters and 378 output tokens, with first content at 9.7 s.

**Temperature and max_tokens.** `provider-groq.ts:160-166` sends neither on `streamChat`, so the tutor runs at the provider default, not 0 as the brief assumes. Even with `temperature: 0`, Nemotron gave 4 to 5 distinct replies out of 5 per scenario. Do not rely on determinism.

**Turning thinking off on the tutor:** p50 1.5 s, p95 3.1 s, 5× fewer output tokens, but **quality drops**:

| Batch | Thinking on | Thinking off |
|---|---|---|
| A (current rules) | 21/27 | 15/27 |
| B (with the F1 fix) | 27/30 | 17/30 |

With thinking off:
- S3 ("that's what I just said") was ignored 5/5, and "What loop condition…" was asked again.
- The F1 hand-over got worse.

**Root cause.** A reasoning model is used for a short conversational reply. Its reasoning buys rule-following that the non-reasoning mode lacks.

**Classification: MODEL (trade-off).** No model tested gives Nemotron-thinking quality at non-thinking latency:

| Model | Score | Reply latency p50 |
|---|---|---|
| DeepSeek-V4-Pro, non-thinking | 20/30 | 1.5 s |
| Qwen3-30B | 23/30 (more leaks) | (see table 4) |

**Fix.**
1. Keep thinking on for the tutor.
2. Send `max_tokens: 1200` on the stream as a ceiling. Today an unbounded reasoning loop is possible; the measured max was 3,917 tokens on Qwen3.5.
3. Send `temperature` explicitly. Pick 0.3 to 0.6 and document it; the brief's "temperature 0 everywhere" is false today.
4. Optional, UNVERIFIED: if Nebius exposes a reasoning-budget parameter for Nemotron, try a budget of about 256 tokens.

These are code changes in `provider-groq.ts` `streamChat` and `StreamChatParams`. No prompt contract changes.

**Expected effect and how to verify.** p95 is bounded. Measure with `session.ts`-style timing in a harness run.

**Effort.** 1 h.

---

### F7. Leak filter side effects: it fires on 19% of turns, mostly on "index", and the fallback is a non-sequitur
**Severity:** minor (major for vp-0001 specifically). **Area:** tutor, content.

**Evidence.** 249 thinking-on Nemotron tutor turns:

| Outcome | Count |
|---|---|
| CLEAN | 202 |
| REWRITTEN | 32 (+1 full call and about 3 to 4 s each) |
| CLEAN_LEAD | 14 |
| FALLBACK | 1 |

Terms that fired: `index` 29, `complement` 16, `set` 6, `indices` 4, `map` 2, and others once each.

**Fallback mid-conversation (verbatim).** At turn 6 the learner said "something with constant time lookups, like a dictionary". The fallback line came back:
> "Let me put that differently — what happens to the work you're doing at each step if the input gets much larger?"

They had just solved the scaling question, so this reads as a non-sequitur. The same line also appeared after the O(n) answer in S1.

**Concept question cut short.** The vp-0001 question "what's the difference between a set and a dictionary in python?" was cut to one sentence by CLEAN_LEAD in 3/3 prod runs. The return-to-problem question was dropped, because explaining a dict naturally uses "map" or "index". This conflicts with the prompt's "Explain any … concept fully".

**Never_say lists include common words.** vp-0001 includes `index`, `indices`, `map`, `dictionary`, `duplicate`, `duplicates`, `complement`. vp-0003 includes `converge`, `left to right`, `first match`, `break out`. vp-0002 includes `base case`, `off by one`, `handled separately`.

**Root cause.** Ordinary programming vocabulary is treated as answer-revealing. "index" in a problem about returning positions is not a leak.

**Classification: CONTENT (70%) + RULES (30%: the fallback text).**

**Fix.**
- **Content, vp-0001:**
  - `index_storage.never_say` → `["store the index", "index as the value", "position as the value"]`
  - `complement_lookup.never_say` → `["hash map", "hashmap", "complement lookup", "lookup table"]` (drop `map`, `dictionary`, `complement`)
  - `duplicates_ok.never_say` → `["check before insert"]`
  - Review vp-0003 `converge`/`left to right` and vp-0002 `base case` the same way.
- **`AUTHORING.md`:** "`never_say` holds phrases that name the insight, not ordinary vocabulary. No single common word (index, map, set, list, loop, sort, first, base case). If a term would appear in a normal explanation of the problem statement, it does not belong."
- **Fallback** (`tutor-system-prompt.md` §Fallback and `prompts/tutor.ts:84`): replace with a context-free line:
  ```
  Let me ask that another way -- where are you with it right now, and what would you try next?
  ```

**Expected effect and how to verify.** A harness case for the S6 concept question asserting that the reply has ≥2 sentences and a `?`. Measure the rewrite rate on the S-corpus and expect it to drop from 19% to under 8% (UNVERIFIED until the content changes).

**Effort.** 2 h.

---

### F8. `mapVerdict` overrides a correct model judgement, and the model mis-maps some wrong approaches
**Severity:** minor. **Area:** judge.

**Evidence.**
- **`vp-0003:wrong` (character-frequency check):** prod model verdict `incorrect` or `borderline`, but the model set `matched_approach: "none"` with no insights, so `verdict-map.ts:46` returned **`unclear`** in 3/3 runs. Qwen3-30B did the same.
- **`garbled` cases:** the model set `borderline` or `unclear` but matched `brute_force` or `iterative_digit_sum` with zero insights. The map then returned `likely_tle` or `borderline` (Nemotron, thinking off: vp-0001 2/3 and vp-0002 3/3).
- **Qwen3-30B on `vp-0001:wrong`:** matched `sort_two_pointer` instead of `sort_lose_indices`, so the result was **pass** in 3/3. This is model capacity.

Overall, the mapped verdict differs from the model's own verdict in 53 to 61% of judgements. It is right more often: Nemotron 61/75 against 39/75 for the model's own verdict, so the map earns its keep.

**Root cause.** The map ignores a zero-evidence signal. "Approach matched but no insight stated" and "nothing matched but the model says incorrect" both fall through to the wrong row.

**Classification: PIPELINE (60%) + MODEL (40%).**

**Fix** (`verdict-map.ts`, before the existing rows):
```ts
if (out.insights_hit.length === 0 && out.verdict === "unclear") return "unclear";
if (out.matched_approach === "none" && out.insights_hit.length === 0 && out.verdict === "incorrect") return "incorrect";
```
Update the precedence table in `specs/001-proxy-content-contract/contracts/judge-system-prompt.md` §Server-side post-processing step 3. A content fix also helps: make vp-0003 `char_frequency_check.name` describe the learner's likely wording ("Check whether the letters could be rearranged into a palindrome").

**Expected effect and how to verify.**
- `vp-0003:wrong` returns `incorrect`.
- `vp-0001:garbled` and `vp-0002:garbled` return `unclear` with thinking off.

**Effort.** 1.5 h.

---

### F9. Content: editorial insight text, and blocked terms inside the tutor's own slice
**Severity:** minor. **Area:** content.

**Evidence.**
- **Insight `text` length** (words per insight):

  | Problem | Words per insight |
  |---|---|
  | vp-0002 | 49, 33, 28, 31 |
  | vp-0003 | 37, 30, 35, 30 |
  | vp-0001 | 14 to 18 |

  vp-0002 and vp-0003 read like the editorial ("…lands on that same remainder class until it reaches its single-digit representative"). This inflates the false positives in F4 and is the judge's matching target.
- **Wrong-turn text sent to the tutor holds `never_say` terms.** `renderGroundTruth` sends `common_wrong_turns[].text` (`ground-truth.ts:316`). In vp-0002, `plain_mod_nine.text` = "Using the formula num **mod 9** directly", and "mod 9" is a `never_say` of a required insight. In vp-0001, `sort_first.text` says "two-pointering". The tutor is handed the exact word the filter then blocks.
- **Public `glossary_terms` include `never_say` terms:** vp-0001 has `hash map`, `complement`, `index`; vp-0002 has `digital root`, `congruent`. They feed transcript repair, which runs on the keyed path only (see Other), and they ship to the app in the public manifest. UNVERIFIED whether the app shows them.
- **Counter-questions:** none reveal the answer outright. `set_not_map` ("A set can tell you the partner is somewhere in the list. Is that enough…?") presupposes the partner idea. Acceptable.
- **Required flags:** every problem has ≥1 required insight. None has more than 4. The real defect is F3: required is global, not per approach.

**Classification: CONTENT.**

**Fix** (`AUTHORING.md`):
- "Insight `text`: one sentence, ≤20 words, in the words a learner would say out loud."
- "`common_wrong_turns[].text` must not contain any `never_say` term." Add this check to `tools/validate-content.ts`.
- "`glossary_terms` must not include `never_say` terms." Add this check too.
- Rewrite vp-0002 `plain_mod_nine.text` → "Using the remainder after dividing by nine directly, without adjusting for multiples of nine".

**Expected effect and how to verify.** `npm run check:content` fails on the current vp-0002 and vp-0001 until they are fixed.

**Effort.** 2 h, plus content edits.

---

### Other observations

- **Prompt caching.**
  - Nebius reports `cached_tokens: 0` for Nemotron on three identical consecutive requests, and lists no cached price. No saving is available today.
  - Qwen3-30B did cache: 1792 of 1796 tokens on repeat.
  - The prompt is not cache-friendly anyway: `{{SOLUTION_REQUEST_COUNT}}` (`tutor.ts:58`) and `{{TURNS_REMAINING}}` (`:74`) sit mid-prompt. Moving both into the final block next to `{{GROUND_TRUTH}}` would make the first ~75% (about 1.4k tokens) a stable prefix. This is a contract change to `tutor-system-prompt.md`.
  - Also remove the internal reference "(`data-model.md` §B1, FR-004a)" at `tutor.ts:39`. It costs tokens and means nothing to the model.
  - Low priority.
- **Pool budget.** One trial session (10 turns + judge) costs 37k to 39k tokens, so the **1M tokens/day pool covers about 26 sessions per day**. The F2 fix saves about 2k tokens per session (finish check and judge reasoning), which is +5% sessions. Turning thinking off for the tutor would add about +10%, but see F6.
- **Finish check per turn.** It costs about 500 input tokens per turn (about 15% of turn tokens). It answers correctly in all observed runs:

  | Model | Ready at |
  |---|---|
  | Nemotron | turns 7 to 10 (correct) |
  | Qwen3-30B | turn 4 (too early: index storage not stated) |

  With F2 it is 6 output tokens and 0.66 s. It is worth keeping, especially once merged with F4. Skipping it until the learner has said ≥3 turns of ≥15 words is a cheap further cut (UNVERIFIED).
- **Buffering for the leak filter.** With thinking on, time to first visible token is 2.6 s of 3.1 s total, so buffering costs about 0.5 s p50. With thinking off it is 0.9 s of 1.5 s. Streaming sentence by sentence would save about 0.5 s but reintroduces cut-off replies. Not worth it.
- **`gpt-oss-120b` reasoning tokens.** As judge: 663 output tokens p50 (against 183 for Nemotron with thinking off), and 5/75 calls hit `max_tokens` 2000 and failed (`ERROR`). It is paying for hidden reasoning. Not recommended for structured calls without `reasoning_effort: "low"` (UNVERIFIED on Nebius).
- **Transcript repair never runs for trial users.** `/v1/repair` requires `X-User-Key` (`routes/repair.ts:23-24`) and the app only calls it on the keyed path. Mangled STT reaches the tutor raw, which the tutor handled well: S5 "mod nein … nein plus won" passed. Also, `meta-llama/Llama-3.3-70B-Instruct` returns **HTTP 403** for this Nebius key, so if the keyed repair is pointed at Nebius it silently falls back to the raw transcript. UNVERIFIED against the production config.
- **Condensation.** Off on the trial path (`condense:false`), so it is not exercised by users. Not tested: UNVERIFIED.
- **Wrap-up near the cap, and off-topic handling.** Not tested: UNVERIFIED.
- **Symptom 1, re-asking.** With the 2026-10-07 mitigation (guess label + `NO_REPEAT_NOTE`), the grader flagged plain re-asks in 0/27 (batch A) and 2/30 (batch B) prod replies. Hand-reading found one clear case: S9 "How does it behave … like [3, 3]?" right after the learner explained [3, 3]. S3 ("that's what I just said") was handled in 4/5 prod runs. **The mitigation mostly works on Nemotron with thinking on.** The remaining risk is F4's leak-filter side, and F1's steering, which looks like re-asking to a learner on a non-reference path. The original live transcripts could not be replayed exactly (symptom 3).
- **Symptom 3, reproducibility.** The live problems are absent from `content/`, so no exact replay of the reported conversations is possible. The harness corpus covers only vp-0000 to vp-0003. Commit the content of every problem that is served, or tag a content version in the session log.

---

## 3. Efficiency table (10-turn trial session on vp-0001, live, 2 runs each)

| | Now (prod) | After recommended (F1+F2 prompt/config; tutor thinking on) | Alt: tutor thinking off too |
|---|---|---|---|
| model calls / turn | 2.05 (tutor 1, finish check 1, rewrite 3/20 turns) | 2.10 | 2.10 |
| input tokens / turn | 2,968 | 3,054 | 3,156 |
| output tokens / turn | 563 | 488 | 91 |
| finish check out tokens / latency (p50) | 171 / 1.73 s | 6 / 0.66 s | 6 / 0.81 s |
| tutor reply latency p50 / p95 | 3.1 s / 8.2 s | 3.8 s / 8.1 s (same within noise) | 1.5 s / 3.1 s |
| judge (once) tokens / latency | about 3.1k / 5.1 to 6.6 s | about 2.4k / 1.7 s | about 2.4k / 2.1 s |
| **tokens per session** (10 turns + judge) | 38.4k | 37.8k | 35.0k |
| **$ per session** | **$0.0155** | **$0.0144** | $0.0112 |
| tutor quality (batch B, 30 replies) | 23/30 | 27/30 | 17/30 |

After F7's content fix the rewrite rate should fall further (fewer second calls). UNVERIFIED.

## 4. Model comparison

### Tutor (one reply per transcript; grader + hand check)

| Model (Nebius) | Rules | Pass, batch A (9 scen × 3) | Pass, batch B (6 hard scen × 5) | Reply latency p50 / p95* | $ / 10-turn session | Notes |
|---|---|---|---|---|---|---|
| Nemotron-3-Super, thinking on (**prod**) | current | 21/27 | 23/30 | 3.1 s / 8.2 s | $0.0155 | hands over the approach on S4 3/5 |
| Nemotron-3-Super, thinking on | **F1 fix** | — | **27/30** | 3.8 s / 8.1 s | $0.0144 | **recommended** |
| Nemotron-3-Super, thinking off | current / fix | 15/27 | 17/30 | 1.5 s / 3.1 s | $0.0112 | ignores "I already said that" (S3 0/5) |
| DeepSeek-V4-Pro (stronger) | current / fix | 21/27 | 20/30 | 1.5 s / 2.9 s | $0.0554 | S7 0/5: pushes the reference approach; 3.6× cost |
| Qwen3-30B-A3B-Instruct (cheaper/faster) | current / fix | 16/27 | 23/30 | 4.4 s / 6.6 s† | $0.0044 | names terms first ("digital root"), rewrite on 50% of turns |

\* Session-run latency. † Qwen's latency is inflated by rewrites (10/20 turns); its first token arrives at 0.65 s.

Also probed once: Kimi-K3, GLM-5.3, gpt-oss-120b, Qwen3.5-397B, Nemotron-3.5-Lightning. All are reasoning models with first-token times of 3.8 to 29 s; none was a better latency or cost option.

### Judge (25 cases × 3 runs = 75)

| Model | Expected verdict, today | Same outputs, F3 per-approach required | Hollow / errors | Flips across 3 runs | p50 / p95 latency | $ / assessment |
|---|---|---|---|---|---|---|
| Nemotron, thinking on (**prod**) | 61/75 | 70/75 | 14 / 0 | 3 cases | 5.9 s / 10.0 s | 0.00140 |
| Nemotron, thinking off (**recommended default**) | 60/75 | 67/75 | 0 / 0 | 2 | 1.7 s / 2.4 s | 0.00069 |
| DeepSeek-V4-Pro (**optional upgrade**) | 62/75 | **74/75** | 0 / 0 | 1 | 2.5 s / 3.2 s | 0.00373 |
| Qwen3-235B-A22B-Instruct | 68/75 | 74/75 | 0 / 0 | 1 | 28.7 s / 36.9 s‡ | 0.00046 |
| gpt-oss-120b | 62/75 | 70/70 | 5 / 5 (hit max_tokens) | 4 | 3.0 s / 6.8 s | 0.00070 |
| Qwen3-30B-A3B-Instruct | 59/75 | 62/69 | 6 / 6 | 1 | 8.3 s / 55 s | 0.00029 |

‡ Qwen3-235B was very slow on Nebius during this run (first token 5.6 s in an earlier probe). It is accurate and cheap, but its latency must be re-measured before it is considered.

**Recommendation.**
1. Do not switch the tutor model. Fix the rules (F1, F5) and keep Nemotron with thinking on.
2. For the judge, apply F2 and F3 on Nemotron first: 67/75, $0.0007, 1.7 s.
3. DeepSeek-V4-Pro for the judge alone (74/75) adds about $0.003 per session (+20%) and no tokens against the pool. It is worth it if judge fairness is the product's headline; otherwise it is optional.

---

## 5. New test cases (add to `worker/test/harness/corpus/`)

The harness must also run the **trial-path shape** (tier A, finish check, the structured extra body) for these to mean what users get; see F2.

### Tutor (`corpus/tutor/vp-000N.json` → new kind `regression`, with a no-re-ask / no-hand-over check)

Problems x-stock and x-repeats are scratch stand-ins; add them once the live problems are in `content/`.

| id | problem | last learner turn (abridged) | must not |
|---|---|---|---|
| S1_paraphrase_settled_en | vp-0001 | "…constant time membership, left to right, first look for target minus it, then add it" | re-ask what to search for or the check/insert order; name `index`/`hash map` |
| S2_paraphrase_settled_egy | vp-0001 | "هحط الأرقام اللي شفتها في structure الـ lookup فيه constant time…" | reply in non-Egyptian Arabic; name `hash map` (failed 2/3 with thinking off) |
| S3_reask_after_answer | vp-0003 | "that's what I just said, I walk i from the start and j from the end…" | ask again about the pointer walk; fail to acknowledge |
| S4_valid_nonreference | vp-0001 | "…binary search for target minus its value… That's n log n" | describe the seen-values approach (failed 3/5 on prod) |
| S5_stt_mangled_complete | vp-0002 | "…the number mod nein, cause ten is nein plus won… multiple of nein you return nein" | re-ask remainders or multiples of nine |
| S6_concept_question | vp-0001 | "what's the difference between a set and a dictionary in python?" | dodge, or be cut to one sentence (prod 3/3 CLEAN_LEAD) |
| S7_stock_suffix_max | x-stock | "…suffix max… if the max is lower or equal I just continue" | push to the forward-minimum approach |
| S8_repeats_adjacent_twice | x-repeats | "like I said, nums[i] == nums[i+1]…" | ask a third time how to compare |
| S9_long_session_vp1 | vp-0001 | 7-turn complete solution, ends on the [3,3] explanation | ask about [3,3] again; ask anything already covered |
| second_solution_request | vp-0001 | "please, just give me the full solution now" (count 2) | withhold the solution (prod 0/3) |

### Judge (`corpus/judge/vp-000N.json`)

| id | problem | expected | today (prod) |
|---|---|---|---|
| paraphrase_optimal | vp-0001 | pass/strong_pass | passes |
| egyptian_optimal | vp-0001 | pass/strong_pass | passes |
| nonreference_binary_search | vp-0001 | pass | flips pass/borderline on several models |
| acceptable_two_pointer_with_indices | vp-0001 | pass | **borderline 3/3** (F3) |
| acceptable_iterative | vp-0002 | pass | **borderline 3/3** (F3) |
| acceptable_reverse_compare | vp-0003 | pass | **borderline 3/3** (F3) |

The full corpus-ready JSON for both sets is in the appendix.

### Unit (`worker/test/unit/`)

- `reached-keys.test.ts`: the 60-paraphrase + 10-unrelated set from section C (appendix B), asserting the new progress check's parsing. Until F4 lands, keep it as a documented-failure benchmark for `reachedInsightKeys` (today 62% recall, 42% cross false positives).
- `verdict-map.test.ts`: a perfect acceptable-approach output maps to `pass` (F3); "matched + zero insights + model unclear" maps to `unclear` (F8).

---

## Appendix A: corpus-ready JSON

### Tutor regression cases (vp-*)
```json
[
 {"id":"S1_paraphrase_settled_en","problem_id":"vp-0001","kind":"regression","history":[
  {"role":"user","text":"brute force is two loops, n squared, way too slow for ten million"},
  {"role":"tutor","text":"Right, the inner search is the slow part. For one number, what exactly are you searching for?"},
  {"role":"user","text":"for each number I know what the other one has to be, it's target minus the number. so I just need to check fast if I've seen that before"},
  {"role":"tutor","text":"Yes -- that's it. How would you make that check fast?"},
  {"role":"user","text":"I keep the numbers I've already seen in a structure with constant time membership, I go left to right, and for each number I first look for target minus it, then add it"}],
  "settled_insights":["complement_lookup","single_pass","duplicates_ok"]},
 {"id":"S2_paraphrase_settled_egy","problem_id":"vp-0001","kind":"regression","history":[
  {"role":"user","text":"الحل البسيط إني ألف بلوبين على كل الأزواج، بس ده n تربيع وهيبقى بطيء جدا مع عشرة مليون"},
  {"role":"tutor","text":"صح، الدور الداخلي هو اللي بطيء. لكل رقم، إنت بتدور على إيه بالظبط؟"},
  {"role":"user","text":"لكل رقم أنا عارف الرقم التاني لازم يبقى إيه، target ناقص الرقم. فمحتاج أشوف بسرعة هل شفته قبل كده ولا لأ"},
  {"role":"tutor","text":"أيوه، بالظبط كده. هتعمل الـ check ده بسرعة إزاي؟"},
  {"role":"user","text":"هحط الأرقام اللي شفتها في structure الـ lookup فيه constant time، وأمشي من الشمال لليمين، ولكل رقم أدور الأول على target ناقصه وبعدين أضيفه"}],
  "settled_insights":["complement_lookup","single_pass","duplicates_ok"],"must_not_contain":["hash map","hashmap","map","dictionary"]},
 {"id":"S3_reask_after_answer","problem_id":"vp-0003","kind":"regression","history":[
  {"role":"user","text":"I go through the words in order and return the first one that's a palindrome, or empty string if none"},
  {"role":"tutor","text":"Yes -- that's it. How do you check that a single word is a palindrome?"},
  {"role":"user","text":"compare the first letter with the last, then the second with the second to last, moving inwards, and stop as soon as they differ"},
  {"role":"tutor","text":"Good. And how would you compare the characters without building a reversed copy?"},
  {"role":"user","text":"that's what I just said, I walk i from the start and j from the end toward each other, no copy at all"}],
  "settled_insights":["scan_in_array_order","two_pointer_no_copy","bail_on_first_mismatch"]},
 {"id":"S4_valid_nonreference","problem_id":"vp-0001","kind":"regression","history":[
  {"role":"user","text":"two loops is n squared, too slow"},
  {"role":"tutor","text":"Right. So what would let you avoid the inner loop?"},
  {"role":"user","text":"I'd make a list of value and original position pairs, sort it by value, then for each element binary search for target minus its value in the sorted list, and return the two original positions. That's n log n"}],
  "settled_insights":["complement_lookup","index_storage"]},
 {"id":"S5_stt_mangled_complete","problem_id":"vp-0002","kind":"regression","history":[
  {"role":"user","text":"ok so I could just loop and some the digits until it's one digit"},
  {"role":"tutor","text":"That would work. The follow-up asks for no loop at all -- what do you notice if you compare a number and its digit sum?"},
  {"role":"user","text":"so the answer is like the number mod nein, cause ten is nein plus won so each digit place leaves the same remainder, but if it's a multiple of nein you return nein not zero"}],
  "settled_insights":["digital_root_congruence","nine_maps_to_nine"]},
 {"id":"S6_concept_question","problem_id":"vp-0001","kind":"regression","history":[
  {"role":"user","text":"two loops would be n squared"},
  {"role":"tutor","text":"Right, and with ten million numbers is that fast enough?"},
  {"role":"user","text":"no. wait, what's the difference between a set and a dictionary in python? how do they look things up so fast?"}],
  "settled_insights":[]},
 {"id":"S9_long_session_vp1","problem_id":"vp-0001","kind":"regression","history":[
  {"role":"user","text":"two nested loops, every pair"},
  {"role":"tutor","text":"That works. With up to ten million numbers, is that fast enough?"},
  {"role":"user","text":"no, that's like 10 to the 14 operations"},
  {"role":"tutor","text":"Right. So for one number, what are you actually looking for?"},
  {"role":"user","text":"I'm looking for the number that adds up with it to the target, so target minus it"},
  {"role":"tutor","text":"Yes -- that's it. How could you find that value quickly?"},
  {"role":"user","text":"keep what I've seen in some kind of lookup thing with O(1) checks"},
  {"role":"tutor","text":"Good. What does that lookup need to hold so you can answer the question?"},
  {"role":"user","text":"it should map each value to where it was, its position, since we return positions"},
  {"role":"tutor","text":"Yes. Walk me through the order of operations for each element."},
  {"role":"user","text":"for each element I first check if target minus it is already in there, if yes return both positions, otherwise I add the current one with its position"},
  {"role":"tutor","text":"Yes, exactly. What happens with an input like [3, 3] and target 6?"},
  {"role":"user","text":"the first 3 goes in, then the second 3 finds the first one, so it returns 0 and 1. it works because I check before I insert"}],
  "settled_insights":["complement_lookup","single_pass","index_storage","duplicates_ok"]},
 {"id":"second_solution_request","problem_id":"vp-0001","kind":"regression","solution_request_count":2,"history":[
  {"role":"user","text":"two loops, n squared"},
  {"role":"tutor","text":"Right. With ten million numbers, is that fast enough?"},
  {"role":"user","text":"please, just give me the full solution now"}],
  "expect":"full solution and session_ended = solution"}
]
```

### Judge cases
```json
[
 {"problem_id":"vp-0001","id":"paraphrase_optimal","kind":"paraphrase_optimal","expected_verdicts":["pass","strong_pass"],"conversation":[{"role":"user","text":"two loops is too slow for ten million"},{"role":"tutor","text":"Right. For one number, what are you looking for?"},{"role":"user","text":"the other number has to be target minus this one. so as I walk the list I keep everything I've seen in a dictionary from the value to where it was, and for each number I first check if target minus it is in there, and if yes I return the two places, otherwise I put the current one in. that's linear"}]},
 {"problem_id":"vp-0001","id":"egyptian_optimal","kind":"egyptian_optimal","expected_verdicts":["pass","strong_pass"],"conversation":[{"role":"user","text":"اللوبين جوه بعض هيبقوا n تربيع، بطيء أوي مع عشرة مليون"},{"role":"tutor","text":"صح. لكل رقم إنت بتدور على إيه؟"},{"role":"user","text":"بدور على target ناقص الرقم. فهمشي على الليست مرة واحدة، وأخزن كل رقم شفته في dictionary، الـ key هو الرقم والـ value هو مكانه. لكل رقم أشوف الأول هل target ناقصه موجود، لو موجود أرجع المكانين، لو لأ أضيفه. كده O(n)"}]},
 {"problem_id":"vp-0001","id":"nonreference_binary_search","kind":"nonreference_binary_search","expected_verdicts":["pass"],"conversation":[{"role":"user","text":"two loops is n squared, too slow"},{"role":"tutor","text":"Right. So what would let you avoid the inner loop?"},{"role":"user","text":"I'd make a list of value and original position pairs, sort it by value, then for each element binary search for target minus its value in the sorted list, skipping itself, and return the two original positions. That's n log n, fine for ten million in a second"}]},
 {"problem_id":"vp-0001","id":"acceptable_two_pointer_with_indices","kind":"acceptable_two_pointer_with_indices","expected_verdicts":["pass"],"conversation":[{"role":"user","text":"I'd sort, but keep each value with its original index, so pairs of value and index"},{"role":"tutor","text":"Okay, and then?"},{"role":"user","text":"then one pointer at the start, one at the end. if the sum is too small move the left one right, too big move the right one left, when it matches I return the two original indices. n log n for the sort"}]},
 {"problem_id":"vp-0002","id":"acceptable_iterative","kind":"acceptable_iterative","expected_verdicts":["pass"],"conversation":[{"role":"user","text":"I'd loop: while the number has more than one digit, sum its digits using mod 10 and divide by 10, then replace the number with the sum"},{"role":"tutor","text":"How many rounds can that take near the top of the range?"},{"role":"user","text":"a ten digit number sums to at most 90, then at most 17, so it's like three rounds, basically constant. and zero just returns zero"}]},
 {"problem_id":"vp-0003","id":"acceptable_reverse_compare","kind":"acceptable_reverse_compare","expected_verdicts":["pass"],"conversation":[{"role":"user","text":"I go through the words in order and for each one I check if it equals its reverse, word == word[::-1], and return the first that does, else empty string"},{"role":"tutor","text":"How expensive is that check?"},{"role":"user","text":"each reverse is linear in the word length, so overall it's total characters, at most 100 by 100 so it's instant"}]}
]
```

## Appendix B: paraphrase set (section C)

For each insight, 5 paraphrases in this order: plain, informal, alternative wording, Egyptian Arabic, bad STT. The full set is in the scratch script `paraphrases.ts` (`PARA` and `UNRELATED`). Examples:

- **`vp-0001.complement_lookup`:** "for each number I know exactly what other number I need, target minus it, so I just look that up" · "لكل رقم أنا عارف الرقم التاني اللي محتاجه، target ناقص الرقم، فبدور عليه على طول" · "I take the target - the number and see if it's in the has map already, the other half"
- **`vp-0003.two_pointer_no_copy`:** "one index at the start and one at the end, walk them toward each other" (missed by the heuristic) · "use to pointers, one at the start one at the end, move them in word"
- **Unrelated (should reach nothing):** "is the number always positive?" (today it reaches 3 of 4 vp-0002 insights) · "I would sort the list first" (reaches 2 vp-0003 insights).

**Failed or disproved hypotheses (reported as required).**
- "Giving the tutor the correct reached-set fixes re-asking": **not supported.** The oracle variant scored 22/27 against prod's 21/27. The mitigation already handles most re-asks; removing the list helped more.
- "Turning thinking off everywhere is a free win": **false for the tutor** (21→15/27). It is true for the judge and finish check.
- "A stronger model fixes the tutor's steering": **false.** DeepSeek-V4-Pro steered the valid S7 approach towards the reference in 5/5 runs with the fix applied.
