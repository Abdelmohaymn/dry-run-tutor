// research.md R-009. Signs and verifies an install UUID as
// `<uuidv4>.<base64url HMAC-SHA256>` so a modified client cannot mint or
// impersonate another install's identity. Does NOT prevent trial farming —
// see research.md R-009.

const UUID_V4_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

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

/** Signs a learner-supplied install UUID, returning `<uuidv4>.<sig>`. */
export async function signInstallId(installUuid: string, secret: string): Promise<string> {
  const key = await importKey(secret);
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(installUuid));
  return `${installUuid}.${toBase64Url(signature)}`;
}

/**
 * Verifies `<uuidv4>.<sig>`. Returns the UUID on a valid signature over a
 * well-formed uuidv4, and null on any tamper, malformed shape, or wrong key.
 */
export async function verifyInstallId(installId: string, secret: string): Promise<string | null> {
  const separatorIndex = installId.lastIndexOf(".");
  if (separatorIndex < 0) return null;

  const uuid = installId.slice(0, separatorIndex);
  const signaturePart = installId.slice(separatorIndex + 1);
  if (!UUID_V4_RE.test(uuid)) return null;

  const signatureBytes = fromBase64Url(signaturePart);
  if (!signatureBytes) return null;

  const key = await importKey(secret);
  const valid = await crypto.subtle.verify(
    "HMAC",
    key,
    signatureBytes,
    new TextEncoder().encode(uuid),
  );
  return valid ? uuid : null;
}
