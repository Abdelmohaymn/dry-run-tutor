# Playtest log

Per `tasks.md` T081: each seed problem voice-playtested three times against the live tutor and judge — once optimal, once suboptimal, once deliberately wrong. Run 2026-08-21 against a real Groq key, `wrangler dev --env dev` on `localhost:8787`, model `openai/gpt-oss-120b`.

Content note: `vp-0002` and `vp-0003` were authored this session from the corresponding LeetCode problems (Add Digits / Find First Palindromic String in the Array) at the user's explicit direction, as a test of AI-authored content quality standing in for the human-authoring step `tasks.md` T079/T080 otherwise calls for. Passing `npm run validate:content` and all nine playtests below is a first-pass quality bar, not a substitute for a human editorial review before this content is treated as final — see `DONE.md`'s open items.

For every scenario below: **the tutor withheld the solution** (no reply named a reference approach outright or gave the answer away; `session_ended` stayed `null`) and asked a probing question or counter-question instead.

## vp-0001 — Pair Sum

| Scenario | Learner turn | Tutor reply | Verdict |
|---|---|---|---|
| Optimal | "I would use a hash map storing value to index, checking the complement before inserting, one pass." | "That's exactly the right strategy. Once you spot the complement, how will you format the two indices you return—do you need to consider their order?" | `strong_pass` / `hashmap` |
| Suboptimal | "I would check every pair with two nested loops until I find the two that add up." | "If the list has ten million items, roughly how many element-pairs would your double loop have to examine? Does that seem doable in under a second?" | `likely_tle` / `brute_force` |
| Wrong | "I would sort the values and use two pointers without tracking the original positions." | "If you sort the values first, what happens to the positions you were asked to return?" | `incorrect` / `sort_lose_indices` |

## vp-0002 — Add Digits

| Scenario | Learner turn | Tutor reply | Verdict |
|---|---|---|---|
| Optimal | "I would use the formula: if the number is 0 return 0, otherwise return 1 plus the remainder of number minus 1 divided by 9." | "That's the right idea. As a quick sanity check, what does your formula give for an input like 9 (or 18)?" | `strong_pass` / `digital_root_formula` |
| Suboptimal | "I would convert the number to a string, sum the digit characters, and recursively call the same function until one digit remains." | "That will work as long as you know when to stop the recursion. How will you detect that the current sum is already a single-digit value before calling the function again?" | `likely_tle` / `string_conversion_sum` |
| Wrong | "I would just sum all the digits once and return that sum." | "What happens if the digits you add up themselves add up to a number like 12 or 27—does your method stop there, or does it keep going until there's just one digit left?" | `incorrect` / `single_pass_no_repeat` |

## vp-0003 — First Palindromic String

| Scenario | Learner turn | Tutor reply | Verdict |
|---|---|---|---|
| Optimal | "I would scan the words in order and check each one with two pointers from both ends moving inward, returning the first one that matches." | "Exactly—stop as soon as you hit a word that passes the two-pointer test. What will you return if you get through the whole list without finding any palindrome?" | `pass` / `two_pointer_scan` |
| Suboptimal | "I would collect every palindromic word into a list first by scanning the whole array, then return the first entry of that list." | "That would work, but once you spot a palindrome, do you really need to keep checking the rest of the words before you can decide which one to return?" | `likely_tle` / `collect_all_then_first` |
| Wrong | "I would check whether each word could be rearranged into a palindrome by counting how many times each letter appears, and return the first one where at most one letter has an odd count." | "Does the problem ask for the word itself to read the same forward and backward, or just for its letters to be rearrangeable into a palindrome?" | `incorrect` / `char_frequency_check` |

## Summary

**9/9 land the correct verdict family and the correct matched approach; the tutor held the solution back in all nine.** No leak-filter trip occurred in any of these nine specific conversations (all `leak_blocked: false`) — a `leak_blocked: true` event *has* been observed live on `vp-0001` in a separate manual test (the "sort first, two pointers" wrong turn, outside this specific nine-run set), confirming the runtime safety net does fire on real model output when it needs to, not just in stubbed tests.
