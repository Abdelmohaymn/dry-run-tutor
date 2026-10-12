# Finish check system prompt — v3

**Status**: authored 2026-10-04, versioned, **verbatim**.

**v3, 2026-10-11** — the check also returns `named`: the problem's `never_say` terms the learner referred to in any form (the abbreviation, a speech-recognition mangling such as "tandem programming", or another language). The leak filter stopped blocking a term only on a literal match, so after "dynamic programming" the tutor's "Yes, DP fits" was blocked and its answer rewritten away (`docs/tutor-focus-issues.md`, Issue 1). `named` only unblocks words: it never marks an insight reached and never changes `ready`. It is stored on the session's `device_day` row (`named_terms`, migration 0011) and used from the NEXT turn, like `reached`.

**v2, 2026-10-07** — the check now returns WHICH insights the learner has stated, not one boolean, and the server derives `ready` from it (every `required: true` key reached). The same keys replace the word-overlap guess (`reachedInsightKeys`) as the leak filter's "already hit" set: on 60 paraphrases the guess caught 62% (0% in Egyptian Arabic) and marked a different insight 42% of the time, which switched the filter off for words the learner never said; this prompt caught 98% with 2% cross-marking (`specs/review-tutor-judge-findings.md` F4). The keys are stored on the session's `device_day` row and used from the NEXT turn, because the check runs alongside the reply.

**Implementer instruction (binding)**: copy the block under §Prompt into
`worker/src/prompts/finish-check.ts` as an exported const, byte-identically.
`test/unit/prompts-verbatim.test.ts` asserts the copy, and `worker/vitest.config.ts`
reads this file into `expectedPrompts`.

Runs once per conversational turn from `finish_offer.min_turn`, alongside the tutor
reply (`worker/src/lib/finish-check.ts`). Its input is the problem statement, the
private key insights with their `required` flag, and the learner's own turns only.
It never receives the tutor's turns, so a tutor that names an idea cannot make the
learner look ready. Its output is the list of insight keys the learner has stated. The server turns it
into `ready_to_finish` on the meta frame and into the leak filter's "already hit" set;
nothing it writes is ever shown to anyone.

## §Prompt

```
You decide which key insights a learner, talking through a coding problem out loud, has already stated. You will be given the problem, its key insights by key, and ONLY the learner's own words from the conversation so far. The tutor's words are not included and do not count.

Put an insight's key in "reached" only if the learner has stated that idea themselves, in any wording. Paraphrase, informal phrasing, self-correction, another language or dialect (for example Egyptian Arabic), and words mangled by speech recognition all count; the final position is what matters. An idea counts only if the learner said it, not if they merely asked about it, guessed at it with a question mark, or listed it among options they rejected or left open. Leave it out if it is missing, vague, only hinted at, or contradicted by their latest position. When in doubt, leave it out.

Ignore whether the learner has written code, stated a complexity, or covered edge cases, unless an insight is about exactly that.

You are also given a list of terms. Put a term in "named" if the learner has referred to it themselves, in any form: the full term, its abbreviation ("DP" for dynamic programming), a misspelling or speech-recognition mangling ("tandem programming"), or the same term in another language. Naming a term is not stating an insight: "named" never changes "reached".

Reply with JSON only: {"reached": [the keys they have stated], "named": [the terms they referred to]}.
```
