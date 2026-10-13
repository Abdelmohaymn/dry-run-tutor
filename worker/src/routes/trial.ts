// POST /v1/trial — contracts/openapi.yaml. One complete session on the
// operator's credential, once per install. Dispatches on `mode` and reuses
// chat-core.ts / judge-core.ts exactly as /v1/chat and /v1/judge do, but
// against a pool-selected credential (data-model.md §B8) instead of the
// learner's own key, and against config.trial.* rather than config.chat.*.
import { Hono } from "hono";
import type { Env, Variables } from "../types";
import { AppError } from "../lib/errors";
import { trialRequestSchema } from "../lib/schemas";
import { getPrivate, getPublicManifest, isPracticeProblem } from "../lib/content";
import { getRuntimeConfig } from "../lib/runtime-config";
import { runConversationalTurn, runHintTurn } from "../lib/chat-core";
import { runPracticeTurn } from "../lib/practice-turn";
import { runJudge } from "../lib/judge-core";
import {
  bumpPracticeTurn,
  getTrialConsumed,
  isSameTrialSession,
  isTasterUnclaimed,
  mayClaimAnotherSession,
  practiceTurnsUsed,
  releasePracticeTurn,
  markTrialCompleted,
  markTrialStarted,
  releaseTrialStart,
  newSessionGateOk,
  hashIp,
  ipSessionGateOk,
  runLeg,
  selectMember,
  settleTrialBudget,
} from "../lib/trial-pool";
import { groqProvider } from "../lib/provider-groq";
import { utcDate, nowIso } from "../lib/time";
import { FINISH_CHECK_MAX_TOKENS } from "../lib/finish-check";
import type { Problem } from "../../../tools/problem-types";

export const trialRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

