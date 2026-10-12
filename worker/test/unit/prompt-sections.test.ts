import { describe, expect, it } from "vitest";
import { CONDENSE_PROMPT } from "../../src/prompts/condense";
import { TUTOR_PROMPT } from "../../src/prompts/tutor";

// prompts-verbatim.test.ts proves each copy equals its contract file. These
// pin the v8 / v2 additions (docs/tutor-focus-issues.md Issues 1 and 2) so
// that editing both copies in step cannot quietly drop one.
describe("tutor prompt v8", () => {
  it("answers a question before it nudges, and says so before HOW TO REPLY", () => {
    const answer = TUTOR_PROMPT.indexOf("ANSWER WHAT THEY ASK");
    expect(answer).toBeGreaterThan(-1);
    expect(answer).toBeLessThan(TUTOR_PROMPT.indexOf("HOW TO REPLY"));
    expect(TUTOR_PROMPT).toContain("the first sentence of your reply answers it");
  });

  it("lets the tutor judge a direction the learner named without that being the answer", () => {
    expect(TUTOR_PROMPT).toContain("Judging a direction they named is not giving the answer.");
    expect(TUTOR_PROMPT).toContain("That's the heart of the problem, so I'll let you find it");
  });

  it("points to Finish instead of inventing a question once everything is covered", () => {
    const works = TUTOR_PROMPT.indexOf("IF THEIR APPROACH WORKS, IT IS THE ANSWER.");
    const covered = TUTOR_PROMPT.indexOf("If what they have said in their own words already covers their approach, its edge cases, and its complexity");
    expect(covered).toBeGreaterThan(works);
    expect(covered).toBeLessThan(TUTOR_PROMPT.indexOf("NEVER ASK AGAIN ABOUT SOMETHING"));
    expect(TUTOR_PROMPT).toContain("Do not invent a question to fill the reply.");
  });

  it("reads the whole latest message and the summary before asking again", () => {
    const rule = TUTOR_PROMPT.indexOf("NEVER ASK AGAIN ABOUT SOMETHING");
    const read = TUTOR_PROMPT.indexOf("Read their whole latest message, not only its last sentence");
    expect(read).toBeGreaterThan(rule);
    expect(read).toBeLessThan(TUTOR_PROMPT.indexOf("If you have put the same question to them twice"));
  });
});

describe("condense prompt v2", () => {
  it("keeps the edge cases the learner has handled, second in priority", () => {
    const list = CONDENSE_PROMPT.slice(CONDENSE_PROMPT.indexOf("Keep, in this order of priority:"));
    const bullets = list.split("\n").filter((l) => l.startsWith("- "));
    expect(bullets[1]).toBe("- edge cases and inputs the learner has already handled, and how");
  });
});
