# Condensation system prompt — v1

**Status**: authored 2026-08-20, versioned, **verbatim**.

**Implementer instruction (binding)**: copy the block under §Prompt into `worker/src/prompts/condense.ts` as an exported const, byte-identically. Do not paraphrase, do not "improve", do not reflow. `test/unit/prompts-verbatim.test.ts` asserts the copy.

This is the cheapest of the three prompts and the only one whose output is fed back into another prompt. It runs on `config.trim.condense_model` against only the turns newly falling out of the verbatim window (`data-model.md` §B6) — never the whole history, which is what keeps SC-007a's linearity claim true.

---

## §Prompt

```
You are compressing part of a tutoring conversation about one coding problem so it can be carried forward cheaply. You will be given a summary of everything before this point (which may be empty) and the next few turns of the conversation.

Produce ONE replacement summary that covers both.

Keep, in this order of priority:
- what the learner has claimed or proposed, and whether they have moved on from it
- any complexity they stated, in their own terms
- which direction the tutor has already nudged them, so the same nudge is not repeated
- anything the learner explicitly said they do not understand

Drop: pleasantries, false starts, repeated phrasings, and the tutor's wording. Keep the learner's substance, not the tutor's prose.

Write it as plain prose in the third person, at most 120 words. Do not use bullet points. Do not add anything that was not said. Do not offer an opinion on whether the learner is right. Do not mention the problem's solution, and do not name an approach the learner has not already named themselves.

Output only the summary. No preamble, no heading, no quotation marks.
```

---

## §Model configuration

```
provider:   from runtime_config.provider              # NOT a constant
model:      from runtime_config.trim.condense_model   # NOT a constant
max_tokens: 200
temperature: 0
stream:     false
```

`max_tokens: 200` is the ~100-output-token line of `research.md` R-007's budget table with headroom. Raising it raises the per-session cost linearly, so it is a quota lever in all but name.

---

## §Enforcement

| Guarantee | Enforced by | Spec |
|---|---|---|
| The summary is never retained server-side | it is returned in the SSE `meta` frame and written nowhere | FR-010a, FR-010b |
| The summary is never trusted for control flow | `turn-cap.ts` §B2 reads D1; the summary is content only | FR-010c |
| A turn is condensed once, not once per later request | only `falling` is ever sent, `data-model.md` §B6 | SC-007a |
| Nothing private leaks through the condenser | its input is the conversation only — never the ground-truth slice, never the editorial | FR-007 |

The last row matters more than it looks: the condenser sees conversation text and nothing else, so a leak cannot enter the session through this path even though its output is replayed into the next tutor prompt.

---

## §Change control

Any diff to this file triggers `test/harness/tutor.harness.test.ts` in CI, because a condensation change alters what every later tutor turn sees. It also triggers `test/unit/condense.linear.test.ts` (**SC-007a**) and should be re-measured against `quickstart.md` §6.
