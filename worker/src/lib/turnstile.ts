// Feature 007. Bot protection for the site's unauthenticated routes only
// (Complexity Tracking, plan.md). Never throws: a bad or unreachable
// siteverify call fails closed by returning false, never by surfacing an
// error to the caller.
export async function verifyTurnstile(
  secret: string,
  token: string,
  expectedAction: string,
  remoteip?: string,
): Promise<boolean> {
  try {
    const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ secret, response: token, remoteip }),
    });
    if (!res.ok) return false;
    const json = (await res.json()) as { success?: boolean; action?: string };
    // Test keys return no `action`, so allowing undefined keeps local dev working.
    return json.success === true && (json.action === expectedAction || json.action === undefined);
  } catch {
    return false;
  }
}
