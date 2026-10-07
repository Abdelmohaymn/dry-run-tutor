import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

async function putVoice(voice: unknown): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  if (voice === undefined) {
    delete cfg.voice;
  } else {
    cfg.voice = voice;
  }
  await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

const GOOD = { enabled: true, seconds_per_device: 300, max_clip_seconds: 120 };

// Feature 008. Same posture as the ads lever: a malformed voice block is
// refused rather than served, so a bad config write cannot quietly change
// what the app believes about its voice allowance.
describe("GET /v1/config — the voice block", () => {
  it("refuses an unknown key inside the block", async () => {
    await putVoice({ ...GOOD, provider: "elsewhere" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
    await putVoice(undefined);
  });

  it("refuses a non-boolean enabled", async () => {
    await putVoice({ ...GOOD, enabled: "true" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
    await putVoice(undefined);
  });

  it("refuses an out-of-range clip length", async () => {
    await putVoice({ ...GOOD, max_clip_seconds: 4 });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
    await putVoice(undefined);
  });

  it("serves the block again once it is valid", async () => {
    await putVoice(GOOD);
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(200);
    await putVoice(undefined);
  });
});
