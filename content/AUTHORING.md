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
- `key_insights`: exactly 3 hints each, climbing toward the insight without stating it.
- `never_say`: phrases that would hand the insight over.
  - A term must not appear inside its own insight's hints, even as part of a word ("most recent" inside "most recently" fails).
  - A term must not appear as a whole word in the public statement, constraints or examples. If it does, drop the term instead of rewording the public text.
- `common_wrong_turns`: `counter_question` ends in `?`. `failing_case` is a concrete input where that wrong idea gives a wrong output, and says what the output is.
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
| `validate:content` | Structure: missing fields, missing verdicts, hint counts, `never_say` leaks, tag format |
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
