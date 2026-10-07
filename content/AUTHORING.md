# Adding problems

How a new `content/problems/vp-NNNN.json` gets written, checked and shipped. Every step here is in the repo, so a person or an AI can run it without the session that wrote the last batch.

## The short version

1. Pick the problem and the next free id.
2. Write `content/problems/vp-NNNN.json` (rules below).
3. Write `tools/ref-solutions/vp-NNNN.py`: a correct solution plus the constraint checks.
4. From `worker/`, run `npm run check:content` until it passes.
5. Review the private half with a fresh pair of eyes (checklist below) and fix what it finds.
6. Do the hand checks, then run `npm run check:content` again.
7. Ship: `npm run build:content && npx wrangler deploy` from `worker/`. Nothing reaches the phone before this.

## 1. Picking problems

- Easy problems only, with no images or diagrams in the original.
- See what's already in: `grep -h '"source"' content/problems/*.json`. Skip any LeetCode problem already listed.
- Avoid two problems with the same core trick back to back (two hash-map lookups in a row, say).
- Next free id: the highest `vp-NNNN` in `content/problems/` plus one.

## 2. Writing rules

Match `vp-0004.json` and `vp-0006.json` for structure, depth and tone.

**Public half**

- `title` and `statement`: our own words, same meaning as the original. Never LeetCode's wording. Give it an original title.
- `examples`: 2 or 3, **our own values**. Never reuse LeetCode's example inputs. Cover one normal case and one edge case. Every input must satisfy the constraints you list, and every output must be right. `verify-examples` checks both.
- Example `input` is `name = value` pairs split by commas, with Python-literal values: `nums = [1, 2], target = 3`. Example `output` is JSON: `true`, `"abc"`, `[1, 2]`, `4.0`. If an output can't be JSON (see vp-0027), the reference solution needs a `same()` function.
- `constraints`: restate the original's facts. Keeping the numbers is fine.
- `source`: `"Plus One (LeetCode 66)"`.
- `tags`: lowercase words split by single spaces. Reuse existing tags: `two pointers`, never `two-pointers` or `two_pointers`. Validator rule 12 enforces the format.
- Usual values: `ramp` `"easy"`, `difficulty` 600 to 950, `collections` `["starter"]`, `est_speak_seconds` 60 to 90.

**Private half**, written from scratch, never copied from any editorial:

- `reference_approaches`: at least one `optimal`, one `suboptimal` and one `wrong`. `acceptable` is optional. A `suboptimal` approach must still give correct answers. A `wrong` approach must really give a wrong answer on some input.
- `requires` on an approach: the insight keys **that approach** needs for a pass. Every `acceptable` approach must have it (validator rule 13), listing only what it actually needs. `required: true` on an insight describes the optimal approach; without `requires`, a perfect explanation of an acceptable approach is capped at borderline.
- `key_insights`: exactly 3 hints each, climbing toward the insight without stating it.
- Insight `text`: one sentence, at most 25 words, in the words a learner would say out loud. Not editorial prose (rule 16).
- `never_say`: phrases that would hand the insight over.
  - A phrase that **names** the insight, not ordinary vocabulary. No single common word (index, map, set, list, loop, sort, first, base case). If a word would appear in a normal explanation of the problem statement, it does not belong (rule 15). Every blocked word costs a rewrite or a cut reply when the tutor uses it innocently.
  - A term must not appear inside its own insight's hints, even as part of a word ("most recent" inside "most recently" fails).
  - A term must not appear as a whole word in the public statement, constraints or examples. If it does, drop the term instead of rewording the public text.
- `common_wrong_turns`: `counter_question` ends in `?`. `failing_case` is a concrete input where that wrong idea gives a wrong output, and says what the output is.
  - `text` and `counter_question` go into every tutor prompt, so neither may contain a `never_say` term (rule 14).
