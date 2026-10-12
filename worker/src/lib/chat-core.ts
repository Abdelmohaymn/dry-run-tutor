// The shared body of one tutor turn, extracted from routes/chat.ts so
// routes/trial.ts (T092) can reuse it verbatim against a pool-selected
// credential instead of the learner's own key. Everything here is
// provider-agnostic: the caller resolves WHICH credential/base_url/model
// serves this turn (fixed, for the keyed path; pool-selected with 429
// routing, for the trial path) and hands back a StreamChatResult.
import { streamSSE } from "hono/streaming";
import type { Context } from "hono";
import { AppError } from "./errors";
import type { ChatRequest, Turn } from "./schemas";
import type { RuntimeConfig } from "./runtime-config";
import {
  assertNotJudged,
  readCounters,
  recordNamedTerms,
  recordReachedKeys,
  refundTurn,
  releaseSolution,
  reserveTurn,
  revealNextHint,
  type TurnCounterKey,
} from "./turn-cap";
import { learnerNamedTerms, renderGroundTruth, selectSlice } from "./ground-truth";
import { isReady, runFinishCheck, withinMs, type FinishCheckCall } from "./finish-check";
import { condense, type CondenseCallOptions } from "./condense";
import { blockedTermsIn, buildBlockedTerms, cleanLead } from "./leak-filter";
import { LADDER_EXHAUSTED, flatLadder, nextHint } from "./hint-ladder";
import { LADDER_EXHAUSTED_LINE, LEAK_BLOCKED_FALLBACK, TUTOR_PROMPT, WRAP_UP_SENTENCE, rewriteNote } from "../prompts/tutor";
import { writeDone, writeError, writeMeta, writeToken, type MetaFramePayload } from "./sse";
import type { Provider, ProviderMessage, StreamChatResult } from "./provider";
import { withReplyLanguageNote, withSolutionReleaseNote } from "./reply-language";
import type { Problem } from "../../../tools/problem-types";

export interface ChatTurnDeps {
  db: D1Database;
  installId: string;
  problemId: string;
  date: string;
  cfg: RuntimeConfig;
  provider: Provider;
  turnCap: number;
  groundTruthTier: "A" | "AB";
  condenseEnabled: boolean;
  /** Resolves the credential for THIS request's main streaming call. */
  streamChat: (systemPrompt: string, messages: ProviderMessage[]) => Promise<{
    stream: StreamChatResult;
    providerId: string;
    model: string;
  }>;
  /** Resolves the credential for the condensation sub-call, if triggered. */
  condenseCallOptions: () => CondenseCallOptions | Promise<CondenseCallOptions>;
  /** Called once, only immediately before the main provider call — never on the hint path (T093). No-op for the keyed path. */
  onBeforeProviderCall?: () => Promise<void>;
  /**
   * Called when the turn is refunded because the provider never answered —
   * the same condition as refundTurn(), so whatever onBeforeProviderCall()
   * claimed can be handed back too (Constitution VIII). No-op for the keyed
   * path, which claims nothing beyond the turn itself.
   */
  onProviderCallUnanswered?: () => Promise<void>;
  /**
   * Feature 005. Makes the finish-check call on this path's credential.
   * Absent = no check, and `ready_to_finish` is left off the meta frame.
   */
  finishCheck?: FinishCheckCall;
}

/**
 * Validates a learner's key on save without spending a turn. A tiny
 * prompt, not the tutor's: a non-2xx from the provider is thrown before
 * the stream opens (INVALID_KEY, QUOTA_EXHAUSTED...) and goes out as an
 * `error` frame, like any other turn's. Once the provider answers 200 the key works, so
 * the stream is cancelled after its first delta. Nothing is reserved;
 * `meta` reports the counters exactly as they already were.
 */
export async function runKeyCheck(
  c: Context,
  deps: Pick<ChatTurnDeps, "db" | "installId" | "problemId" | "date" | "cfg" | "turnCap">,
  problem: Problem,
  openStream: (systemPrompt: string, messages: ProviderMessage[]) => Promise<{ stream: StreamChatResult; providerId: string; model: string }>,
): Promise<Response> {
  const key: TurnCounterKey = { installId: deps.installId, problemId: deps.problemId, date: deps.date };
  return streamSSE(c, async (stream) => {
    let opened: { stream: StreamChatResult; providerId: string; model: string };
    try {
      opened = await openStream("Reply with the single word OK.", [{ role: "user", text: "OK" }]);
    } catch (err) {
      await writeError(stream, err instanceof AppError ? err : new AppError("UNCLEAR_RETRY"));
      return;
    }
    try {
      for await (const _delta of opened.stream.deltas) break; // leaving the loop cancels upstream
    } catch {
      // The provider already answered 200 — a stream that fails after that
      // says nothing about the key.
    }

    const counters = await readCounters(deps.db, key);

    const meta: MetaFramePayload = {
      turn_index: counters.turns,
      turns_remaining: Math.max(0, deps.turnCap - counters.turns),
      hints_revealed: counters.hintsRevealed,
      hints_remaining: Math.max(0, flatLadder(problem).length - counters.hintsRevealed),
      session_ended: null,
      leak_blocked: false,
    };
    await writeMeta(stream, meta);
    await writeDone(stream);
  });
}

