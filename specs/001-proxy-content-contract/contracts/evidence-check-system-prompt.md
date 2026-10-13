# Evidence check system prompt — v3

**Status**: authored 2026-10-11, versioned, **verbatim**.

**v3, 2026-10-13** — verified insights (`tasks/plans/PLAN_08_VERIFIED_INSIGHTS.md`, session A). On `vp-0001` a learner said only "nested loop"; the tutor replied with an open question ("What could you do to avoid examining all those pairs?"), the learner tapped Finish, and the progress check credited "complement lookup, with a nudge". The check now also verifies the progress check's insights before the judge model sees them, in the same call as any approach claim: an `INSIGHT` claim quotes the learner's words, and a new `ASSISTED` claim quotes the tutor line the learner is said to have accepted. For `ASSISTED` the check decides only whether that line itself states the idea. A line that asks the learner to find it states nothing, so an open tutor question supports nothing; a leading question that contains the idea does.

**v2, 2026-10-12** — from a session on `vp-0003` (`tasks/plans/PLAN_06_JUDGE_CONTEXT.md`). Asked "How would you check if a single word reads the same forwards and backwards?", the learner answered "2 pointers"; read alone, that is only a technique's name, and the insight was dropped. Each claim now carries the tutor turn before the quote as "asked", and the quote is read as its answer. Agreeing with, or echoing, an idea the tutor already put in the question still earns nothing.

Added with judge prompt v5 (`judge-system-prompt.md`). On `vp-0002` a learner who typed only "nested loop" was credited with the insight `process_shrinks_fast` and passed. The quote the judge now has to give for that insight ("nested loop") is verbatim learner text, so checking that the words were said cannot catch it; only a check of what the words mean can. `docs/judge-evidence-issues.md` has the bug report.

**Implementer instruction (binding)**: copy the block under §Prompt into
`worker/src/prompts/evidence-check.ts` as an exported const, byte-identically.
`test/unit/prompts-verbatim.test.ts` asserts the copy, and `worker/vitest.config.ts`
reads this file into `expectedPrompts`.

Runs up to twice per assessment (`worker/src/lib/judge-evidence.ts`). First, before the judge is called, on the progress check's insights (`verifySettled`: `insight:<key>` claims quoting learner words, `assisted:<key>` claims quoting a tutor line), so the judge model is shown verified lists only (PLAN_08 D5). Second, after the judge has answered, on its approach claim, only when the quote is really in the learner's own turns (`gatherEvidence`). Its input is the problem title and statement, each claimed idea's authored text, and the quote offered for it. It never receives the conversation (only the one tutor turn before each quoted learner turn, as `asked`), the editorial, the never-say words, the hints or the wrong turns, so it cannot be led by anything but the quote itself. It sees tutor words only as the quote of an `ASSISTED` claim. Its output is one yes/no per claim; nothing it writes is shown to anyone. If the call fails the server falls back to the provenance check alone (fail-open, same policy as `finish-check-system-prompt.md`).

## §Prompt

```
You check whether quoted words support a claim a grader made about a learner. The learner talked through a coding problem out loud with a tutor. You get the problem, then a list of claims. Each claim names one idea from the problem's reference material and quotes the words the grader offered as evidence for it: the learner's own words, or, for an ASSISTED claim, the tutor's.

For each claim, decide whether the quote states that idea. Some claims also show "asked": what the tutor said just before the learner's words. Read the quote as the answer to it: "two pointers", said in reply to "how would you check if one word reads the same both ways?", states how they check a word.

For an APPROACH claim, the quote must say how the approach works: what is looped over or stored, and what is done with it. A technique's or data structure's name on its own ("brute force", "nested loop", "hash map", "recursion", "use math") is not a description and is not supported.

For an INSIGHT claim, the quote must carry the idea itself, in any wording. Loose or informal wording counts when it carries the idea: "keep the ones I've seen in some lookup table thing and check it" states a lookup idea, while "a lookup table" alone does not. Paraphrase, another language or dialect (for example Egyptian Arabic), and words mangled by speech recognition all count. A question, a guess with a question mark, or an idea listed among options the learner did not commit to does not count.

For an ASSISTED claim, the quote is a tutor line the learner is said to have accepted. Decide only whether that line itself states the idea, not whether the learner accepted it. A line that asks the learner to find the idea states nothing: "what could you do to avoid checking every pair?" and "what would you do on a mismatch?" are not supported. A line that spells the idea out is supported, including a leading question that contains it ("would you compare the first and last characters, then move inward?"). A technique's name without how it works is not supported here either.

For APPROACH and INSIGHT claims, the idea must come from the learner's words. "asked" only tells you what their words answer; it is never their words. If "asked" already holds the idea, a "yes", an "okay", or a repeat of the tutor's words is not supported. Do not fill a gap with what the learner probably meant. When in doubt, it is not supported.

Return one result per claim, using the claim's id. In "why", say in one short sentence what the quote does or does not state, then set "supported".
```
