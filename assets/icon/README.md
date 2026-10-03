# The Dry Run icon

A terminal window. Inside it, a `>` prompt that is also a binary tree lying on its
side, followed by the cursor.

## Why this mark

**Three readings, all true, all native to the person using this app.**

- The **window frame** says *terminal* at a glance, at any size. It is what survives
  when the interior detail does not.
- Inside it, the same three points are a **binary tree** — apex on the right is the
  root, the two open ends are its children. That says *interview algorithms* far more
  specifically than any bracket, brace or question mark can.
- The bar on the baseline is the **cursor**: it is your turn. Here it is your turn to
  *speak*, which is the entire interaction.

## The frame is what defeats the share icon

Three nodes joined by two lines is **Android's own share icon**, mirrored. The
previous unframed mark tried to escape that by making the root node larger than its
children, and it did not work — side by side with the real share glyph the collision
was still the first thing you saw.

Share icons are never boxed. Enclosing the tree in a terminal window reframes it as
the *contents of a terminal*, and the collision disappears outright. The root is
still drawn larger than the children, and `generate.py` still asserts
`ROOT_R > CHILD_R`, but that hierarchy is now a nicety rather than the whole defence.

## The cursor sits on the baseline, next to the tree

An earlier composition placed the tree on the left of the interior and the cursor in
the bottom-right corner. Fitted independently, they read as two objects sharing a
box. The cursor is now laid out as part of the same group — gap smaller than the
stroke, bottom edge on the tree's baseline — and the group as a whole is fitted to
the interior. `generate.py` asserts `BAR_GAP < 1.0` (a multiple of the arm stroke),
because past that width it goes back to looking stranded.

Centring the bar on the root instead of the baseline was drawn and rejected: it reads
as a minus sign, `>-`.

## What the frame costs

The frame takes roughly a third of the safe circle, so everything inside is smaller
than the old unframed mark:

| | this mark | previous (unframed tree) |
|---|---|---|
| Frame stroke | 2.3 dp | — |
| Tree arm | 2.0 dp | 9.7 dp |
| Root diameter at 48 px | 3.7 px | 6.3 px |

Below about 48 px the interior reads as **mass, not as three distinct nodes**, and the
themed-monochrome layer — reused as the notification icon at ~24 dp — keeps little
more than the window outline. This is the accepted trade: the frame carries
recognition when small, the tree carries meaning when large. `generate.py` prints a
warning if either stroke falls below 1.2 px at 48 px, which is the antialiasing floor.

The other side of the trade is that a bare terminal window is **generic**: Termux,
Termius, Warp, Hyper, iTerm and JuiceSSH all own some version of it. That is a milder
collision than the share icon — it reads as *nothing specific* rather than as the
*wrong thing* — but it is real.

## Geometry, and why it is what it is

| Constraint | Value | Consequence here |
|---|---|---|
| Layer canvas | 108 × 108 dp | 1024 px working canvas |
| Masked viewport | inner 72 dp | 66.7% of canvas |
| **Guaranteed safe zone** | **66 dp circle** | 626 px — the only area no OEM mask can clip |
| Logo size | 48–66 dp | mark is **53.7 dp** |

**The safe zone is a circle, not a box, and that matters for a framed mark.** The
frame's corners are its outermost points and sit further from centre than its edges
do, so fitting the longest side to the circle's diameter would push them outside it.
`fit_safe_circle()` scales by the **circumscribed radius** instead. Max pixel radius
is 304.8 px against the 312.8 px the circle allows.

`generate.py` asserts and exits non-zero on: any opaque pixel outside the 66 dp safe
circle, the mark leaving the 48–66 dp band, the root not staying larger than the
children, and the cursor gap exceeding the stroke.

The monochrome layer is not optional: Android 13+ discards all colour and keeps
**only the alpha channel**, and Android 16 QPR2 auto-generates a themed icon — badly —
for any app shipping without one.

`pubspec.yaml` sets `adaptive_icon_foreground_inset: 0`. The package defaults to 16%,
which would double-pad an already safe-zone-fitted source below the spec's own minimum.

## Rejected directions

On collision grounds, before any aesthetic judgement: microphone and waveform (the
universal voice-AI cliché), speech bubble (says *text chat*, which this is not),
lightbulb, brain, sparkle, assistant orb, owl (Duolingo), and rubber duck (on-concept,
but Duckly uses one and it reads as a bath toy at 48 dp).

After drawing and rendering at real size: the **unframed tree** (the share icon, as
above); an unframed `>_` (clean and legible small, but gives up the tree entirely); a
chevron over a long baseline (the baseline merges with the lower arm at 48 px); a
debugger step-over arc (reads as **wifi bars**); two facing arcs (a **crescent moon**);
array cells (meaningless squares); code-indent bars (a text-align button); `O(▮)` (a
record button).

Dark ground with a green mark rather than a green field keeps clear of the
Duolingo / HackerRank / Grammarly green-disc cluster while staying clear of LeetCode,
which is dark + yellow.

## Regenerating

```bash
python3 tools/icon/generate.py     # redraws assets/icon/*.png, asserts the spec
dart run flutter_launcher_icons    # writes android/app/src/main/res/**
```

`play_store_512.png` is the listing icon: 512 × 512, opaque edge to edge, full square,
**no baked drop shadow** — Play masks to a 30% radius and adds its own shadow, and a
transparent asset would show the Play UI background through it.