/** Runs the hint branch: no provider call, no turn spent (FR-003a, FR-003b). */
export async function runHintTurn(
  c: Context,
  body: ChatRequest,
  deps: Pick<ChatTurnDeps, "db" | "installId" | "problemId" | "date" | "cfg" | "turnCap">,
  problem: Problem,
): Promise<Response> {
  const key: TurnCounterKey = { installId: deps.installId, problemId: deps.problemId, date: deps.date };
  return streamSSE(c, async (stream) => {
    const counters = await readCounters(deps.db, key);
    try {
      assertNotJudged(counters.judgedAt);
    } catch (err) {
      await writeError(stream, err instanceof AppError ? err : new AppError("UNCLEAR_RETRY"));
      return;
    }

    const hintsRevealed = await revealNextHint(deps.db, key);
    const ladderLength = flatLadder(problem).length;
    const hintsRemaining = Math.max(0, ladderLength - hintsRevealed);
    const rung = nextHint(problem, hintsRevealed);
    const rungText = rung === LADDER_EXHAUSTED ? LADDER_EXHAUSTED_LINE : rung.text;

    await writeToken(stream, rungText);
    const meta: MetaFramePayload = {
      turn_index: counters.turns,
      turns_remaining: Math.max(0, deps.turnCap - counters.turns),
      hints_revealed: hintsRevealed,
      hints_remaining: hintsRemaining,
      session_ended: null,
      leak_blocked: false,
    };
    await writeMeta(stream, meta);
    await writeDone(stream);
  });
}