- `sketch` lines are full sentences. A short line like "Return k" also appears in some public text and the build's leak check refuses it.
- `followups.when_approach` uses existing approach keys or `"*"`.

**Voice:** short, plain, human. Use `--`, not em-dashes.

## 3. Reference solution

`tools/ref-solutions/vp-NNNN.py` defines:

```python
def solve(nums, target):        # a correct solution; argument names match the example inputs
    ...

def check_input(nums, target):  # assert every public constraint
    assert 2 <= len(nums) <= 10**7
    ...

def same(got, want, inputs):    # optional: custom compare for non-JSON outputs,
    ...                         # or when several answers are right
```

- If the problem changes a list in place, return that list (vp-0015, vp-0021).
- If the problem hides something behind an API call like `isBad(v)`, take the hidden value as an input and only reach it through the call (vp-0029).
- Assert **every** constraint, including guarantees like "exactly one answer" or "sorted". A broken guarantee was one of the errors caught in the vp-0009 to vp-0038 batch.
- Keep `solve()` simple and obviously correct. It is the answer key, not a showcase.

## 4. Automatic checks

From `worker/`:

```bash
npm run check:content
```

This runs three checks in order and stops at the first failure:

| Script | Catches |
|---|---|
| `validate:content` | Structure: missing fields, missing verdicts, hint counts, `never_say` leaks, tag format. Since 2026-10-07 also: `requires` on acceptable approaches, `never_say` in wrong-turn text, common words in `never_say`, insight text over 25 words (rules 13 to 16, see §8) |
| `verify:examples` | An example whose input breaks a constraint or whose output is wrong. Also a problem with no reference solution |
| `build:content` | Private text leaking into the public manifest |

Pass file paths to check only some problems: `npm run validate:content -- ../content/problems/vp-0039.json`, and `python3 ../tools/verify-examples.py ../content/problems/vp-0039.json`.

CI runs `validate:content` and `verify:examples` on every change under `content/`.

## 5. Review checklist

The automatic checks prove structure and examples. They can't tell whether a complexity, a verdict or a failing case is **true**. In the vp-0009 to vp-0038 batch, this review found 8 real errors that every automatic check had passed.

The reviewer must not be the author. Give a fresh AI agent (or a person) this prompt, 10 files at most per reviewer:

> You are a strict reviewer of coding-interview tutor content. Files: `content/problems/vp-XXXX.json` to `vp-YYYY.json`. Read `content/problems/vp-0006.json` as the quality reference. The public examples are already verified by `tools/verify-examples.py`; focus on the `private` half, but flag anything wrong in public too.
>
> Do NOT edit any file. Report findings only.
>
> For each file check:
> 1. `reference_approaches`: is each sketch correct for that approach? Are time and space complexities right? Is each verdict right? `optimal` = best known. `suboptimal` = correct but slower or heavier. `wrong` = gives wrong answers on some input. A `wrong` approach must really be wrong; a `suboptimal` one must really be correct.
> 2. `key_insights`: is each one true? Do the 3 hints climb toward it without giving it away? Does each `never_say` term actually hand over that insight?
>    2a. For each `acceptable` approach: would a learner who explains it perfectly hit every key in its `requires`? Is anything in `requires` actually specific to a different approach?
> 3. `common_wrong_turns`: is `why_it_fails` accurate? Is `failing_case` concrete, and does it really fail? Run a small Python script for every failing case. Every number claimed must be right.
> 4. `edge_cases` are correct. Each followup's `model_answer` is technically correct.
> 5. `editorial` is correct and doesn't contradict the approaches.
> 6. The statement has the same meaning as the original LeetCode problem, and the wording isn't copied.
>
> Output concrete defects only, each as: file | field path | what's wrong | suggested fix. Separate "real errors" (factually or technically wrong) from "minor" (style, weak hint). Say "clean" for a clean file. Don't pad.

Fix every real error. Fix minor ones unless there's a reason not to, and note the reason.

