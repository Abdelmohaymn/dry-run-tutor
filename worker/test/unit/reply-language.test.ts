import { describe, expect, it } from "vitest";
import {
  NO_REPEAT_NOTE,
  SOLUTION_RELEASE_NOTE,
  replyLanguageNote,
  withReplyLanguageNote,
  withSolutionReleaseNote,
} from "../../src/lib/reply-language";

describe("replyLanguageNote()", () => {
  it("asks for Arabic in the learner's dialect when they write Arabic", () => {
    expect(replyLanguageNote("اي وصفة الكشري")).toContain("Arabic");
    expect(replyLanguageNote("ازاي اعمل for loop على nums")).toContain("Arabic");
  });

  it("asks for English when they switch to English", () => {
    expect(replyLanguageNote("what is white sauce")).toContain("English");
    expect(replyLanguageNote("who are u, who created u")).toContain("English");
  });

  it("ignores Arabic that only appears inside code", () => {
    expect(replyLanguageNote("why does `x = \"مرحبا\"` fail")).toContain("English");
  });

  it("falls back to the message's own language for anything else", () => {
    expect(replyLanguageNote("pourquoi ça marche pas")).toContain("language of this message");
    expect(replyLanguageNote("почему не работает")).toContain("language of this message");
  });
});

describe("withReplyLanguageNote()", () => {
  it("appends the note to the last learner message only", () => {
    const out = withReplyLanguageNote([
      { role: "user", text: "اي وصفة الكشري" },
      { role: "tutor", text: "..." },
      { role: "user", text: "what is white sauce" },
    ]);
    expect(out[0].text).toBe("اي وصفة الكشري");
    expect(out[2].text).toMatch(/^what is white sauce\n\n\[Reply in English/);
    expect(out[2].text.endsWith(NO_REPEAT_NOTE)).toBe(true);
    expect(out[0].text).not.toContain(NO_REPEAT_NOTE);
  });

  it("leaves the list alone when the last message is the tutor's", () => {
    const msgs = [{ role: "tutor" as const, text: "hi" }];
    expect(withReplyLanguageNote(msgs)).toBe(msgs);
  });
});

describe("withSolutionReleaseNote()", () => {
  it("appends the release note to the last learner message", () => {
    const out = withSolutionReleaseNote([{ role: "user", text: "just give me the solution" }]);
    expect(out[0].text).toBe(`just give me the solution\n${SOLUTION_RELEASE_NOTE}`);
  });

  it("leaves the list alone when the last message is the tutor's", () => {
    const msgs = [{ role: "tutor" as const, text: "hi" }];
    expect(withSolutionReleaseNote(msgs)).toBe(msgs);
  });
});