/** Runs one conversational turn: reserve, condense, stream, filter, meta. */
export async function runConversationalTurn(
  c: Context,
  body: ChatRequest,
  deps: ChatTurnDeps,
  problem: Problem,
): Promise<Response> {
  const key: TurnCounterKey = { installId: deps.installId, problemId: deps.problemId, date: deps.date };

  const reserved = await reserveTurn(deps.db, key, deps.turnCap, body.solution_request_count);
  assertNotJudged(reserved.judgedAt);

  const released = releaseSolution(reserved.turnIndex, reserved.solutionRequests);
  const turnsRemaining = Math.max(0, deps.turnCap - reserved.turnIndex);
  const sessionEnded: "cap" | "solution" | null = released
    ? "solution"
    : reserved.turnIndex >= deps.turnCap
      ? "cap"
      : null;

  return streamSSE(c, async (stream) => {
    let tokenEmitted = false;
    try {
      const condensed = deps.condenseEnabled
        ? await condense(
            body.summary,
            body.messages,
            deps.cfg,
            deps.provider,
            await deps.condenseCallOptions(),
          )
        : { summary: body.summary, verbatim: body.messages, called: false, covered: 0 };

      // What the learner has said this session, for the word filter and the
      // ground-truth slice: the turns already inside the summary (the app
      // sends their text) and then the ones replayed verbatim. Only the
      // verbatim ones reach the provider. Without the earlier ones, a word
      // said before the last summary was blocked again (2026-09-25).
      const learnerHistory: Turn[] = [
        ...(body.earlier_learner_turns ?? []).map((text) => ({ role: "user" as const, text })),
        ...body.messages,
      ];
      const slice = selectSlice(problem, learnerHistory, reserved.turnIndex, deps.cfg, deps.groundTruthTier);
      const groundTruthText = renderGroundTruth(slice);
      const wrapUp = reserved.turnIndex >= deps.cfg.chat.wrap_up_at_turn ? WRAP_UP_SENTENCE : "";
      const systemPrompt = TUTOR_PROMPT.replace(
        "{{SOLUTION_REQUEST_COUNT}}",
        String(reserved.solutionRequests),
      )
        .replace("{{TURNS_REMAINING}}", String(turnsRemaining))
        .replace("{{WRAP_UP}}", wrapUp)
        .replace("{{GROUND_TRUTH}}", groundTruthText);

      const withNotes = withReplyLanguageNote(
        condensed.summary
          ? [
              {
                role: "user" as const,
                text: `[Context from earlier in this conversation: ${condensed.summary}]`,
              },
              ...condensed.verbatim,
            ]
          : condensed.verbatim,
      );
      const providerMessages: ProviderMessage[] = released ? withSolutionReleaseNote(withNotes) : withNotes;

      if (deps.onBeforeProviderCall) {
        await deps.onBeforeProviderCall();
      }

      // Started before the tutor call so the two run side by side; awaited
      // only after the reply has gone out (feature 005). It also runs after
      // "Keep going": its reached keys feed the leak filter (below), and
      // only the offer itself is withheld.
      const finishOffer = deps.cfg.finish_offer;
      const finishCheck =
        deps.finishCheck &&
        finishOffer.enabled &&
        sessionEnded === null &&
        reserved.turnIndex >= finishOffer.min_turn
          ? withinMs(
              runFinishCheck(problem, learnerHistory, deps.finishCheck),
              finishOffer.timeout_ms,
            )
          : null;

      // The insights the progress check found stated on EARLIER turns (this
      // turn's check is still running). It replaced the word-overlap guess,
      // which caught 62% of paraphrases and none in Arabic, and marked a
      // different insight 42% of the time, unblocking words the learner
      // never said (review F4, 2026-10-07). A word the learner used
      // themselves is still unblocked at once (learnerNamedTerms). The terms
      // the check found the learner referred to in other forms on earlier
      // turns (an abbreviation, a mangling, another language) join them
      // (2026-10-11, docs/tutor-focus-issues.md Issue 1).
      const reachedKeys = new Set(reserved.reachedKeys);
      const named = new Set([...learnerNamedTerms(problem, learnerHistory), ...reserved.namedTerms]);
      const blockedTerms = buildBlockedTerms(problem, reachedKeys, named, released ? "solution" : null);

      // The whole draft is read before any of it is sent, so a blocked
      // word can be written around instead of cut off (data-model.md §B1).
      const first = await deps.streamChat(systemPrompt, providerMessages);
      const firstText = await collectText(first.stream.deltas);
      // Awaited for its side effect: on the trial path usage() is the wrapper
      // that settles the trial budget with the real token count.
      await first.stream.usage();
      let reply = firstText;

      const hits = blockedTermsIn(firstText, blockedTerms);
      const leakBlocked = hits.length > 0;
      let fallbackSent = false;
      if (leakBlocked) {
        // One rewrite, told which words to avoid. If that is blocked too,
        // or fails, the first draft's clean sentences stand, or the
        // fallback when there are none.
        let rewrite: string | null = null;
        try {
          const second = await deps.streamChat(systemPrompt + rewriteNote(hits), providerMessages);
          const secondText = await collectText(second.stream.deltas);
          await second.stream.usage();
          if (secondText.trim() !== "" && blockedTermsIn(secondText, blockedTerms).length === 0) {
            rewrite = secondText;
          }
        } catch {
          // The first draft was answered; a failed rewrite is not a failed turn.
        }
        const lead = cleanLead(firstText, blockedTerms);
        reply = rewrite ?? (lead.trim() !== "" ? lead : LEAK_BLOCKED_FALLBACK);
        fallbackSent = rewrite === null && lead.trim() === "";
      }

      // A reasoning model that spent its whole max_tokens thinking answers
      // nothing. That is a turn the provider never answered, so it is
      // refunded below rather than spent on silence.
      if (reply.trim() === "") {
        throw new AppError("UNCLEAR_RETRY");
      }
      tokenEmitted = true;
      await writeToken(stream, reply);

      const checked = finishCheck ? await finishCheck : null;
      const reachedNow = [...new Set([...reserved.reachedKeys, ...(checked?.reached ?? [])])];
      if (checked) {
        await recordReachedKeys(deps.db, key, reserved.reachedKeys, checked.reached);
        await recordNamedTerms(deps.db, key, reserved.namedTerms, checked.named);
      }

      const meta: MetaFramePayload = {
        turn_index: reserved.turnIndex,
        turns_remaining: turnsRemaining,
        hints_revealed: reserved.hintsRevealed,
        hints_remaining: Math.max(0, flatLadder(problem).length - reserved.hintsRevealed),
        summary: condensed.called ? (condensed.summary ?? null) : undefined,
        summary_covers: condensed.called ? condensed.covered : undefined,
        session_ended: sessionEnded,
        leak_blocked: fallbackSent,
        ready_to_finish: finishCheck && !body.finish_offer_dismissed ? isReady(problem, reachedNow) : undefined,
      };
      await writeMeta(stream, meta);
      await writeDone(stream);
    } catch (err) {
      const appError = err instanceof AppError ? err : new AppError("UNCLEAR_RETRY");
      // FR-037, Constitution VIII: a turn the provider never answered is
      // not spent. Once a single token has reached the caller, the turn
      // was served — do not refund a stream that failed midway.
      if (!tokenEmitted) {
        await refundTurn(deps.db, key, reserved.turnIndex);
        if (deps.onProviderCallUnanswered) {
          await deps.onProviderCallUnanswered();
        }
      }
      await writeError(stream, appError);
    }
  });
}

async function collectText(deltas: AsyncIterable<string>): Promise<string> {
  let text = "";
  for await (const delta of deltas) text += delta;
  return text;
}
