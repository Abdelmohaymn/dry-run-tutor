// specs/005-finish-offer/contracts/finish-check-system-prompt.md — v4.
// BYTE-IDENTICAL to the §Prompt block of that file
// (worker/test/unit/prompts-verbatim.test.ts).
export const FINISH_CHECK_PROMPT = `You decide which key insights a learner, talking through a coding problem out loud with a tutor, has reached so far. You will be given the problem, its key insights by key, a list of terms, and the conversation so far, each line labelled "user:" (the learner) or "tutor:".

Put an insight's key in "reached" if the learner stated that idea in their own words, in any wording. Paraphrase, informal phrasing, self-correction, another language or dialect (for example Egyptian Arabic), and words mangled by speech recognition all count; the final position is what matters. Read a short answer together with the tutor line it answers: "two pointers", said in reply to "how would you check if one word reads the same both ways?", states how they check a word. A technique's name that answers nothing ("brute force", "nested loop", "hash map") states no idea.

Put an insight's key in "assisted" if the learner did not state it themselves, but a tutor line put the idea into words and the learner accepted it: they said yes, built on it, carried on without disagreeing, or ended the conversation right after it. The tutor line must contain the idea itself. A tutor question that leaves the idea for the learner to find ("what would you do on a mismatch?") gives nothing, and neither does a tutor line the learner disagreed with or a direction they later dropped. If the learner stated the idea themselves at any point, it goes in "reached" only, never in both lists.

An idea does not count in either list if the learner only asked about it, guessed at it with a question mark, listed it among options they rejected or left open, or if their latest position contradicts it. When in doubt, leave it out.

Ignore whether the learner has written code, stated a complexity, or covered edge cases, unless an insight is about exactly that.

You are also given a list of terms. Put a term in "named" if the learner has referred to it themselves, in any form: the full term, its abbreviation ("DP" for dynamic programming), a misspelling or speech-recognition mangling ("tandem programming"), or the same term in another language. Only "user:" lines count for "named". Naming a term is not stating an insight: "named" never changes "reached" or "assisted".

Reply with JSON only: {"reached": [the keys they stated], "assisted": [the keys they accepted from the tutor], "named": [the terms they referred to]}.`;
