"""Dry Run launcher icon.

The mark: a terminal window, and inside it a `>` prompt that is also a binary
tree lying on its side, followed by the cursor.

  - The window frame says *terminal* at a glance, at any size, and it is what
    survives when the interior detail does not.
  - Inside it, the three points are a binary tree: apex on the right is the
    root, the two open ends are its children. That is what the problems are
    actually made of, and it says "interview algorithms" more specifically
    than any bracket or brace can.
  - The bar on the baseline is the cursor. It sits immediately after the tree,
    with a gap smaller than the stroke, so the two read as one prompt rather
    than as two objects sharing a box.

**The frame is what defeats the share icon.** Three nodes joined by two lines
is Android's own share glyph, mirrored, and the previous unframed mark could
not escape that reading - making the root node larger was not enough. Share
icons are never boxed, so enclosing the tree in a terminal window reframes it
as the *contents of a terminal* and the collision disappears.

The cost is paid at small sizes: the frame takes roughly a third of the safe
circle, so the tree inside is smaller than it was standing alone, and below
about 48px the interior reads as mass rather than as three distinct nodes.
That is the accepted trade - the frame carries recognition when small, the
tree carries meaning when large.

Geometry is driven by the adaptive-icon spec: 108dp canvas, 72dp viewport,
66dp guaranteed-safe circle. On this 1024px canvas the safe circle is 626px
across, so the mark is fitted to it by CIRCUMSCRIBED RADIUS and centred - it
cannot clip under a circle, squircle, rounded-square or teardrop mask.
"""
from PIL import Image, ImageDraw
import json, os
import numpy as np

S = 1024                 # the 108dp adaptive layer, in px
SS = 2                   # supersample factor while drawing
BG = (13, 17, 23)        # #0d1117 surface - lifted off pure black on purpose
FG = (63, 185, 80)       # #3fb950 the single accent
SAFE_D = S * 0.611       # 66dp of 108dp = 626px
SAFE_MARGIN = 0.97       # breathing room inside the safe circle

# --- the terminal window, in 1024-canvas units before the safe-circle fit ---
FRAME_A = 304            # half-width
FRAME_B = 252            # half-height
FRAME_R = 80             # corner radius
FRAME_T = 52             # stroke
PAD     = 22             # interior padding between frame and contents

# --- the tree, same units. Fitted into the interior alongside the cursor. ---
ARM     = 104            # stroke of the two edges
ROOT_R  = 140            # root node radius  - deliberately larger than...
CHILD_R = 100            # ...the two child nodes, so the hierarchy is visible
SPREAD  = 250            # vertical half-distance between the children
REACH   = 258            # horizontal half-span, children to root

# --- the cursor, expressed against the tree's stroke so they scale together ---
BAR_H    = 0.95          # bar height, as a multiple of ARM
BAR_W    = 2.2           # bar width, as a multiple of its own height
BAR_GAP  = 0.60          # gap from the root node, as a multiple of ARM


def _line(p0, p1, n=900):
    return [(p0[0] + (p1[0] - p0[0]) * i / n,
             p0[1] + (p1[1] - p0[1]) * i / n) for i in range(n + 1)]


def _brush(d, pts, w, colour):
    """Stroke a path as overlapping discs - gives round caps and joins."""
    r = w / 2
    for x, y in pts:
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour)


