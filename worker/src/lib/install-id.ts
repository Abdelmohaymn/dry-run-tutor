// research.md R-009. Signs and verifies a device hash as
// `<device_hash>.<base64url HMAC-SHA256>` so a modified client cannot mint or
// impersonate another device's identity. `<device_hash>` is 64 lowercase hex
// (specs/006-lean-backend research.md R-2). Does NOT prevent trial farming —
// see research.md R-009.

const DEVICE_HASH_RE = /^[0-9a-f]{64}$/;

async function importKey(secret: string): Promise<CryptoKey> {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign", "verify"],
  );
}

function toBase64Url(bytes: ArrayBuffer): string {
  let binary = "";
  for (const byte of new Uint8Array(bytes)) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function fromBase64Url(value: string): Uint8Array | null {
  if (!/^[A-Za-z0-9_-]+$/.test(value)) return null;
  const padded = value.replace(/-/g, "+").replace(/_/g, "/") + "=".repeat((4 - (value.length % 4)) % 4);
  try {
    const binary = atob(padded);
    return Uint8Array.from(binary, (c) => c.charCodeAt(0));
  } catch {
    return null;
  }
}

/** Signs a device hash, returning `<device_hash>.<sig>`. */
export async function signInstallId(deviceHash: string, secret: string): Promise<string> {
  const key = await importKey(secret);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(deviceHash));
  return `${deviceHash}.${toBase64Url(signature)}`;
}

/**
 * Verifies `<device_hash>.<sig>`. Returns the hash on a valid signature over a
 * well-formed 64-hex hash, and null on any tamper, malformed shape (including
 * a legacy `<uuidv4>.<sig>`), or wrong key.
 */
export async function verifyInstallId(installId: string, secret: string): Promise<string | null> {
  const separatorIndex = installId.lastIndexOf(".");
  if (separatorIndex < 0) return null;

  const deviceHash = installId.slice(0, separatorIndex);
  const signaturePart = installId.slice(separatorIndex + 1);
  if (!DEVICE_HASH_RE.test(deviceHash)) return null;

  const signatureBytes = fromBase64Url(signaturePart);
  if (!signatureBytes) return null;

  const key = await importKey(secret);
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    signatureBytes,
    new TextEncoder().encode(deviceHash),
  );
  return valid ? deviceHash : null;
}
