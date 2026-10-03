// data-model.md §A1. Shared between the content pipeline (tools/) and the
// Worker (worker/src/lib/content.ts) — this is the one type both halves of
// this feature's toolchain agree on.

export interface Approach {
  key: string;
  name: string;
  sketch: string[];
  time: string;
  space: string;
  verdict: "optimal" | "acceptable" | "suboptimal" | "wrong";
}

export interface Insight {
  key: string;
  text: string;
  required: boolean;
  hints: [string, string, string];
  never_say: string[];
}

export interface WrongTurn {
  key: string;
  text: string;
  why_it_fails: string;
  counter_question: string;
  failing_case: string;
}

export interface Followup {
  id: string;
  when_approach: string[];
  question: string;
  model_answer: string;
  grading_note: string;
}

/** A worked example. PUBLIC: it shows what the question means, never how
 * to answer it — the private half still owns every approach. */
export interface Example {
  input: string;
  output: string;
  explanation?: string;
}

export interface PublicHalf {
  schema_version: number;
  id: string;
  date?: string;
  title: string;
  ramp: "easy" | "medium" | "hard";
  difficulty?: number;
  tags: string[];
  source: string;
  statement: string;
  constraints: string[];
  examples?: Example[];
  est_speak_seconds: number;
  collections?: string[];
  glossary_terms: string[];
  /** Build-injected, never authored. 3 * len(private.key_insights). */
  hint_count?: number;
}

export interface PrivateHalf {
  reference_approaches: Approach[];
  key_insights: Insight[];
  common_wrong_turns: WrongTurn[];
  edge_cases: string[];
  followups: Followup[];
  editorial: string;
}

export interface Problem {
  public: PublicHalf;
  private: PrivateHalf;
}