def glyph(colour):
    """The mark alone, transparent, drawn large and cropped to its content."""
    k = SS
    pad = 900 * k
    im = Image.new("RGBA", (S * k + pad, S * k + pad), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx, cy = im.width // 2, im.height // 2

    d.rounded_rectangle([(cx - FRAME_A * k, cy - FRAME_B * k),
                         (cx + FRAME_A * k, cy + FRAME_B * k)],
                        radius=FRAME_R * k, outline=colour, width=FRAME_T * k)

    inner_w = 2 * (FRAME_A - FRAME_T - PAD)
    inner_h = 2 * (FRAME_B - FRAME_T - PAD)

    # Compose tree + cursor as one group, then fit that group to the interior.
    # Laying them out independently is what made the cursor look stranded in
    # the corner rather than attached to the prompt.
    t_left,  t_right  = -REACH - CHILD_R, REACH + ROOT_R
    t_top,   t_bottom = -(SPREAD + CHILD_R), SPREAD + CHILD_R
    bar_h = ARM * BAR_H
    bar_w = bar_h * BAR_W
    b_left = t_right + ARM * BAR_GAP
    b_right, b_bottom, b_top = b_left + bar_w, t_bottom, t_bottom - bar_h

    s = min(inner_w / (b_right - t_left), inner_h / (t_bottom - t_top))
    ox, oy = (t_left + b_right) / 2, 0.0
    P = lambda x, y: (cx + (x - ox) * s * k, cy + (y - oy) * s * k)

    arm, rr, cr = ARM * s, ROOT_R * s, CHILD_R * s
    root  = P(REACH, 0)
    upper = P(-REACH, -SPREAD)
    lower = P(-REACH, SPREAD)
    _brush(d, _line(root, upper) + _line(root, lower), arm * k, colour)
    for point, radius in ((root, rr), (upper, cr), (lower, cr)):
        d.ellipse([point[0] - radius * k, point[1] - radius * k,
                   point[0] + radius * k, point[1] + radius * k], fill=colour)

    d.rounded_rectangle([P(b_left, b_top), P(b_right, b_bottom)],
                        radius=(bar_h * s / 2) * k, fill=colour)

    return im.crop(im.getbbox()), {"arm": arm, "root": rr, "bar_h": bar_h * s}


def _place(g, canvas, bg):
    out = Image.new("RGBA", (canvas, canvas), (*bg, 255) if bg else (0, 0, 0, 0))
    out.alpha_composite(g, ((canvas - g.width) // 2, (canvas - g.height) // 2))
    return out


def _scaled(g, scale):
    return g.resize((max(1, round(g.width * scale)), max(1, round(g.height * scale))),
                    Image.LANCZOS)


def fit_safe_circle(colour, canvas=S, bg=None):
    """Scale the mark so it fits the 66dp safe CIRCLE, not a safe box.

    The frame's corners are its outermost points, and they sit further from
    centre than its edges do. Fitting the longest side to the circle's
    diameter would push those corners outside it. Scale by the circumscribed
    radius instead.
    """
    g, parts = glyph(colour)
    a = np.array(g.split()[-1])
    ys, xs = np.nonzero(a > 8)
    r_native = float(np.hypot(xs - g.width / 2, ys - g.height / 2).max())
    scale = (SAFE_D / 2 * SAFE_MARGIN) / r_native
    return _place(_scaled(g, scale), canvas, bg), scale, parts


def fit_longest(target_px, colour, canvas=S, bg=None):
    """Scale by longest side - correct for the square, unmasked Play icon."""
    g, _ = glyph(colour)
    return _place(_scaled(g, target_px / max(g.size)), canvas, bg)


REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(REPO, "assets", "icon")
os.makedirs(OUT, exist_ok=True)

# --- adaptive layers: mark fitted inside the 626px safe circle ---
fg, SCALE, PARTS = fit_safe_circle(FG)
fg.save(f"{OUT}/foreground.png")
fit_safe_circle((255, 255, 255))[0].save(f"{OUT}/monochrome.png")
Image.new("RGBA", (S, S), (*BG, 255)).save(f"{OUT}/background.png")

# --- full-bleed square for the Play listing + legacy icons ---
# Opaque edge to edge and no baked drop shadow: Play masks to a 30% radius and
# adds its own shadow, and a transparent asset would show the Play UI through it.
square = fit_longest(int(S * 0.70), FG, bg=BG).convert("RGB")
square.save(f"{OUT}/icon.png")
square.resize((512, 512), Image.LANCZOS).save(f"{OUT}/play_store_512.png")

# --- verification -------------------------------------------------------
# Test actual opaque pixels, not the bounding box: this mark does not fill its
# box corners, so a corner test would fail an icon that is fine.
alpha = np.array(Image.open(f"{OUT}/foreground.png").split()[-1])
ys, xs = np.nonzero(alpha > 8)
radius = np.hypot(xs - S / 2, ys - S / 2)
bb = Image.open(f"{OUT}/foreground.png").getbbox()
mark_dp = max(bb[2] - bb[0], bb[3] - bb[1]) / S * 108
dp = lambda v: round(v * SCALE / S * 108, 2)      # canvas units -> dp of 108
px48 = lambda v: round(v * SCALE * 48 / (S * 72 / 108), 2)   # -> px on a 48px icon

report = {
    "mark_dp_of_108": round(mark_dp, 1),
    "spec_range_dp": "48-66",
    "mark_within_spec": 48 <= mark_dp <= 66,
    "frame_stroke_dp": dp(FRAME_T),
    "tree_arm_dp": dp(PARTS["arm"]),
    "cursor_bar_dp": dp(PARTS["bar_h"]),
    "frame_stroke_px_at_48": px48(FRAME_T),
    "tree_arm_px_at_48": px48(PARTS["arm"]),
    "root_diameter_px_at_48": px48(2 * PARTS["root"]),
    "max_pixel_radius_px": round(float(radius.max()), 1),
    "safe_circle_radius_px": round(SAFE_D / 2, 1),
    "pixels_outside_safe_circle": int((radius > SAFE_D / 2).sum()),
    "clips_under_any_mask": bool((radius > SAFE_D / 2).any()),
    "root_larger_than_children": ROOT_R > CHILD_R,
    "cursor_attached_to_prompt": BAR_GAP < 1.0,
}
print(json.dumps(report, indent=2))
if report["clips_under_any_mask"] or not report["mark_within_spec"]:
    raise SystemExit("icon violates the adaptive-icon spec - see report above")
if not report["root_larger_than_children"]:
    raise SystemExit("root must stay larger than the children - see the share-icon note above")
if not report["cursor_attached_to_prompt"]:
    raise SystemExit("cursor gap exceeds the stroke - it reads as a stranded rectangle")
# Not fatal, but the frame is what makes these strokes thin: watch them.
for k in ("frame_stroke_px_at_48", "tree_arm_px_at_48"):
    if report[k] < 1.2:
        print(f"WARNING: {k} = {report[k]}px - at or below the antialiasing floor")
