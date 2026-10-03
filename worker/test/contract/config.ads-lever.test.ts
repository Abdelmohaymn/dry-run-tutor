import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

async function putAds(ads: unknown): Promise<void> {
  const row = await env.DB.prepare("SELECT payload FROM runtime_config WHERE id = 1").first<{
    payload: string;
  }>();
  const cfg = JSON.parse(row!.payload);
  if (ads === undefined) {
    delete cfg.ads;
  } else {
    cfg.ads = ads;
  }
  await env.DB.prepare("UPDATE runtime_config SET payload = ? WHERE id = 1")
    .bind(JSON.stringify(cfg))
    .run();
}

async function served(): Promise<any> {
  return (await (await SELF.fetch("https://worker.test/v1/config")).json()) as any;
}

// FR-021a. The relay carries the switch; the app decides what to do with
// it. What matters here is that the two states are distinguishable and
// that a malformed one is refused rather than served — a config that
// silently failed to parse would take ads off every install by accident.
describe("GET /v1/config — the ad kill switch", () => {
  it("is absent by default, leaving the build flag as the only opinion", async () => {
    await putAds(undefined);
    expect((await served()).ads).toBeUndefined();
  });

  it("carries false, which is the whole point of the lever", async () => {
    await putAds({ enabled: false });
    expect((await served()).ads).toEqual({ enabled: false });
  });

  it("carries true, and false is not confused with absent", async () => {
    await putAds({ enabled: true });
    const withTrue = (await served()).ads;

    await putAds({ enabled: false });
    const withFalse = (await served()).ads;

    await putAds(undefined);
    const withNothing = (await served()).ads;

    expect(withTrue).toEqual({ enabled: true });
    expect(withFalse).toEqual({ enabled: false });
    expect(withNothing).toBeUndefined();
  });

  it("switching ads off is one write", async () => {
    await putAds({ enabled: true });
    await env.DB.prepare(
      "UPDATE runtime_config SET payload = json_set(payload, '$.ads.enabled', json('false'))",
    ).run();

    expect((await served()).ads).toEqual({ enabled: false });
  });

  it("refuses a non-boolean rather than serving it", async () => {
    await putAds({ enabled: "false" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
  });

  it("refuses an unknown key inside the block", async () => {
    await putAds({ enabled: false, placement: "everywhere" });
    expect((await SELF.fetch("https://worker.test/v1/config")).status).toBe(502);
    await putAds(undefined);
  });
});