trialRoute.post("/", async (c) => {
  const installId = c.get("installId");

  const rawBody = await c.req.json().catch(() => null);
  const parsed = trialRequestSchema.safeParse(rawBody);
  if (!parsed.success) throw new AppError("BAD_REQUEST");
  const body = parsed.data;

  const publicEntry = getPublicManifest().problems.find((p) => p.id === body.problem_id);
  const privateHalf = getPrivate(body.problem_id);
  if (!publicEntry || !privateHalf) throw new AppError("BAD_REQUEST");
  const problem: Problem = { public: publicEntry, private: privateHalf };

  const cfg = await getRuntimeConfig(c.env.DB);
  const date = utcDate();
  const now = new Date();
  const db = c.env.DB;
  const ipHash = await hashIp(c.req.header("CF-Connecting-IP") ?? "unknown", c.env.INSTALL_HMAC_SECRET);

  // data-model.md §A5: killed_problem_ids is read by chat.ts, judge.ts and
  // trial.ts alike — a killed problem is refused before the provider on
  // every path, regardless of mode.
  if (cfg.killed_problem_ids.includes(body.problem_id)) {
    throw new AppError("PROBLEM_KILLED");
  }

  const secretFor = (bindingName: string): string => (c.env as unknown as Record<string, string>)[bindingName];

  // A hint pull reaches no provider and must neither start nor consume the
  // trial (FR-032a) — this branch returns before any of the gating below.
  if (body.mode === "chat" && body.hint_requested) {
    return runHintTurn(
      c,
      body,
      { db, installId, problemId: body.problem_id, date, cfg, turnCap: cfg.trial.turn_cap },
      problem,
    );
  }

  // T093: one session per install (FR-032). A call belongs to the session
  // already in flight only if it names the SAME problem on the SAME UTC day
  // and that session has not completed; such a call always runs to its end
  // regardless of budget (FR-032d). Everything else — a completed taster, a
  // different problem, a later day — is a request for a SECOND session.
  //
  // The identity check matters because completed_at is written by one caller
  // only, after a successful mode=judge. An abandoned session never gets it,
  // so "completed_at IS NULL" on its own meant "in flight" forever: a fresh
  // trial.turn_cap per problem_id, renewed daily, with the budget gate below
  // skipped every time. See migrations/0002_trial_session_identity.sql.
  const consumed = await getTrialConsumed(db, installId);

  // The onboarding walkthrough (0003). Its turns come out of the taster —
  // one allowance per install, not two — but it does NOT claim the taster:
  // no problem_id, no date, so today's real problem is still there when
  // the learner arrives at it. The bound is `practice_turn_cap` turns for
  // the life of the install, counted on the taster's own row, because a
  // per-(problem, date) counter is exactly what migration 0002 had to
  // close: it renews daily.
  if (isPracticeProblem(body.problem_id)) {
    if (practiceTurnsUsed(consumed) >= cfg.trial.practice_turn_cap) {
      throw new AppError("TRIAL_CONSUMED");
    }
    if (!(await newSessionGateOk(cfg, db, now))) {
      throw new AppError("TRIAL_UNAVAILABLE");
    }
    if (body.mode !== "chat") {
      // The walkthrough teaches the conversation and stops there — it has
      // no Finish, so it never judges. A judge call against the warm-up is
      // a client that has strayed, not a request to serve.
      throw new AppError("BAD_REQUEST");
    }

    const lastPracticeMessage = body.messages[body.messages.length - 1];
    if (lastPracticeMessage.text.replace(/\s+/g, "").length < cfg.chat.min_turn_chars) {
      throw new AppError("EMPTY_TURN");
    }

    const practiceStartedAt = nowIso();
    return runPracticeTurn({
      c,
      body,
      db,
      installId,
      problemId: body.problem_id,
      date,
      cfg,
      turnCap: cfg.trial.practice_turn_cap,
      now,
      secretFor,
      problem,
      reserve: async () => {
        await bumpPracticeTurn(db, installId, practiceStartedAt);
      },
      release: async () => {
        await releasePracticeTurn(db, installId);
      },
    });
  }

  // T092b: a NEW session is refused only when no eligible member has budget,
  // or the operator's daily session cap is reached. Reinstalls mint fresh
  // install ids, so the per-install rule alone does not bound one network;
  // the second check does (trial.ip_daily_session_cap).
  const gateNewSession = async (): Promise<void> => {
    if (!(await newSessionGateOk(cfg, db, now))) {
      throw new AppError("TRIAL_UNAVAILABLE");
    }
    if (!(await ipSessionGateOk(cfg, db, ipHash, date))) {
      throw new AppError("TRIAL_IP_LIMIT");
    }
  };

  if (consumed && !isTasterUnclaimed(consumed)) {
    // A judge call for the session this install already finished today is
    // a retry of a verdict that was delivered (or lost on the way), not a
    // second taster. TRIAL_CONSUMED here put the key wall in front of the
    // learner's own assessment; SESSION_ALREADY_JUDGED lets the app show
    // the copy it saved (2026-10-04).
    if (
      body.mode === "judge" &&
      consumed.completedAt !== null &&
      consumed.problemId === body.problem_id &&
      consumed.date === date
    ) {
      throw new AppError("SESSION_ALREADY_JUDGED");
    }
    if (!isSameTrialSession(consumed, body.problem_id, date)) {
      // A request for ANOTHER session. Refused for the same problem on the
      // same day (a finished session is not replayable), and once the device
      // has claimed trial.sessions_per_device sessions (default 1: the slot is
      // already occupied, so this is the old one-taster rule).
      const replay = consumed.problemId === body.problem_id && consumed.date === date;
      if (replay || !mayClaimAnotherSession(consumed, cfg)) {
        throw new AppError("TRIAL_CONSUMED");
      }
      await gateNewSession();
    }
    // else in flight — fall through, no budget gate.
  } else {
    await gateNewSession();
  }

  if (body.mode === "chat") {
    const lastMessage = body.messages[body.messages.length - 1];
    const nonWhitespaceChars = lastMessage.text.replace(/\s+/g, "").length;
    if (nonWhitespaceChars < cfg.chat.min_turn_chars) {
      throw new AppError("EMPTY_TURN");
    }

    // One timestamp for both hooks: markTrialStarted() leaves an existing
    // row's started_at alone, so releaseTrialStart() matching on this value
    // can only undo a row THIS call created (Constitution VIII).
    const trialStartedAt = nowIso();

    return runConversationalTurn(
      c,
      body,
      {
        db,
        installId,
        problemId: body.problem_id,
        date,
        cfg,
        provider: groqProvider,
        turnCap: cfg.trial.turn_cap,
        groundTruthTier: cfg.trial.ground_truth_tier,
        condenseEnabled: cfg.trial.condense,
        streamChat: async (systemPrompt, messages) => {
          const { member, result } = await runLeg(
            "chat",
            cfg,
            db,
            now,
            (opts) => groqProvider.streamChat({ ...opts, systemPrompt, messages }),
            secretFor,
          );
          const wrappedUsage = async () => {
            const usage = await result.usage();
            await settleTrialBudget(db, now, member.id, "chat", usage.inputTokens + usage.outputTokens);
            return usage;
          };
          return { stream: { deltas: result.deltas, usage: wrappedUsage }, providerId: member.id, model: member.model };
        },
        // Condensation is disabled by default for the trial profile
        // (cfg.trial.condense). If ever enabled, it is resolved against a
        // single non-retried pool pick rather than full runLeg() — the
        // low-stakes, secondary call the pool retry logic was not written
        // for (data-model.md §B8 only names the main leg).
        condenseCallOptions: async () => {
          const m = await selectMember("chat", cfg, db, now);
          if (!m) throw new AppError("TRIAL_UNAVAILABLE");
          return { baseUrl: m.base_url, apiKey: secretFor(m.secret_binding), model: m.model };
        },
        finishCheck: async (systemPrompt, userContent, jsonSchema) => {
          const { member, result } = await runLeg(
            "judge",
            cfg,
            db,
            now,
            (opts) =>
              groqProvider.structuredCompletion({
                ...opts,
                systemPrompt,
                userContent,
                maxTokens: FINISH_CHECK_MAX_TOKENS,
                temperature: 0,
                jsonSchema,
              }),
            secretFor,
          );
          await settleTrialBudget(db, now, member.id, "judge", result.usage.inputTokens + result.usage.outputTokens);
          return { result, providerId: member.id, model: member.model };
        },
        onBeforeProviderCall: async () => {
          if (!(await markTrialStarted(db, installId, trialStartedAt, body.problem_id, date, ipHash, cfg.trial.sessions_per_device))) {
            throw new AppError("TRIAL_CONSUMED");
          }
        },
        onProviderCallUnanswered: async () => {
          await releaseTrialStart(db, installId, trialStartedAt);
        },
      },
      problem,
    );
  }

  // mode === "judge"
  const trialStartedAt = nowIso();
  if (!(await markTrialStarted(db, installId, trialStartedAt, body.problem_id, date, ipHash, cfg.trial.sessions_per_device))) {
    throw new AppError("TRIAL_CONSUMED");
  }
  let assessment;
  try {
    assessment = await runJudge(
    {
      db,
      installId,
      problemId: body.problem_id,
      date,
      finishCheckTimeoutMs: cfg.finish_offer.timeout_ms,
      structuredCompletion: async (systemPrompt, userContent, jsonSchema) => {
        const { member, result } = await runLeg(
          "judge",
          cfg,
          db,
          now,
          (opts) =>
            groqProvider.structuredCompletion({
              ...opts,
              systemPrompt,
              userContent,
              maxTokens: 2000,
              temperature: 0,
              jsonSchema,
            }),
          secretFor,
        );
        await settleTrialBudget(db, now, member.id, "judge", result.usage.inputTokens + result.usage.outputTokens);
        return { result, providerId: member.id, model: member.model };
      },
    },
    body,
    problem,
    );
  } catch (err) {
    // No assessment came back, so nothing was spent. runJudge() has already
    // handed the judge claim back; hand back the trial row too, but only if
    // this call is what created it (Constitution VIII).
    await releaseTrialStart(db, installId, trialStartedAt);
    throw err;
  }
  await markTrialCompleted(db, installId, nowIso());

  return c.json(assessment, 200);
});
