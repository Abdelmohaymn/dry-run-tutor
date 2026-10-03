// GET /privacy — the public privacy policy, served from the relay itself.
//
// Both stores require a reachable policy URL, so it is not optional. There
// is no custom domain (SHIP.md intro), so the worker that already serves the
// app is also the cheapest honest place to host this.
//
// The text is derived from specs/002-voice-tutor-app/PLAY-DATA-SAFETY.md
// and must not drift from it. In particular the audio paragraph draws the
// distinction Constitution VII (amended 2026-08-28) forbids blurring: this
// app does not collect audio, which is not the same claim as "audio never
// leaves the device".
import { Hono } from "hono";
import type { Env, Variables } from "../types";

/// The address a learner or a store reviewer can actually reach. Published
/// on a public page, so it is a deliberate choice rather than a default.
const CONTACT_EMAIL = "contact@example.com";

const LAST_UPDATED = "29 September 2026";

export const privacyRoute = new Hono<{ Bindings: Env; Variables: Variables }>();

privacyRoute.get("/", (c) => {
  return new Response(page(), {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=3600",
    },
  });
});

function page(): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Privacy Policy — Dry Run</title>
<style>
  :root { color-scheme: light dark; --fg: #16181d; --muted: #5b6270; --bg: #ffffff; --rule: #e3e6ec; }
  @media (prefers-color-scheme: dark) {
    :root { --fg: #e8eaf0; --muted: #9aa2b1; --bg: #14161a; --rule: #2a2e37; }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0 auto; padding: 40px 16px 80px; max-width: 46rem;
    background: var(--bg); color: var(--fg);
    font: 16px/1.65 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  h1 { font-size: 1.75rem; line-height: 1.25; margin: 0 0 .25rem; }
  h2 { font-size: 1.1rem; margin: 2.25rem 0 .5rem; }
  p, li { color: var(--fg); }
  .updated { color: var(--muted); font-size: .9rem; margin: 0 0 2rem; }
  table { border-collapse: collapse; width: 100%; margin: 1rem 0; font-size: .95rem; }
  th, td { text-align: left; padding: .5rem .6rem; border-bottom: 1px solid var(--rule); vertical-align: top; }
  th { color: var(--muted); font-weight: 600; }
  a { color: inherit; }
  footer { margin-top: 3rem; padding-top: 1rem; border-top: 1px solid var(--rule); color: var(--muted); font-size: .9rem; }
</style>
</head>
<body>
<h1>Privacy Policy — Dry Run</h1>
<p class="updated">Last updated ${LAST_UPDATED}</p>

<p>Dry Run is a voice tutor for interview practice. It has no accounts, no sign-in, and
nothing to buy. This page describes exactly what the app handles and what leaves your
device.</p>

<h2>Your voice is not collected</h2>
<p>Dry Run does not record, store, or transmit audio. Speech is handled by your phone's own
speech recognition service, which returns text to the app; no audio file is ever written and
no audio is ever sent to us. The microphone permission exists only because Android requires
it for speech recognition to run at all.</p>
<p>That is a statement about this app, and not a claim that audio never leaves your phone.
Android's speech recognition is documented as likely to stream audio to the device maker's
servers to perform the recognition. What your device maker does with that audio is covered by
your device maker's own privacy policy, not this one. The app explains this to you in plain
language before the microphone permission is ever requested.</p>

<h2>What the app does handle</h2>
<table>
  <tr><th>Data</th><th>Why</th><th>Where it goes</th></tr>
  <tr>
    <td>An install identifier</td>
    <td>Keeps your streak and session identity, and limits trial abuse</td>
    <td>Our relay. Created fresh for each install; not a hardware identifier and not linked to you</td>
  </tr>
  <tr>
    <td>App interaction events</td>
    <td>Understanding which parts of the app work</td>
    <td>Our relay. A fixed, closed list of events. No conversation text, no free-text fields, no key material</td>
  </tr>
  <tr>
    <td>Conversation and transcript text, when you supply your own API key</td>
    <td>Producing the tutor's reply. A spoken turn's transcript is also sent for correction before you confirm it, so a misheard word can be fixed before you see it</td>
    <td>The AI provider <em>you</em> chose — Groq or Google Gemini. Never your key's contents to anyone else. Check that provider's own terms for how it uses what it receives</td>
  </tr>
</table>

<h2>Advertising</h2>
<p>The app shows no advertisements and contains no advertising code.</p>

<h2>What we never collect</h2>
<ul>
  <li>The app never collects your name, email address, phone number, or any account details — there are no accounts</li>
  <li>Your location</li>
  <li>Your device's advertising identifier</li>
  <li>Payment information — the app sells nothing</li>
  <li>Your API key, which stays in your device's encrypted storage and is sent only to the
      provider you chose</li>
</ul>

<h2>On our website</h2>
<p><strong>Launch emails.</strong> If you ask to be told when Dry Run reaches the App Store,
we keep your email address. We use it once, to tell you. Then we delete it. Email <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a> to have it
deleted sooner.</p>
<p><strong>Counts.</strong> We count page visits and button taps without cookies and without
identifying you.</p>

<h2>Children</h2>
<p>Dry Run is intended for people preparing for job interviews and is not directed at
children.</p>

<h2>Keeping and deleting data</h2>
<p>Your practice history, disputes, and settings live on your device. The app's settings
screen can delete all of it, and uninstalling removes it. The install identifier and event
records on our relay are not tied to your identity and cannot be traced back to you.</p>

<h2>Changes</h2>
<p>If this policy changes, the date at the top of this page changes with it.</p>

<h2>Contact</h2>
<p>Questions about this policy: <a href="mailto:${CONTACT_EMAIL}">${CONTACT_EMAIL}</a></p>

<footer>Dry Run · app.dryrun</footer>
</body>
</html>`;
}
