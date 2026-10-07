import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { runtimeConfigSchema } from "../../src/lib/runtime-config";

// US6 scenario 1, SC-012.
describe("GET /v1/config", () => {
  it("the seeded payload validates against contracts/config.schema.json (via the zod transcription)", async () => {
    const res = await SELF.fetch("https://worker.test/v1/config");
    expect(res.status).toBe(200);
    expect(res.headers.get("cache-control")).toContain("max-age=300");
    expect(res.headers.get("etag")).toBeTruthy();
    const body = await res.json();
    expect(() => runtimeConfigSchema.parse(body)).not.toThrow();
  });

  it("never sends the web lever block (feature 007 — the app has no use for it)", async () => {
    const res = await SELF.fetch("https://worker.test/v1/config");
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.web).toBeUndefined();
  });

  it("never sends rotation either, and keeps the legacy content_manifest_url for pre-006 apps", async () => {
    const res = await SELF.fetch("https://worker.test/v1/config");
    const body = (await res.json()) as Record<string, unknown>;
    expect(body.rotation).toBeUndefined();
    expect(body.web).toBeUndefined();
    expect(typeof body.content_manifest_url).toBe("string");
  });

  // Feature 008. `voice` is optional; its `model` is the Worker's own choice.
  async function putVoice(voice: unknown): Promise<void> {
    const row = await env.DB.prepare("SELECT payload FROM config WHERE id = 1").first<{
      payload: string;
    }>();
    const cfg = JSON.parse(row!.payload);
    if (voice === undefined) delete cfg.voice;
    else cfg.voice = voice;
    await env.DB.prepare("UPDATE config SET payload = ? WHERE id = 1")
      .bind(JSON.stringify(cfg))
      .run();
  }

  async function served(): Promise<Record<string, any>> {
    return (await (await SELF.fetch("https://worker.test/v1/config")).json()) as Record<string, any>;
  }

  it("serves voice when it is set", async () => {
    await putVoice({ enabled: true, seconds_per_device: 300, max_clip_seconds: 120 });
    expect((await served()).voice).toEqual({
      enabled: true,
      seconds_per_device: 300,
      max_clip_seconds: 120,
    });
  });

  it("never serves voice.model, whether it is stored explicitly or defaulted", async () => {
    await putVoice({
      enabled: true,
      seconds_per_device: 300,
      max_clip_seconds: 120,
      model: "whisper-large-v3",
    });
    const explicit = await served();
    expect(explicit.voice).toEqual({
      enabled: true,
      seconds_per_device: 300,
      max_clip_seconds: 120,
    });
    expect(explicit.voice).not.toHaveProperty("model");

    await putVoice({ enabled: false, seconds_per_device: 0, max_clip_seconds: 5 });
    const defaulted = await served();
    expect(defaulted.voice).toEqual({ enabled: false, seconds_per_device: 0, max_clip_seconds: 5 });
    expect(defaulted.voice).not.toHaveProperty("model");
  });

  it("leaves voice absent when the config has none (voice off by default)", async () => {
    await putVoice(undefined);
    const body = await served();
    expect(body).not.toHaveProperty("voice");
    expect(() => runtimeConfigSchema.parse(body)).not.toThrow();
  });
});
