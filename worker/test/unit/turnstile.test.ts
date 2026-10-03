import { afterEach, describe, expect, it, vi } from "vitest";
import { verifyTurnstile } from "../../src/lib/turnstile";

function mockFetch(response: unknown, ok = true) {
  return vi.spyOn(globalThis, "fetch").mockResolvedValue(
    new Response(JSON.stringify(response), { status: ok ? 200 : 500 }),
  );
}

afterEach(() => {
  vi.restoreAllMocks();
});

describe("verifyTurnstile()", () => {
  it("is true on success with a matching action", async () => {
    mockFetch({ success: true, action: "notify" });
    await expect(verifyTurnstile("secret", "token", "notify")).resolves.toBe(true);
  });

  it("is false on success with the wrong action", async () => {
    mockFetch({ success: true, action: "something_else" });
    await expect(verifyTurnstile("secret", "token", "notify")).resolves.toBe(false);
  });

  it("is false when success is false", async () => {
    mockFetch({ success: false });
    await expect(verifyTurnstile("secret", "token", "notify")).resolves.toBe(false);
  });

  it("is false when fetch throws", async () => {
    vi.spyOn(globalThis, "fetch").mockRejectedValue(new Error("network down"));
    await expect(verifyTurnstile("secret", "token", "notify")).resolves.toBe(false);
  });
});
