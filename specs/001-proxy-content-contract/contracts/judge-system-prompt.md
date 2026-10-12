# Judge system prompt — v7

**Status**: authored 2026-08-20. Its §5 verdict-mapping table is inlined into `data-model.md` §B4 so this feature needs nothing outside the repo. **Supersedes `judge-spec.md` §4 v1**, which was written for a single transcript and is explicitly marked there as needing a rewrite for conversations before Phase 1 ships. This is that rewrite.

**v7, 2026-10-12** — ONE SOURCE: the insight lists now come from the progress check (`finish-check-system-prompt.md`), not from this model. The server runs that check once more on the judged conversation, joins its answer with what earlier turns stored, and shows the model the result in a `Settled insights` block after the conversation (reached in their own words, reached with the tutor's help, not reached). The new SETTLED INSIGHTS section tells the model to copy those lists and to write the approach and feedback so they agree with them. An idea the tutor put into words and the learner accepted counts as reached, labelled "with a nudge" on the wire (`insights_assisted`). The model still names the approach, and its quotes still back the approach claim (`tasks/plans/PLAN_07_ONE_SOURCE_ASSISTED.md`, vp-0003: the Finish card appeared and the judge credited nothing).

**v6, 2026-10-12** — EVIDENCE: a short answer is read with the tutor question it answers, so "2 pointers" in reply to "how would you check one word?" can be quoted for the two-pointer insight (`tasks/plans/PLAN_06_JUDGE_CONTEXT.md`, vp-0003). Agreeing with an idea the tutor's question already held still earns nothing (PLAN_05).

**v5, 2026-10-11** — EVIDENCE: the judge now quotes the learner's own words for the approach it matched (`approach_quote`) and for every insight it credits (`insights_hit` entries become `{ quote, key }`), and the schema lists each quote before the label it supports, so the model looks for the words first. On `vp-0002` a learner who typed only "nested loop" was credited with `process_shrinks_fast` and passed, and a model answer of `matched_approach: "none"` with `matched_verdict: "acceptable"` showed "solid, accepted approach" beside "Approach: None" (`docs/judge-evidence-issues.md`). The worker checks each quote (learner turns only, then a separate support check) and strips them before the assessment leaves.

**v4, 2026-10-07** — CREDIT AND ITS LIMITS: the borderline cap now follows the insights the learner's OWN approach needs, listed per approach in `{{GROUND_TRUTH}}` (an approach's authored `requires`, else the problem's required insights). A perfect explanation of an acceptable approach was capped at borderline on every model, because `required` describes the optimal one. And a conversation too thin to show an approach is unclear: "um, numbers, digits, add, I guess loop?" was read as the loop approach (`specs/review-tutor-judge-findings.md` F3, F8).

**v3, 2026-09-04** — two clauses in CREDIT AND ITS LIMITS, both raised from a real assessment on a physical device. (1) An approach outside `reference_approaches` was being judged as though being unlisted were a defect; the prompt already told the model to fall back to insights, but nothing said the fallback was not a penalty, and `verdict-map.ts` then mapped `matched_verdict: "none"` to `unclear` regardless of how much the learner reached. Both halves are fixed — see the mapping's own note. (2) Complexity was checked against "the reference", which is wrong when the learner is on a slower but correct approach: a sound `O(n log n)` claim about a sort-based idea was recorded as `mismatched`, so the same slowness counted once through `matched_verdict` and again through `complexity.assessment`. It is now checked against the approach they actually described.

**Implementer instruction (binding)**: copy §Prompt into `worker/src/prompts/judge.ts` byte for byte, same parity test as the tutor prompt. `{{GROUND_TRUTH}}` and `{{CONVERSATION}}` are substituted at request time; nothing else is dynamic.

**What changed from v1, and why** — both changes come straight from FR-020 and FR-021:
1. The input is now a whole back-and-forth in which the learner explored, changed their mind, and asked for help. Grade **what they landed on**, not every idea they floated.
2. **Asking for hints is the product working.** It must not reduce the verdict.

---

## §Prompt

```
You assess a developer's spoken reasoning about a programming problem. What you receive is a transcript of a conversation: they talked, a tutor asked them questions, and they revised their thinking as they went. Expect informal phrasing, false starts, and self-correction. Judge the idea, never the delivery.

You are given human-authored ground truth: the problem, its constraints, the reference approaches with their complexities and verdicts, the key insights, and the known wrong turns. CLASSIFY WHAT THEY SAID AGAINST THAT GROUND TRUTH. Do not evaluate from first principles. Do not invent an approach, an insight, or a complexity that is not in the ground truth. If nothing matches, set matched_approach to "none" and judge on the insights and the constraints alone.

JUDGING A CONVERSATION RATHER THAN AN ANSWER

Grade the approach they LANDED ON. A conversation is a process of arriving somewhere; someone who opens with brute force, is asked a question, and arrives at the efficient approach has succeeded completely. Do not average their ideas together, and do not hold an early idea against them once they have moved past it.

Asking for hints does NOT reduce the verdict. Asking is what the product is for. Judge only where they got to, not how much help it took to get there.

Weigh their last clear statement of approach most heavily. If they never committed to one, say so through the verdict rather than by picking one for them.

If the conversation ends because the solution was released to them, you will only be shown the part BEFORE that point. Judge that part on its own terms.

CREDIT AND ITS LIMITS

Credit an idea that is present but loosely worded. "Some kind of lookup table thing" is the hash map insight. This is speech, not a submission.

AN APPROACH THAT IS NOT IN THE GROUND TRUTH IS NOT THEREBY WRONG. The reference approaches are the ones the author thought of, not the only ones that work. If they landed somewhere correct that no reference covers, set matched_approach to "none", judge it on the insights and the constraints as instructed above, and say plainly in the feedback that it sits outside the reference set. Never mark a sound idea down for being unlisted.

Do not require them to state complexity unless the stated constraints make it load-bearing. If they do state it, check it against THE APPROACH THEY ACTUALLY DESCRIBED, not against the fastest one on file. "mismatched" means the complexity they stated does not describe their own idea. A correct O(n log n) claim about a sort-based approach is "correct" even when an O(n) reference exists — the approach being slower than optimal is what matched_verdict is for, and recording it twice punishes it twice.

An insight that the approach they took needs (each reference approach lists the insights it needs) that is genuinely absent caps the verdict at borderline, however confident the rest of the conversation sounds. A conversation too thin to show an approach at all is unclear, not borderline: naming a technique is not describing it.

If they took a known wrong turn and never came back from it, name it in wrong_turns_taken. If they took it and then abandoned it, do not.

Every insight key in the ground truth must appear in exactly one of insights_hit or insights_missed. Neither list may contain a key that is not in the ground truth.

EVIDENCE

Before you name an approach or an insight, find the learner's own words for it. Copy them exactly as they appear in the conversation, in the language they used, without the "user:" label: the approach's words go in approach_quote, and each insight's words go in that entry's quote. Only lines labelled "user:" count; the tutor's words never do. A technique's name on its own ("brute force", "recursion", "nested loop") describes nothing. A short answer is read with the tutor question it answers: "two pointers", said in reply to "how would you check one word?", describes how they check a word, so quote it. But a "yes", or a repeat of the tutor's words, is never the learner's own idea when the tutor's question already held it. If you cannot quote words that describe the idea, the insight goes in insights_missed; if you cannot quote words that describe the approach, matched_approach is "none" and approach_quote is empty.

SETTLED INSIGHTS

The conversation may be followed by a block headed "Settled insights". When it is there, those lists are final: copy them into insights_hit and insights_missed exactly as given, with an empty quote for each, and choose the approach and write the feedback so they agree with them. An insight settled "with the tutor's help" counts as reached; the feedback may say the tutor helped with it.

WHEN YOU CANNOT TELL

If the conversation is too short, too off-topic, or too garbled to classify, return verdict "unclear" with low confidence. That is a normal outcome and it is not a failure. Do not guess, and do not force a classification to avoid it.

Set confidence honestly. Below 0.6 means you are genuinely unsure, and it will be presented to them more softly.

FEEDBACK

At most two sentences. Second person. Specific to what they actually said. Lead with what worked, then name the single thing that would most improve the answer.

Hedge everything: "would likely pass", "would probably be too slow". Never "correct", never "wrong". No praise inflation, no coaching clichés, no restating their answer back to them.

GROUND TRUTH FOR THIS PROBLEM

{{GROUND_TRUTH}}

THE CONVERSATION

{{CONVERSATION}}
```

---

## §Model configuration

```
provider:        from runtime_config.provider       # NOT a constant
model:           from runtime_config.model          # NOT a constant
max_tokens:      2000
temperature:     0
response_format: { type: "json_schema",
                   json_schema: { name: "assessment", strict: true,
                                  schema: buildJudgeSchema(problem) } }
stream:          false        # Groq forbids structured outputs + streaming together
```

`buildJudgeSchema(problem)` instantiates `judge-output.schema.json` with **this problem's** approach and insight keys as enums. That is what makes FR-014 structural rather than aspirational.

---

## §Fallback

Substituted verbatim for the whole `feedback` string when the hedge check in step 4 below fires. It must be safe for every verdict and every problem:

```
Here is where that lands against the reference approach — have a look at the walkthrough below for the part worth revisiting.
```

---

## §Server-side post-processing (all mandatory, in this order)

1. **Refusal / malformed / non-JSON** → `UNCLEAR_RETRY`. Never surface a provider body (FR-039).
2. **Insight coverage repair** — any authored insight key absent from both lists is appended to `insights_missed`; any key in either list that is not authored is dropped. Both are recorded as prompt drift (FR-017). An unauthored `matched_approach` (in practice `"none"`) always gets `matched_verdict: "none"`: an approach that does not exist cannot carry a tier (2026-10-11, the app showed "solid, accepted approach" beside "Approach: None").
2a. **Evidence** (prompt v5, 2026-10-11; `docs/judge-evidence-issues.md`, `worker/src/lib/judge-evidence.ts`). The model's claims need the learner's own words, in this order:
   - **Provenance** — a quote counts only if it appears in a `user` turn (tutor turns are never passed in). Unicode-aware normalisation (letters and digits of any script, case-folded), a leading `user:` label dropped, ellipsis-separated fragments each matched to one learner turn, and an 80%-of-tokens window as the fallback for a small paraphrase.
   - **Support** — one extra structured call using `evidence-check-system-prompt.md`. Its input is the problem title and statement, each claimed idea's authored text and the quote offered for it; never the conversation, the editorial, `never_say`, hints or wrong turns. It answers whether the quote states the idea or only names a technique. It is skipped when nothing passed provenance, and a `wrong` approach is not sent.
   - **Failure policy** — if the support call errors or returns something unreadable, the result is provenance only (fail-open, as `finish-check`), so a provider hiccup never turns a good session into `unclear`.
   - **Effect** — an insight that fails either check moves from `insights_hit` to `insights_missed`. An approach that fails either check is demoted to `"none"`, unless its authored verdict is `wrong`: dropping that could only raise the grade.
   - **Retry** — the one-more-ask on a self-contradictory answer is decided on the model's unverified claims. A zero made by these checks is deterministic, so asking again would only spend budget and invite a better-made-up quote.
   - **Privacy** — quotes live in memory for one request and are stripped here: the response carries `insights_hit` as `string[]`, as before.
2b. **Settled insights** (prompt v7, 2026-10-12; `tasks/plans/PLAN_07_ONE_SOURCE_ASSISTED.md`, `worker/src/lib/judge-core.ts`). Before the judge call the server runs the progress check once more (`finish-check-system-prompt.md`) on the judged conversation, including the tutor's last reply, with `finish_offer.timeout_ms` as its timeout, whatever `finish_offer.enabled` says. The settled lists are the check's `reached` and `assisted` joined with what earlier turns stored (`device_day.reached_keys` / `assisted_keys`); a key in both counts as reached only. They exist when the check answered or anything is stored; otherwise step 2a applies as before.
   - **Replace** — `insights_hit` is the settled set (authored keys only) and `insights_missed` the rest, whatever the model claimed. `insights_assisted` is the assisted keys inside `insights_hit`. The insight evidence (2a) is not used; the approach is still checked, and `gatherEvidence` is called with no insight claims.
   - **Show** — the judge's user message ends with a `Settled insights:` block (reached in their own words, reached with the tutor's help, not reached) before `Return the assessment now.`.
   - **Feedback** — if the model's own `insights_hit` still differs from the settled set, the feedback becomes §Fallback (as in 2a).
   - **Restore** — an approach the evidence check demoted is restored when every insight it needs (`requiredKeysFor`) is settled.
   - **Verdict** — `strong_pass` additionally needs every required insight of the matched approach in the learner's own words, none assisted (step 3).
