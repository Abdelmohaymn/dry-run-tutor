// The tutor prompt says to reply in the language of the learner's most
// recent message, but the trial-pool models weigh the conversation's
// opening language over a rule buried mid-prompt: a session started in
// Arabic kept answering English questions in Arabic (2026-10-02). A short
// note on the last user message, right where the model reads last, holds.
import type { ProviderMessage } from "./provider";

const ARABIC_LETTER = /[؀-ۿݐ-ݿࢠ-ࣿ]/g;
const NON_ASCII = /[^\u0000-\u007F]/;
const ENGLISH_WORD =
  /\b(the|is|are|what|how|why|who|can|do|does|i|you|u|it|this|that|and|or|not|my|me|a|an|to|of|in|for|with|use|should|would)\b/i;
const CODE = /```[\s\S]*?```|`[^`\n]*`/g;

export function replyLanguageNote(text: string): string {
  const prose = text.replace(CODE, " ");
  // Two letters, not one: a lone character pasted from elsewhere is not a
  // switch of language. An English speaker never types two Arabic letters.
  if ((prose.match(ARABIC_LETTER) ?? []).length >= 2) {
    return "[Reply in Arabic, in the same dialect as this message, even if earlier messages were in another language.]";
  }
  // Accented letters mean French, Spanish and the like, which get the
  // generic note: "ça" would otherwise match the English word "a".
  if (!NON_ASCII.test(prose) && ENGLISH_WORD.test(prose)) {
    return "[Reply in English, even if earlier messages were in another language.]";
  }
  return "[Reply in the language of this message, even if earlier messages were in another language.]";
}

/** Appends the note to the last message when it is the learner's. */
export function withReplyLanguageNote(messages: ProviderMessage[]): ProviderMessage[] {
  const last = messages[messages.length - 1];
  if (!last || last.role !== "user") return messages;
  return [...messages.slice(0, -1), { role: "user", text: `${last.text}\n\n${replyLanguageNote(last.text)}` }];
}
