import { env } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { getRuntimeConfig, type RuntimeConfig } from "../../src/lib/runtime-config";
import {
  runLeg,
  TRIAL_ESTIMATE_CHAT,
  TRIAL_ESTIMATE_JUDGE,
  type TrialPoolMember,
} from "../../src/lib/trial-pool";
import { AppError } from "../../src/lib/errors";

let counter = 0;
function freshId(prefix: string): string {
  counter += 1;
  return `${prefix}-${counter}-${Date.now()}`;
}

function member(overrides: Partial<TrialPoolMember>): TrialPoolMember {
  return {
    id: freshId("member"),
    secret_binding: "TRIAL_KEY_GROQ",
    base_url: "https://api.groq.com/openai/v1",
    model: "openai/gpt-oss-120b",
    daily_token_budget: 100000,
    structured_output: false,
    enabled: true,
    cooldown_ms: 60000,
    ...overrides,
  };
}

async function cfgWithPool(pool: TrialPoolMember[]): Promise<RuntimeConfig> {
  const base = await getRuntimeConfig(env.DB);
  return { ...base, trial: { ...base.trial, pool } };
}

async function tokensSpent(providerId: string, date: string): Promise<number> {
  const row = await env.DB.prepare(
    "SELECT tokens_spent FROM provider_day WHERE date = ?1 AND provider_id = ?2",
  )
    .bind(date, providerId)
    .first<{ tokens_spent: number }>();
  return row?.tokens_spent ?? 0;
}

