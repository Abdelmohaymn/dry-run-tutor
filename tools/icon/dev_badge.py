"""Dry Run dev launcher icon: the prod icon with an amber "DEV" strip.

The dev flavor installs next to the prod app, so the two need to be told apart
in the launcher at a glance. This script reads the PROD icons from
android/app/src/main/res and writes badged copies into android/app/src/dev/res.
It never writes to `main`.

What it produces (10 PNGs, one per density, mdpi to xxxhdpi):
  - drawable-<d>/ic_launcher_foreground.png  the adaptive foreground, badged
  - mipmap-<d>/ic_launcher.png               the legacy icon, badged, opaque RGB

The adaptive background and monochrome layers are NOT copied: the dev source
set inherits them from `main`. launch_image.png and splash_branding.png are not
copied either.

The adaptive-foreground strip sits just inside the 66/108 safe circle (corner
radius 0.3048 of the canvas, limit 0.3056), so no launcher mask clips it.

Run from the repo root:

    python3 tools/icon/dev_badge.py

Re-run after tools/icon/generate.py changes the prod icon.
"""
from PIL import Image, ImageDraw, ImageFont
import os

AMBER = (210, 153, 34, 255)   # #D29922 AppTokens.amber
INK = (13, 17, 23, 255)       # #0d1117 surface
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
TEXT = "DEV"
SS = 4                        # supersample factor while drawing
DENSITIES = ("mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi")

# (box as fractions of the icon's width, corner radius, font px) - icons are
# square, so every fraction, x and y alike, is multiplied by the width.
FOREGROUND = dict(box=(0.30, 0.63, 0.70, 0.73), radius=0.03, font_px=0.075)
LEGACY = dict(box=(0.14, 0.64, 0.86, 0.80), radius=0.04, font_px=0.12)

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "android", "app", "src", "main", "res")
OUT = os.path.join(REPO, "android", "app", "src", "dev", "res")


def _font(px):
    if os.path.exists(FONT):
        return ImageFont.truetype(FONT, px)
    return ImageFont.load_default(size=px)


def badge(img, box, radius, font_px):
    """Draw the amber "DEV" strip on `img` and return it as RGBA.

    Drawn at SS x size and downsampled with LANCZOS for anti-aliasing.
    """
    img = img.convert("RGBA")
    w = img.width
    big = img.resize((w * SS, w * SS), Image.LANCZOS)
    d = ImageDraw.Draw(big)

    x0, y0, x1, y1 = (v * w * SS for v in box)
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius * w * SS, fill=AMBER)

    font = _font(max(1, round(font_px * w * SS)))
    l, t, r, b = font.getbbox(TEXT)
    # getbbox is relative to the text origin; offset by its left/top so the ink
    # (not the advance box) is what ends up centred in the strip.
    tx = (x0 + x1) / 2 - (l + r) / 2
    ty = (y0 + y1) / 2 - (t + b) / 2
    d.text((tx, ty), TEXT, font=font, fill=INK)

    return big.resize((w, w), Image.LANCZOS)


def _process(rel_dir, name, params, to_rgb=False):
    for density in DENSITIES:
        src = os.path.join(SRC, f"{rel_dir}-{density}", name)
        dst_dir = os.path.join(OUT, f"{rel_dir}-{density}")
        os.makedirs(dst_dir, exist_ok=True)
        out = badge(Image.open(src), **params)
        if to_rgb:
            out = out.convert("RGB")
        out.save(os.path.join(dst_dir, name))
        print(f"wrote {os.path.relpath(os.path.join(dst_dir, name), REPO)}")


_process("drawable", "ic_launcher_foreground.png", FOREGROUND)
_process("mipmap", "ic_launcher.png", LEGACY, to_rgb=True)
