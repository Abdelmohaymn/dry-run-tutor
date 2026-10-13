# Finish check system prompt — v5

**Status**: authored 2026-10-04, versioned, **verbatim**.

**v5, 2026-10-13** — verified insights (`tasks/plans/PLAN_08_VERIFIED_INSIGHTS.md`, §1). Two playtest sessions: a learner who said only "nested loop" was credited "complement lookup, with a nudge" after the tutor asked an open question ("what could you do to avoid examining all those pairs?") and the learner tapped Finish; and "scan in array order", which only the tutor had stated, was shown as the learner's own words. Nothing checked the answer, and the prompt's "or ended the conversation right after it" invited the model to read Finish as acceptance. The answer now carries one `insights` list with a `learner_quote` and a `tutor_quote` per key, plus `named` as before; there is no `reached` or `assisted` list any more. The server checks each quote against the conversation (the PLAN_02 matcher) and decides "reached" or "assisted" itself: a learner quote found in a `user:` line is reached, a tutor quote found in a `tutor:` line is assisted, a learner quote found only in a `tutor:` line is assisted, and a quote found nowhere drops the key. Finishing right after a tutor question accepts nothing; finishing right after a tutor line that states the idea still counts.

**v4, 2026-10-12** — one source with the judge (`tasks/plans/PLAN_07_ONE_SOURCE_ASSISTED.md`). In the vp-0003 session the learner said "brute force", "return empty string", "two pointers technique"; the tutor said "checking each word in order until you hit a palindrome works" and explained the two pointers. The Finish card appeared, and the judge then said "Hard to call" with every insight missed, because the two graders used different prompts and the progress check ignored the tutor entirely. The check now receives the conversation with both roles, labelled `user:` / `tutor:`, and returns a second list, `assisted`: insights the tutor put into words and the learner accepted. A short answer is read with the tutor line it answers, so "two pointers" after "how would you check a word?" is `reached`. A tutor question that leaves the idea for the learner to find gives nothing, so PLAN_02's "nested loop plus an open tutor question earns nothing" still holds. `assisted` is stored on `device_day` (`assisted_keys`, migration 0012); it counts toward the Finish offer and the judge, and never toward the leak filter. `named` still reads `user:` lines only.

**v3, 2026-10-11** — the check also returns `named`: the problem's `never_say` terms the learner referred to in any form (the abbreviation, a speech-recognition mangling such as "tandem programming", or another language). The leak filter stopped blocking a term only on a literal match, so after "dynamic programming" the tutor's "Yes, DP fits" was blocked and its answer rewritten away (`docs/tutor-focus-issues.md`, Issue 1). `named` only unblocks words: it never marks an insight reached and never changes `ready`. It is stored on the session's `device_day` row (`named_terms`, migration 0011) and used from the NEXT turn, like `reached`.

**v2, 2026-10-07** — the check now returns WHICH insights the learner has stated, not one boolean, and the server derives `ready` from it (every `required: true` key reached). The same keys replace the word-overlap guess (`reachedInsightKeys`) as the leak filter's "already hit" set: on 60 paraphrases the guess caught 62% (0% in Egyptian Arabic) and marked a different insight 42% of the time, which switched the filter off for words the learner never said; this prompt caught 98% with 2% cross-marking (`specs/review-tutor-judge-findings.md` F4). The keys are stored on the session's `device_day` row and used from the NEXT turn, because the check runs alongside the reply.

**Implementer instruction (binding)**: copy the block under §Prompt into
`worker/src/prompts/finish-check.ts` as an exported const, byte-identically.
`test/unit/prompts-verbatim.test.ts` asserts the copy, and `worker/vitest.config.ts`
reads this file into `expectedPrompts`.

Runs once per conversational turn (from turn 1 since 2026-10-12; `finish_offer.min_turn`
gates only `ready_to_finish`), alongside the tutor
reply (`worker/src/lib/finish-check.ts`), and once more at judge time on the whole judged
conversation, including the tutor's last reply (`worker/src/lib/judge-core.ts`, PLAN_07 D6). The
judge-time run happens whatever `finish_offer.enabled` says, with `finish_offer.timeout_ms` as its
timeout, and nothing it returns is stored. Since v5 it is the only source of the assessment's
insight lists: the judge reads no stored keys, and the quotes in its answer go through the
evidence check (`evidence-check-system-prompt.md`; `ASSISTED` claims for tutor quotes) before the
judge model is shown the lists (PLAN_08 D3, D5). Its input is the problem statement, the
private key insights, the never_say terms, and the conversation with both roles, each line
labelled `user:` or `tutor:` (learner turns condensed out of the conversation come first as
`user:` lines; their tutor lines are gone, so a quote of theirs can only be the learner's).
Its output is, per insight, the learner's own words that state it and the tutor's words that
state it and that the learner accepted (`""` for either when there are none), and the terms the
learner named. The server decides what each quote is worth (`runFinishCheck`): a tutor that
names an idea cannot make the learner look like they stated it, because a learner quote found
only in a tutor line is `assisted`. It turns the kept keys into `reached` and `assisted`, `reached`
plus `assisted` into `ready_to_finish` on the meta frame, and `reached` alone into the leak
filter's "already hit" set (`assisted` never unblocks a word). The quotes live in memory for one
request: never stored, logged or returned. Its text is never shown to anyone; only authored
insight keys survive.

## §Prompt

```
You decide which key insights a learner, talking through a coding problem out loud with a tutor, has reached so far. You will be given the problem, its key insights by key, a list of terms, and the conversation so far, each line labelled "user:" (the learner) or "tutor:".

An insight is reached in one of two ways.

First, the learner stated it in their own words, in any wording. Paraphrase, informal phrasing, self-correction, another language or dialect (for example Egyptian Arabic), and words mangled by speech recognition all count; the final position is what matters. Read a short answer together with the tutor line it answers: "two pointers", said in reply to "how would you check if one word reads the same both ways?", states how they check a word. A technique's name that answers nothing ("brute force", "nested loop", "hash map") states no idea, even when the tutor's next line spells out what it could mean.

Second, a tutor line put the idea into words and the learner accepted it: they said yes, built on it, or carried on without disagreeing. The tutor line must contain the idea itself. A tutor question that leaves the idea for the learner to find ("what would you do on a mismatch?", "what could you do to avoid checking every pair?") gives nothing, even if the conversation ends right after it: ending the conversation is not an answer. Ending right after a tutor line that states the idea does count as accepting it. A tutor line the learner disagreed with, or a direction they later dropped, gives nothing.

An insight is not reached if the learner only asked about it, guessed at it with a question mark, listed it among options they rejected or left open, or if their latest position contradicts it. When in doubt, leave it out.

Ignore whether the learner has written code, stated a complexity, or covered edge cases, unless an insight is about exactly that.

For each insight reached, give its key and copy the evidence exactly as it appears in the conversation. "learner_quote" is the learner's own words that state the idea, copied from a "user:" line, or "" if they never stated it themselves. "tutor_quote" is the tutor's words that state the idea and that the learner accepted, copied from a "tutor:" line, or "" if there are none. Never put the tutor's words in "learner_quote". Leave out any insight for which both would be "".

You are also given a list of terms. Put a term in "named" if the learner has referred to it themselves, in any form: the full term, its abbreviation ("DP" for dynamic programming), a misspelling or speech-recognition mangling ("tandem programming"), or the same term in another language. Only "user:" lines count for "named". Naming a term is not reaching an insight: "named" never changes "insights".

Reply with JSON only: {"insights": [{"key": the insight's key, "learner_quote": "...", "tutor_quote": "..."}], "named": [the terms they referred to]}.
```