// data-model.md §B8, T091b.
describe("runLeg() — budget accounting and 429 routing", () => {
  it("reserves the estimate before the call — visible mid-call, before any correction", async () => {
    const m = member({});
    const cfg = await cfgWithPool([m]);
    const date = new Date().toISOString().slice(0, 10);

    let spentDuringCall = 0;
    await runLeg(
      "chat",
      cfg,
      env.DB,
      new Date(),
      async () => {
        spentDuringCall = await tokensSpent(m.id, date);
        return "ok";
      },
      () => "fake-key",
    );

    expect(spentDuringCall).toBe(TRIAL_ESTIMATE_CHAT);
  });

  it("a two-member pool whose first member returns 429 completes the leg on the second, no error reaching the caller (SC-010c)", async () => {
    const first = member({});
    const second = member({});
    const cfg = await cfgWithPool([first, second]);

    let calls = 0;
    const { member: served, result } = await runLeg(
      "chat",
      cfg,
      env.DB,
      new Date(),
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new AppError("RATE_LIMITED");
        }
        return "served";
      },
      () => "fake-key",
    );

    expect(result).toBe("served");
    expect(served.id).toBe(second.id);
  });

  it("cooldown is set on a 429'd member so a subsequent selection skips it", async () => {
    const m = member({});
    const cfg = await cfgWithPool([m]);
    const date = new Date().toISOString().slice(0, 10);

    await expect(
      runLeg(
        "chat",
        cfg,
        env.DB,
        new Date(),
        async () => {
          throw new AppError("RATE_LIMITED");
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "TRIAL_UNAVAILABLE" });

    const row = await env.DB.prepare(
      "SELECT cooldown_until FROM provider_day WHERE date = ?1 AND provider_id = ?2",
    )
      .bind(date, m.id)
      .first<{ cooldown_until: string | null }>();
    expect(row?.cooldown_until).not.toBeNull();
  });

  // Found on a physical device: the assessment failed roughly two calls in
  // three, always after the provider's own 30-second timeout, while the
  // other pool member was healthy and answering in about a second. A member
  // that never answers is exactly what a second member is for.
  it("a member that never answered routes the leg to the next member", async () => {
    const first = member({});
    const second = member({});
    const cfg = await cfgWithPool([first, second]);

    let calls = 0;
    const { member: served, result } = await runLeg(
      "chat",
      cfg,
      env.DB,
      new Date(),
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new AppError("UNCLEAR_RETRY", { memberUnavailable: true });
        }
        return "served";
      },
      () => "fake-key",
    );

    expect(result).toBe("served");
    expect(served.id).toBe(second.id);
    expect(calls).toBe(2);
  });

  it("cooldown is set on a member that never answered, so the next call skips it", async () => {
    const m = member({});
    const cfg = await cfgWithPool([m]);
    const date = new Date().toISOString().slice(0, 10);

    await expect(
      runLeg(
        "chat",
        cfg,
        env.DB,
        new Date(),
        async () => {
          throw new AppError("UNCLEAR_RETRY", { memberUnavailable: true });
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "TRIAL_UNAVAILABLE" });

    const row = await env.DB.prepare(
      "SELECT cooldown_until FROM provider_day WHERE date = ?1 AND provider_id = ?2",
    )
      .bind(date, m.id)
      .first<{ cooldown_until: string | null }>();
    expect(row?.cooldown_until).not.toBeNull();
  });

  // The distinction that keeps `trial.session-identity`'s 500 case intact:
  // an upstream that ANSWERED with an error is describing the request, and
  // the next member would fail identically.
  it("an upstream error status still surfaces immediately, without trying another member", async () => {
    const first = member({});
    const second = member({});
    const cfg = await cfgWithPool([first, second]);
    let calls = 0;

    await expect(
      runLeg(
        "chat",
        cfg,
        env.DB,
        new Date(),
        async () => {
          calls += 1;
          throw new AppError("UNCLEAR_RETRY");
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "UNCLEAR_RETRY" });

    expect(calls).toBe(1);
  });

  it("a non-rate-limit error surfaces immediately without trying another member", async () => {
    const first = member({});
    const second = member({});
    const cfg = await cfgWithPool([first, second]);
    let calls = 0;

    await expect(
      runLeg(
        "chat",
        cfg,
        env.DB,
        new Date(),
        async () => {
          calls += 1;
          throw new AppError("INVALID_KEY");
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "INVALID_KEY" });

    expect(calls).toBe(1);
  });
  // docs/errors/2026-09-25-trial-judge-unclear-retry.md, bug 2: failed calls
  // kept their full estimate, so ~39 failed judge calls used up a member's
  // whole day and locked every new learner out of the trial.
  it("a call that fails outright gives its reserved estimate back", async () => {
    const m = member({ structured_output: true });
    const cfg = await cfgWithPool([m]);
    const date = new Date().toISOString().slice(0, 10);

    await expect(
      runLeg(
        "judge",
        cfg,
        env.DB,
        new Date(),
        async () => {
          throw new AppError("UNCLEAR_RETRY");
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "UNCLEAR_RETRY" });

    expect(await tokensSpent(m.id, date)).toBe(0);
  });

  it("a member that is routed around gives its estimate back; only the serving member keeps one", async () => {
    const first = member({ structured_output: true });
    const second = member({ structured_output: true });
    const cfg = await cfgWithPool([first, second]);
    const date = new Date().toISOString().slice(0, 10);

    let calls = 0;
    await runLeg(
      "judge",
      cfg,
      env.DB,
      new Date(),
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new AppError("RATE_LIMITED");
        }
        return "served";
      },
      () => "fake-key",
    );

    expect(await tokensSpent(first.id, date)).toBe(0);
    expect(await tokensSpent(second.id, date)).toBe(TRIAL_ESTIMATE_JUDGE);
  });
  it("an upstream 5xx or unusable answer is retried on the next member, and the failing member is not cooled down", async () => {
    const first = member({ structured_output: true });
    const second = member({ structured_output: true });
    const cfg = await cfgWithPool([first, second]);
    const date = new Date().toISOString().slice(0, 10);

    let calls = 0;
    const { member: served } = await runLeg(
      "judge",
      cfg,
      env.DB,
      new Date(),
      async () => {
        calls += 1;
        if (calls === 1) {
          throw new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
        }
        return "served";
      },
      () => "fake-key",
    );

    expect(served.id).toBe(second.id);
    const row = await env.DB.prepare(
      "SELECT cooldown_until FROM provider_day WHERE date = ?1 AND provider_id = ?2",
    )
      .bind(date, first.id)
      .first<{ cooldown_until: string | null }>();
    expect(row?.cooldown_until ?? null).toBeNull();
  });

  it("with no member left to try, the original error surfaces, not TRIAL_UNAVAILABLE", async () => {
    const only = member({ structured_output: true });
    const cfg = await cfgWithPool([only]);

    await expect(
      runLeg(
        "judge",
        cfg,
        env.DB,
        new Date(),
        async () => {
          throw new AppError("UNCLEAR_RETRY", { tryElsewhere: true });
        },
        () => "fake-key",
      ),
    ).rejects.toMatchObject({ code: "UNCLEAR_RETRY" });
  });
});
