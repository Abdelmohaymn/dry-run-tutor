// Module-scope Zod schemas transcribed from contracts/openapi.yaml and
// contracts/event.schema.json, including every additionalProperties:false,
// minItems/maxItems and pattern constraint.
import { z } from "zod";

export const turnSchema = z
  .object({
    role: z.enum(["user", "tutor"]),
    text: z.string().min(1).max(8000),
  })
  .strict();

const problemIdSchema = z.string().regex(/^vp-\d{4}$/);

// The bare object, kept un-refined so `trialRequestSchema` below can still
// `.extend({ mode })` it — `.superRefine()` returns a wrapper that cannot.
const chatRequestObject = z
  .object({
    problem_id: problemIdSchema,
    messages: z.array(turnSchema).max(40),
    summary: z.string().max(4000).optional(),
    // The learner's own turns already folded into `summary`, oldest first.
    // Read only to decide which words the learner has said and which
    // insights they have reached; never sent to the provider.
    earlier_learner_turns: z.array(z.string().min(1).max(8000)).max(40).optional(),
    hint_requested: z.boolean().default(false),
    solution_request_count: z.number().int().min(0).default(0),
    // Key check on save: see runKeyCheck() in chat-core.ts. /v1/chat only;
    // the trial schema omits it.
    key_check: z.boolean().default(false),
    // Feature 005: the learner chose Keep going, so no finish check runs
    // for the rest of the session.
    finish_offer_dismissed: z.boolean().default(false),
  })
  .strict();

/**
 * A conversational turn needs something to respond to, so `messages` stays
 * effectively `.min(1)` on that path. A hint pull does not: `runHintTurn`
 * reads the authored ladder and never looks at `messages` at all, and
 * US3 scenario 4 requires pulling a hint *before the learner has said
 * anything* — which is exactly an empty array. Enforcing `.min(1)` for
 * both collapsed those two cases and made every pre-turn hint a 400.
 */
function requireMessagesUnlessHint(
  value: { messages: readonly unknown[]; hint_requested: boolean },
  ctx: z.RefinementCtx,
): void {
  if (!value.hint_requested && value.messages.length < 1) {
    ctx.addIssue({
      code: "custom",
      path: ["messages"],
      message: "messages must hold at least one turn unless hint_requested is true",
    });
  }
}

export const chatRequestSchema = chatRequestObject.superRefine(requireMessagesUnlessHint);

// Without `key_check`: the turn code never sees it (chat.ts branches on it
// first), and the trial body, which omits it, must still fit this type.
export type ChatRequest = Omit<z.infer<typeof chatRequestSchema>, "key_check">;
export type Turn = z.infer<typeof turnSchema>;

export const judgeRequestSchema = z
  .object({
    problem_id: problemIdSchema,
    conversation: z.array(turnSchema).min(1).max(40),
    ended_by: z.enum(["user", "cap", "solution"]),
    reveal_at_index: z.number().int().min(0).optional(),
  })
  .strict();

export type JudgeRequest = z.infer<typeof judgeRequestSchema>;

export const repairRequestSchema = z
  .object({
    problem_id: problemIdSchema,
    transcript: z.string().min(1).max(8000),
  })
  .strict();

export type RepairRequest = z.infer<typeof repairRequestSchema>;

export const sessionResetRequestSchema = z
  .object({
    problem_id: problemIdSchema,
    // "practice" (the default) retires the session so it can be replayed.
    // "recover" only hands back a judge claim whose verdict never reached
    // the app, so the same session can be judged again.
    reason: z.enum(["practice", "recover"]).optional(),
  })
  .strict();

export type SessionResetRequest = z.infer<typeof sessionResetRequestSchema>;

// oneOf ChatRequest+{mode:"chat"} / JudgeRequest+{mode:"judge"}.
export const trialRequestSchema = z
  .discriminatedUnion("mode", [
    chatRequestObject.omit({ key_check: true }).extend({ mode: z.literal("chat") }),
    judgeRequestSchema.extend({ mode: z.literal("judge") }),
  ])
  .superRefine((value, ctx) => {
    if (value.mode === "chat") {
      requireMessagesUnlessHint(value, ctx);
    }
  });

export type TrialRequest = z.infer<typeof trialRequestSchema>;
