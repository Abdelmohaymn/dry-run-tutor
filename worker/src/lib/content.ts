// Exposes the content compiled into the bundle by tools/build-content.ts.
// getPrivate() is reachable only from server-side ground-truth code — no
// route may return its result directly. The only place private content ever
// crosses the wire is the `editorial` field POST /v1/judge attaches after
// post-processing (FR-022).
import publicManifestJson from "../generated/public-manifest.json";
import { PRIVATE } from "../generated/private-store";
import type { PrivateHalf, PublicHalf } from "../../../tools/problem-types";

export interface PublicManifest {
  schema_version: 2;
  generated: string;
  problems: PublicHalf[];
}

const manifest = publicManifestJson as unknown as PublicManifest;
const privateStore = PRIVATE as unknown as Record<string, PrivateHalf>;

export function getPublicManifest(): PublicManifest {
  return manifest;
}

export function getPrivate(problemId: string): PrivateHalf | null {
  return privateStore[problemId] ?? null;
}

/**
 * The `collections` entry marking the onboarding warm-up, mirroring
 * `practiceCollection` in the app's `problem_repository.dart`. The warm-up
 * is an ordinary manifest problem — it needs a statement and a private
 * half like any other, because the walkthrough is a real conversation —
 * but it is never one of the days, and /v1/trial gates it differently.
 */
export const PRACTICE_COLLECTION = "practice";

export function isPracticeProblem(problemId: string): boolean {
  const entry = manifest.problems.find((p) => p.id === problemId);
  return entry?.collections?.includes(PRACTICE_COLLECTION) ?? false;
}