Errors this review has caught before, so they're worth a second look:

- A failing case that actually gives the right answer.
- A correct approach labelled `wrong`, or a correct loop style called a bug.
- A follow-up answer claiming a data structure does something it doesn't.
- A failing case built on a tie, so it proves nothing.
- Claims about language behaviour (overflow, set ordering) that are wrong or only true in one language.

## 6. Hand checks

After the review fixes:

- Read each statement next to the original once. Same meaning, different words?
- Work one example per problem out by hand.
- Tags: reuse the spelling already in other files. See the list with `python3 -c "import json,glob; print(sorted({t for f in glob.glob('content/problems/vp-*.json') for t in json.load(open(f))['public']['tags']}))"`.
- `npm run check:content` passes again after the last edit.

## 7. Ship

- Commit the problem file and its reference solution together.
- `npm run build:content && npx wrangler deploy` from `worker/`. `src/generated/` is gitignored and wrangler has no build hook, so deploy ships whatever was built last.
- Playtest a few on the phone with the live tutor: once with a good answer, once slow, once wrong. See `problems/PLAYTEST.md`. This is the only step that tests how the tutor actually behaves.

## Harness corpus

Only vp-0000 to vp-0003 have tutor and judge corpus files in `worker/test/harness/corpus/`. A new problem does not need one. `worker/test/unit/harness-corpus.test.ts` checks only the corpora that exist.

## 8. Problems written before 2026-10-07

The tutor and judge review (`specs/review-tutor-judge-findings.md`) added four validator rules, 13 to 16. A problem written before them still **runs** fine:
- An approach without `requires` falls back to the problem's required insights.
- The progress check reads any problem's insight keys.

It **fails `npm run check:content`**, though, and that blocks the build. When the 38 problems in the private repo were checked against these rules, 37 of them failed, with 118 issues.

| Rule | Message | Fix |
|---|---|---|
| 13 | `acceptable approach 'x' must author 'requires'` | Add `"requires": [...]` to that approach: the insight keys a learner on **that** approach must state. Often fewer than the problem's required set, sometimes none of the optimal-approach insights. Ask: "if someone explained this approach perfectly, which insights would they have said?" |
| 14 | `wrong turn 'x' text or counter_question uses never_say term` | Reword the wrong turn's `text` or `counter_question` without the term. It is sent to the tutor, which then gets blocked for saying it. |
| 15 | `never_say term 'x' is ordinary vocabulary` | Drop the word, or replace it with a phrase that names the insight ("store the index as the value", not "index"). |
| 16 | `insight 'x' text has N words` | Rewrite as one sentence of 25 words or fewer, the way a learner would say it out loud. Keep the meaning: the judge and the progress check match against this text. |

Fix one batch of 10 at a time. You can give this prompt to an AI agent:

> Fix the validator failures in `content/problems/vp-XXXX.json` to `vp-YYYY.json`. Run `npm run validate:content -- <files>` from `worker/` and fix only what it reports, following `content/AUTHORING.md` §2 and §8. Do not change `public`, hints, `reference_approaches[].verdict`, examples or the editorial. For rule 13, decide `requires` from the approach's own sketch. For rule 16, keep each insight's meaning exactly. Report each change as file | field | before | after.

Then:
1. Review the `requires` choices by hand. They decide whether a learner gets `pass` or `borderline`. This is the one change that can make the judge harsher or softer.
2. `npm run check:content` passes.
3. If the problem has a harness corpus, run `npm run test:harness` (see `docs/switching-models.md` §2).

## 9. What the tutor does with a new problem

Nothing to configure. Once a problem passes the checks and is built and deployed:
- The tutor gets its statement, constraints, approach names and wrong turns.
- The progress check gets its insight keys and texts.
- The leak filter gets its `never_say` lists.
- The judge gets the full private half, including each approach's `requires`.

The quality of the content is the quality of the session. The rules above exist because each one caused a real failure in the review.

