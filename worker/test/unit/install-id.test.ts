import { describe, expect, it } from "vitest";
import { signInstallId, verifyInstallId } from "../../src/lib/install-id";

const SECRET = "test-install-hmac-secret";
const OTHER_SECRET = "a-different-secret";
const SOME_UUID = "3f1c2a4e-5b6d-4e7f-89ab-1234567890ab";

describe("install-id sign/verify", () => {
  it("round trips: a signed id verifies back to the same uuid", async () => {
    const installId = await signInstallId(SOME_UUID, SECRET);
    const verified = await verifyInstallId(installId, SECRET);
    expect(verified).toBe(SOME_UUID);
  });

  it("fails verification against a different secret", async () => {
    const installId = await signInstallId(SOME_UUID, SECRET);
    const verified = await verifyInstallId(installId, OTHER_SECRET);
    expect(verified).toBeNull();
  });

  it("fails verification when the uuid is tampered with but the signature is not", async () => {
    const installId = await signInstallId(SOME_UUID, SECRET);
    const [, sig] = installId.split(".");
    const tamperedUuid = "00000000-0000-4000-8000-000000000000";
    const tampered = `${tamperedUuid}.${sig}`;
    const verified = await verifyInstallId(tampered, SECRET);
    expect(verified).toBeNull();
  });

  it("rejects a malformed install id with no separator", async () => {
    const verified = await verifyInstallId("not-a-valid-install-id", SECRET);
    expect(verified).toBeNull();
  });

  it("rejects a non-uuidv4 prefix even with a syntactically valid signature", async () => {
    const installId = await signInstallId("not-a-uuid-at-all", SECRET);
    const verified = await verifyInstallId(installId, SECRET);
    expect(verified).toBeNull();
  });
});
