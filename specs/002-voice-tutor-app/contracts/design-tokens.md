# Contract — design tokens

**Feature**: 002-voice-tutor-app | Source: `docs/ui-prototype.html` (one directory above this repo)

The prototype is the binding UI reference. These are its CSS custom properties, lifted verbatim into
a Dart token file. Nothing here is reinterpreted — a hex that differs from the prototype is a bug.

---

## Colour

| Token | Value | Role |
|---|---|---|
| `bg` | `#0a0c10` | Page ground, behind everything |
| `surface` | `#0d1117` | Cards, the problem card, the composer |
| `surface2` | `#161b22` | Raised: message bubbles, chips |
| `surface3` | `#1c2230` | Highest: the learner's own turn |
| `border` | `#21262d` | Default hairline |
| `border2` | `#30363d` | Emphasised hairline, focus |
| `text` | `#e6edf3` | Primary |
| `muted` | `#8b949e` | Secondary, labels |
| `faint` | `#6e7681` | Tertiary, "or type instead" |
| `accent` | `#3fb950` | The one accent. Mic, primary action, insight hit |
| `accentDim` / `accentBorder` | `rgba(63,185,80,.14)` / `.35` | Accent fills and outlines |
| `amber` | `#d29922` | Wrap-up nudge, the 15-second warning, hedged-borderline |
| `amberDim` / `amberBorder` | `rgba(210,153,34,.12)` / `.3` | |
| `red` | `#f85149` | Reserved. Failed send and destructive confirmation **only** |
| `redDim` | `rgba(248,81,73,.12)` | |
| `blue` | `#58a6ff` | Links, the language-pack route, informational |
| `blueDim` | `rgba(88,166,255,.12)` | |

**`red` is reserved and the reservation is load-bearing.** Most of what could reach for it is not an
error: a rate limit is the conversation catching up (FR-045a), a spent taster is a routing decision
(FR-007), a reached turn cap is a normal ending, and a verdict is never "wrong" (FR-030,
Principle IV). If red appears on a verdict screen, a taster screen, or a rate-limit screen, a
requirement has been broken — which makes "grep for red" a cheap review check.

## Type

| Token | Stack | Where |
|---|---|---|
| `mono` | `ui-monospace, "JetBrains Mono", "SF Mono", Menlo, Consolas, monospace` | Anything **numeric or systemic**: turn gauge, timer, hint counter, complexity, streak count, problem id, constraints |
| `sans` | `-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif` → **Roboto** on Android | **Prose**: statement, conversation, feedback, editorial, every explanatory line |

**The rule is the prototype's and it holds without exception**, because the boundary is what makes the
interface legible: monospace means "this is a number the system is telling you", sans means "this is
something someone wrote". A complexity annotation is mono; the sentence around it is sans.

## Semantics that must survive greyscale

**SC-015**: every screen legible and correctly distinguishable in greyscale — the share card, the
verdict, and the heatmap included. So colour is never the sole carrier of meaning:

- **Verdict chip** — hue *and* a word. The word is what a colourblind or greyscale reader gets, and
  it is hedged either way (FR-030).
- **Insights hit / missed** — distinct glyphs, not green and red dots.
- **Streak heatmap** — four **luminance** steps, not four hues. Ordered in greyscale by construction.
- **Share card** — FR-039b requires text-only and distinguishable without colour: shapes and words,
  never red/green, and never any part of the conversation.
- **Failed send** — an icon and a retry affordance, not just a red bubble.

`test/golden/` renders every screen through a saturation-zero filter and diffs against a checked-in
reference, so this is a build failure rather than a design review note.

## Accessibility

**FR-054, SC-014**: screen reader and dynamic text sizing on every screen.

- Text scales to the largest supported size with no clipping and no overlap — the turn gauge and the
  recording timer are the tight ones, and they get explicit tests.
- Semantic labels on the mic, the turn gauge (announced as remaining allowance, not as a score —
  FR-022a), the waveform (labelled, not read out), and every chip.
- The mic is a single large target; the "or type instead" link meets minimum touch size even though
  it is visually small (FR-009 requires it to be less prominent, not less reachable).
- **FR-053**: a learner who cannot or will not use voice is fully served by the keyboard, without
  that path being promoted over voice. Less prominent, never less capable.

## Localisation

**FR-052**: every learner-facing string in `l10n/app_en.arb` from the first commit. No string
literal in a widget — `custom_lint` enforces it. English only at launch, with translation needing no
code change.
