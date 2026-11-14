#!/usr/bin/env python3
"""The Lock Screen widget's logo (1.5): the default app icon's B, traced to a vector.

Build tooling only (CLAUDE.md: nothing here is linked into the app). Takes the default
icon (Northumberland Simple), keeps its blue and red strokes and drops the cream ground,
closes the thin cream lines between the two colours so the letter reads as one solid
shape at Lock Screen size, traces it with potracer (pure-Python potrace) and writes an
SVG cropped square around the letter. The widget draws it as a template image, so the
system tints it.

    python3 -m venv venv && venv/bin/pip install potracer pillow numpy
    venv/bin/python scripts/widget-logo.py \
        App/Breviarium/Assets.xcassets/AppIcon.appiconset/icon-1024.png \
        App/Shared/WidgetAssets.xcassets/WidgetLogo.imageset/widget-logo.svg
"""
import sys

import numpy as np
import potrace
from PIL import Image, ImageFilter

source, output = sys.argv[1], sys.argv[2]
pixels = np.asarray(Image.open(source).convert("RGB")).astype(int)
ground = pixels[5, 5]
mask = np.sqrt(((pixels - ground) ** 2).sum(axis=2)) > 60

# A closing of about 9 px fills the cream lines between the red and the blue.
closed = Image.fromarray((mask * 255).astype("uint8")).filter(ImageFilter.MaxFilter(19)).filter(ImageFilter.MinFilter(19))
mask = np.asarray(closed) > 127

# potracer fills the False pixels, so it traces the inverse.
path = potrace.Bitmap(~mask).trace(turdsize=8, alphamax=1.0, opticurve=True, opttolerance=0.2)

parts = []
for curve in path:
    start = curve.start_point
    d = [f"M{start.x:.2f},{start.y:.2f}"]
    for segment in curve.segments:
        if segment.is_corner:
            d.append(f"L{segment.c.x:.2f},{segment.c.y:.2f}L{segment.end_point.x:.2f},{segment.end_point.y:.2f}")
        else:
            d.append(
                f"C{segment.c1.x:.2f},{segment.c1.y:.2f} {segment.c2.x:.2f},{segment.c2.y:.2f} "
                f"{segment.end_point.x:.2f},{segment.end_point.y:.2f}"
            )
    d.append("Z")
    parts.append("".join(d))

# A square view box centred on the letter, with 2% to spare.
rows, columns = np.where(mask)
top, bottom, left, right = rows.min(), rows.max(), columns.min(), columns.max()
side = max(bottom - top, right - left) * 1.04
cx, cy = (left + right) / 2, (top + bottom) / 2
box = f"{cx - side / 2:.1f} {cy - side / 2:.1f} {side:.1f} {side:.1f}"
svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{box}" width="{side:.0f}" height="{side:.0f}">'
    f'<path fill="#000000" fill-rule="evenodd" d="{" ".join(parts)}"/></svg>\n'
)
with open(output, "w") as file:
    file.write(svg)
print(f"{len(path)} curves, {len(svg)} bytes, view box {box}")
