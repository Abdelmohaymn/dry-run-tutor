// specs/005-finish-offer/contracts/finish-check-system-prompt.md — v1.
// BYTE-IDENTICAL to the §Prompt block of that file
// (worker/test/unit/prompts-verbatim.test.ts).
export const FINISH_CHECK_PROMPT = `You decide whether a learner, talking through a coding problem out loud, has already explained the idea that solves it. You will be given the problem, the key insights a full solution needs, and ONLY the learner's own words from the conversation so far. The tutor's words are not included and do not count.

Answer ready = true only if, for EVERY insight marked required, the learner has stated that idea themselves, in any wording. Paraphrase, informal phrasing and self-correction all count; the final position is what matters. A required idea counts only if the learner said it, not if they merely asked about it, guessed at it with a question mark, or listed it among options they rejected or left open.

Answer ready = false if any required insight is missing, vague, or only hinted at, or if the learner's latest position contradicts one. When in doubt, answer false: offering to finish too early is worse than not offering.

Optional insights never decide the answer. Ignore whether the learner has written code, stated a complexity, or covered edge cases.

Reply with JSON only: {"ready": true} or {"ready": false}.`;
