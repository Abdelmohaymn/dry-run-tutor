import { z } from "zod";

// Rule 0 (data-model.md §A1, tasks.md T026a). A SHAPE-ONLY transcription of
// contracts/problem.schema.json: which keys exist on which half, and their
// basic type. Deliberately NOT a full-fidelity JSON Schema port — value-level
// constraints (patterns, enum membership, array-length bounds, numeric
// ranges) are the job of rules 1-9 downstream, exactly as in the Python
// reference this file replaces. Rule 0's whole purpose is catching a field
// authored onto the WRONG HALF (every object below is `.strict()`, matching
// `additionalProperties: false`) and required-field presence — that is what
// makes "a structurally valid object" well-defined for rules 1-10 to build
// on (`data-model.md` §A1: "Rules 1–10 assume a structurally valid object").

const approachShape = z
  .object({
    key: z.string(),
    name: z.string(),
    sketch: z.array(z.string()),
    time: z.string(),
    space: z.string(),
    verdict: z.string(),
    requires: z.array(z.string()).optional(),
  })
  .strict();

const insightShape = z
  .object({
    key: z.string(),
    text: z.string(),
    required: z.boolean(),
    hints: z.array(z.string()),
    never_say: z.array(z.string()),
  })
  .strict();

const wrongTurnShape = z
  .object({
    key: z.string(),
    text: z.string(),
    why_it_fails: z.string(),
    counter_question: z.string(),
    failing_case: z.string(),
  })
  .strict();

const followupShape = z
  .object({
    id: z.string(),
    when_approach: z.array(z.string()),
    question: z.string(),
    model_answer: z.string(),
    grading_note: z.string(),
  })
  .strict();

// hint_count is DELIBERATELY absent from this shape: build-injected, never
// authored (data-model.md §A1). An authored file that carries it fails rule
// 0 here, same as any other field on the wrong side of the contract.
const exampleShape = z
  .object({
    input: z.string(),
    output: z.string(),
    explanation: z.string().optional(),
  })
  .strict();

const authoredPublicHalfShape = z
  .object({
    schema_version: z.number(),
    id: z.string(),
    date: z.string().optional(),
    title: z.string(),
    ramp: z.string(),
    difficulty: z.number().optional(),
    tags: z.array(z.string()),
    source: z.string(),
    statement: z.string(),
    constraints: z.array(z.string()),
    examples: z.array(exampleShape).optional(),
    est_speak_seconds: z.number(),
    collections: z.array(z.string()).optional(),
    glossary_terms: z.array(z.string()),
  })
  .strict();

const privateHalfShape = z
  .object({
    reference_approaches: z.array(approachShape),
    key_insights: z.array(insightShape),
    common_wrong_turns: z.array(wrongTurnShape),
    edge_cases: z.array(z.string()),
    followups: z.array(followupShape),
    editorial: z.string(),
  })
  .strict();

export const authoredProblemShape = z
  .object({
    public: authoredPublicHalfShape,
    private: privateHalfShape,
  })
  .strict();
