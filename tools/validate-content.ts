#!/usr/bin/env -S node
// tools/validate-content.ts. Rules 0-10 from data-model.md §A1, plus 11 and 12.
// Rules 1-3 and 5-9 are a line-by-line port of tools/validate-content.py.
// Rules 0, 4 and 10 are new. Rule 10 (no private field reachable from the
// built manifest) is asserted over BUILD OUTPUT, not a single authored file
// — see tools/build-content.ts assertNoPrivateLeak() — so it is not
// evaluated here.
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { authoredProblemShape } from "./problem-schema";
import type { Problem } from "./problem-types";

export interface RuleFailure {
  rule: number;
  message: string;
}

export interface ValidationResult {
  problemId: string;
  failures: RuleFailure[];
  /** The rule-0-parsed object. Present only when rule 0 passed — build-content.ts's only use of it. */
  problem?: Problem;
}

const VERDICT_COVERAGE_NEEDED = ["optimal", "suboptimal", "wrong"] as const;

/** `leak-filter.ts`'s own normalisation, kept in step by hand: lowercase, every non-alphanumeric collapsed to one space. */
function normaliseForMatch(text: string): string {
  return text.toLowerCase().replace(/[^a-z0-9]+/g, " ").trim();
}

function wholeWordIn(haystack: string, needle: string): boolean {
  if (!needle) return false;
  return new RegExp(`\\b${needle.replace(/[.*+?^${}()|[\\]\\\\]/g, "\\\\$&")}\\b`).test(haystack);
}

function guessProblemId(raw: unknown): string {
  const pub = (raw as { public?: { id?: unknown } } | null)?.public;
  const id = pub && typeof pub === "object" ? (pub as { id?: unknown }).id : undefined;
  return typeof id === "string" ? id : "unknown";
}

