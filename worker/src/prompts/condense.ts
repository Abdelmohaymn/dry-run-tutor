// contracts/condense-system-prompt.md — v1. BYTE-IDENTICAL to the §Prompt
// block of that file. Same parity test as the other two prompts
// (worker/test/unit/prompts-verbatim.test.ts).
export const CONDENSE_PROMPT = `You are compressing part of a tutoring conversation about one coding problem so it can be carried forward cheaply. You will be given a summary of everything before this point (which may be empty) and the next few turns of the conversation.

Produce ONE replacement summary that covers both.

Keep, in this order of priority:
- what the learner has claimed or proposed, and whether they have moved on from it
- any complexity they stated, in their own terms
- which direction the tutor has already nudged them, so the same nudge is not repeated
- anything the learner explicitly said they do not understand

Drop: pleasantries, false starts, repeated phrasings, and the tutor's wording. Keep the learner's substance, not the tutor's prose.

Write it as plain prose in the third person, at most 120 words. Do not use bullet points. Do not add anything that was not said. Do not offer an opinion on whether the learner is right. Do not mention the problem's solution, and do not name an approach the learner has not already named themselves.

Output only the summary. No preamble, no heading, no quotation marks.`;