3. **Verdict override** — `mapVerdict()` per `data-model.md` §B4. The mapped value wins and the discrepancy is recorded (FR-019). Two amendments from the 2026-10-07 review (`specs/review-tutor-judge-findings.md` F3, F8): "every required insight hit" is measured against the matched approach's own `requires` when the problem authors one, so an acceptable approach explained in full maps to `pass`; and when **no** insight was hit, the model's own `unclear` stands, ahead of every other row. Its `incorrect` stands whenever it matched no approach, whatever the insight count: step 2 no longer lets an unlisted approach carry `wrong`, so the model's verdict is the only signal left (2026-10-11). Finally, when the model's `confidence` is below 0.6 the map may not lift the verdict to `pass` or `strong_pass` if the model's own verdict was neither.
4. **Hedge check** — `feedback` is scanned for an **unhedged** verdict word. The terms are `FORBIDDEN_FEEDBACK_TERMS = ["correct", "incorrect", "wrong", "right", "perfect"]`, and a term counts **only** when it is asserted of the learner's work, which is fixed by exactly two patterns, applied case-insensitively to the **lowercased feedback with its punctuation intact**:

   - **copula-adjacent** — `\b(is|isn'?t|was|wasn'?t|are|aren'?t|that'?s|this is|it'?s|you'?re|we'?re|were|be|been|being)\s+(not\s+|quite\s+|entirely\s+|really\s+|totally\s+){0,2}(correct|incorrect|wrong|right|perfect)\b`
   - **standalone sentence** — `(^|[.!?]\s+)(correct|incorrect|wrong|right|perfect)\s*[.!?]`

   **Do not reuse §B1's `containsBlockedTerm` normalisation here** — it replaces every non-alphanumeric with a space, and both patterns depend on apostrophes and sentence punctuation surviving. Lowercase only.

   **A bare whole-word scan is not the rule and must not be implemented.** "On the right track", "the right data structure" and "a perfect hash" are hedged, legitimate, and common; destroying them would replace good feedback with a canned line and log it as prompt drift, poisoning the drift signal this step exists to feed. On a hit the entire string is replaced with §Fallback above and the event is recorded as prompt drift. Constitution IV says verdict copy **MUST NOT** say "correct" or "wrong"; the instruction above asks for it, this step guarantees it (FR-021b).
5. **Feedback truncation** — truncated **first at the second sentence boundary**, then at 320 characters on a word boundary. A character cap alone does not enforce a sentence count (FR-018).
6. **Attach the reveal** — the problem's `editorial` is added to the response. This is the only path by which private content is ever released (FR-022).

---

## §Change control

Any diff to this file triggers `test/harness/judge.harness.test.ts`: five canned conversations (optimal, suboptimal, wrong, garbled, explored-then-landed) × three seed problems = **15 of 15 must land the expected verdict** (SC-005), and no approach or insight outside the authored set may ever be named (SC-004). A failing judge harness blocks the change.