/** Rules 0-9 over a single authored problem object. Rule 0 short-circuits: everything downstream assumes a structurally valid object. */
export function validateOne(raw: unknown): ValidationResult {
  const problemId = guessProblemId(raw);

  // Rule 0 — runs first. additionalProperties:false on every half catches a
  // field authored onto the wrong side (the real vp-0002/vp-0003 defect) and
  // an authored `hint_count` (build-injected, never authored) in one shot.
  const parsed = authoredProblemShape.safeParse(raw);
  if (!parsed.success) {
    const failures: RuleFailure[] = parsed.error.issues.map((issue) => ({
      rule: 0,
      message: `${issue.path.join(".") || "(root)"}: ${issue.message}`,
    }));
    return { problemId, failures };
  }

  const problem = parsed.data as unknown as Problem;
  const pub = problem.public;
  const priv = problem.private;
  const failures: RuleFailure[] = [];

  // rule 1
  if (pub.schema_version !== 2) {
    failures.push({ rule: 1, message: "schema_version must be 2" });
  }

  // rule 2
  const verdicts = new Set(priv.reference_approaches.map((a) => a.verdict));
  for (const need of VERDICT_COVERAGE_NEEDED) {
    if (!verdicts.has(need)) {
      failures.push({ rule: 2, message: `missing a '${need}' reference approach` });
    }
  }

  // rule 3
  const approachKeys = new Set(priv.reference_approaches.map((a) => a.key));
  for (const followup of priv.followups) {
    for (const when of followup.when_approach) {
      if (when !== "*" && !approachKeys.has(when)) {
        failures.push({
          rule: 3,
          message: `followup '${followup.id}' -> unknown approach '${when}'`,
        });
      }
    }
  }

  // rule 4 (new) — no orphan insight keys: unique, non-empty, ^[a-z0-9_]+$
  const seenInsightKeys = new Map<string, number>();
  for (const insight of priv.key_insights) {
    seenInsightKeys.set(insight.key, (seenInsightKeys.get(insight.key) ?? 0) + 1);
    if (!/^[a-z0-9_]+$/.test(insight.key)) {
      failures.push({ rule: 4, message: `insight key '${insight.key}' must match ^[a-z0-9_]+$` });
    }
  }
  for (const [key, count] of seenInsightKeys) {
    if (count > 1) {
      failures.push({ rule: 4, message: `duplicate insight key '${key}'` });
    }
  }

  // rules 5, 6, 9 — per insight
  for (const insight of priv.key_insights) {
    if (insight.hints.length !== 3) {
      failures.push({
        rule: 5,
        message: `insight '${insight.key}' needs exactly 3 hints, has ${insight.hints.length}`,
      });
    }
    if (insight.never_say.length === 0) {
      failures.push({ rule: 6, message: `insight '${insight.key}' has empty never_say` });
    }
    for (const term of insight.never_say) {
      insight.hints.forEach((rung, i) => {
        if (rung.toLowerCase().includes(term.toLowerCase())) {
          failures.push({
            rule: 9,
            message: `insight '${insight.key}' LEAKS never_say term '${term}' in hint rung ${i + 1}`,
          });
        }
      });
    }
  }

  // rule 11 — a never_say term that is ALREADY PUBLIC.
  //
  // `never_say` exists to stop the tutor handing over a word that would
  // resolve an insight the learner has not reached. A phrase that is
  // already printed on the learner's own screen resolves nothing: it is
  // not a leak, it is vocabulary they can read. Blocking it only means
  // `leak-filter.ts` discards good tutor replies WHOLE and substitutes the
  // canned fallback, which is what the learner then reads instead.
  //
  // Found on a physical device (2026-09-04): `vp-0003` blocked "in order",
  // which appears verbatim in its own public statement ("Find the first
  // one, in order, ..."). Any tutor sentence containing the ordinary
  // English phrase "in order" was thrown away mid-conversation.
  //
  // Whole-word matching, mirroring `leak-filter.ts`'s own predicate — a
  // term is only "already public" if the filter would actually fire on the
  // public text.
  const publicText = normaliseForMatch(
    [pub.statement, ...pub.constraints, ...(pub.examples ?? []).flatMap((e) => [e.input, e.output, e.explanation ?? ""])].join(" "),
  );
  for (const insight of priv.key_insights) {
    for (const term of insight.never_say) {
      if (wholeWordIn(publicText, normaliseForMatch(term))) {
        failures.push({
          rule: 11,
          message: `insight '${insight.key}' never_say term '${term}' already appears in the problem's own public half — blocking it discards good tutor replies without hiding anything`,
        });
      }
    }
  }

  // rule 12 — tags are lowercase words split by single spaces, so one idea
  // has one spelling. The vp-0009..0038 batch arrived with `two-pointers` and
  // `two_pointers` next to the existing `two pointers`.
  for (const tag of pub.tags) {
    if (!/^[a-z]+( [a-z]+)*$/.test(tag)) {
      failures.push({ rule: 12, message: `tag '${tag}' must be lowercase words split by single spaces, like 'two pointers'` });
    }
  }

  // rules 7, 8 — per wrong turn
  for (const wrongTurn of priv.common_wrong_turns) {
    if (!wrongTurn.counter_question) {
      failures.push({ rule: 7, message: `wrong turn '${wrongTurn.key}' missing counter_question` });
    } else if (!/\?\s*$/.test(wrongTurn.counter_question.trim())) {
      failures.push({
        rule: 8,
        message: `wrong turn '${wrongTurn.key}' counter_question must be a question (end in '?')`,
      });
    }
    if (!wrongTurn.failing_case) {
      failures.push({ rule: 7, message: `wrong turn '${wrongTurn.key}' missing failing_case` });
    }
  }

  return { problemId, failures, problem };
}

export function validateAll(problems: unknown[]): ValidationResult[] {
  return problems.map(validateOne);
}

function loadProblemFile(filePath: string): unknown[] {
  const doc = JSON.parse(readFileSync(filePath, "utf-8"));
  if (doc && typeof doc === "object" && "problems" in doc && Array.isArray((doc as any).problems)) {
    return (doc as any).problems;
  }
  return [doc];
}

function defaultTargets(): string[] {
  const dir = path.resolve("../content/problems");
  try {
    return readdirSync(dir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => path.join(dir, f));
  } catch {
    return [];
  }
}

function main(argv: string[]): number {
  const targets = argv.length > 0 ? argv : defaultTargets();
  let total = 0;
  for (const target of targets) {
    const problems = loadProblemFile(target);
    for (const raw of problems) {
      const { problemId, failures } = validateOne(raw);
      if (failures.length > 0) {
        total += failures.length;
        console.log(`\n  ${problemId}  (${path.basename(target)})`);
        for (const f of failures) {
          console.log(`     rule${f.rule}  ${f.message}`);
        }
      }
    }
  }
  console.log(`\n${total ? "FAIL" : "PASS"}: ${total} problem(s) issue(s)`);
  return total ? 1 : 0;
}

const isMain = Boolean(process.argv[1]) && path.resolve(process.argv[1]!) === fileURLToPath(import.meta.url);
if (isMain) {
  process.exit(main(process.argv.slice(2)));
}
