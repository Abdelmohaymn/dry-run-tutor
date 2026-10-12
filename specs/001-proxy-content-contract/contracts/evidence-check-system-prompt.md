# Evidence check system prompt — v2

**Status**: authored 2026-10-11, versioned, **verbatim**.

**v2, 2026-10-12** — from a session on `vp-0003` (`tasks/plans/PLAN_06_JUDGE_CONTEXT.md`). Asked "How would you check if a single word reads the same forwards and backwards?", the learner answered "2 pointers"; read alone, that is only a technique's name, and the insight was dropped. Each claim now carries the tutor turn before the quote as "asked", and the quote is read as its answer. Agreeing with, or echoing, an idea the tutor already put in the question still earns nothing.

Added with judge prompt v5 (`judge-system-prompt.md`). On `vp-0002` a learner who typed only "nested loop" was credited with the insight `process_shrinks_fast` and passed. The quote the judge now has to give for that insight ("nested loop") is verbatim learner text, so checking that the words were said cannot catch it; only a check of what the words mean can. `docs/judge-evidence-issues.md` has the bug report.

**Implementer instruction (binding)**: copy the block under §Prompt into
`worker/src/prompts/evidence-check.ts` as an exported const, byte-identically.
`test/unit/prompts-verbatim.test.ts` asserts the copy, and `worker/vitest.config.ts`
reads this file into `expectedPrompts`.

Runs once per assessment (`worker/src/lib/judge-evidence.ts`), after the judge has answered and only when at least one of its quotes is really in the learner's own turns. Its input is the problem title and statement, each claimed idea's authored text, and the quote offered for it. It never receives the conversation (only the one tutor turn before each quoted learner turn, as `asked`), the editorial, the never-say words, the hints or the wrong turns, so it cannot be led by anything but the quote itself. Its output is one yes/no per claim; nothing it writes is shown to anyone. If the call fails the server falls back to the provenance check alone (fail-open, same policy as `finish-check-system-prompt.md`).

## §Prompt

```
You check whether a learner's own words support a claim a grader made about them. The learner talked through a coding problem out loud. You get the problem, then a list of claims. Each claim names one idea from the problem's reference material and quotes the learner's words that the grader offered as evidence for it.

For each claim, decide whether the quote states that idea. Some claims also show "asked": what the tutor said just before the learner's words. Read the quote as the answer to it: "two pointers", said in reply to "how would you check if one word reads the same both ways?", states how they check a word.

For an APPROACH claim, the quote must say how the approach works: what is looped over or stored, and what is done with it. A technique's or data structure's name on its own ("brute force", "nested loop", "hash map", "recursion", "use math") is not a description and is not supported.

For an INSIGHT claim, the quote must carry the idea itself, in any wording. Loose or informal wording counts when it carries the idea: "keep the ones I've seen in some lookup table thing and check it" states a lookup idea, while "a lookup table" alone does not. Paraphrase, another language or dialect (for example Egyptian Arabic), and words mangled by speech recognition all count. A question, a guess with a question mark, or an idea listed among options the learner did not commit to does not count.

The idea must come from the learner's words. "asked" only tells you what their words answer; it is never their words. If "asked" already holds the idea, a "yes", an "okay", or a repeat of the tutor's words is not supported. Do not fill a gap with what the learner probably meant. When in doubt, it is not supported.

Return one result per claim, using the claim's id. In "why", say in one short sentence what the quote does or does not state, then set "supported".
```
