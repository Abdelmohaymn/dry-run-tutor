import { describe, expect, it } from "vitest";
import { signInstallId, verifyInstallId } from "../../src/lib/install-id";

const SECRET = "test-install-hmac-secret";
const OTHER_SECRET = "a-different-secret";
const SOME_HASH = "3f1c2a4e5b6d4e7f89ab1234567890ab3f1c2a4e5b6d4e7f89ab1234567890ab";

describe("install-id sign/verify", () => {
  it("round trips: a signed id verifies back to the same device hash", async () => {
    const installId = await signInstallId(SOME_HASH, SECRET);
    const verified = await verifyInstallId(installId, SECRET);
    expect(verified).toBe(SOME_HASH);
  });

  it("fails verification against a different secret", async () => {
    const installId = await signInstallId(SOME_HASH, SECRET);
    const verified = await verifyInstallId(installId, OTHER_SECRET);
    expect(verified).toBeNull();
  });

  it("fails verification when the hash is tampered with but the signature is not", async () => {
    const installId = await signInstallId(SOME_HASH, SECRET);
    const [, sig] = installId.split(".");
    const tampered = `${"0".repeat(64)}.${sig}`;
    const verified = await verifyInstallId(tampered, SECRET);
    expect(verified).toBeNull();
  });

  it("rejects a malformed install id with no separator", async () => {
    const verified = await verifyInstallId("not-a-valid-install-id", SECRET);
    expect(verified).toBeNull();
  });

  it("rejects a non-64-hex prefix even with a syntactically valid signature", async () => {
    const installId = await signInstallId("not-a-hash-at-all", SECRET);
    const verified = await verifyInstallId(installId, SECRET);
    expect(verified).toBeNull();
  });

  it("rejects a legacy <uuidv4>.<sig> signed with the right secret", async () => {
    const legacy = await signInstallId("3f1c2a4e-5b6d-4e7f-89ab-1234567890ab", SECRET);
    const verified = await verifyInstallId(legacy, SECRET);
    expect(verified).toBeNull();
  });
});
