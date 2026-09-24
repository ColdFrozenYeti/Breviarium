#!/usr/bin/env python3
"""Measure text lines in UI snapshot PNGs, in points, for comparison with design/reference/.

Every horizontal band of non-black pixels is one "line" (a text line, a rule, an icon).
Prints each line's top, bottom, height and x-extent in points (pixels divided by --scale,
3 for @3x screenshots). With --pitch, also prints the distance from each line's top to
the next line's top, which makes stanza gaps and paragraph spacing visible directly.

Build tooling only (Pillow); nothing here is linked into the app.

Usage:
  scripts/measure-snapshot.py design/reference/Format.png
  scripts/measure-snapshot.py --pitch snapshot.png
  scripts/measure-snapshot.py reference.png ours.png     # measures both, one after the other
"""
import argparse

from PIL import Image


def measure(path, scale, threshold):
    """Returns (top, bottom, left, right) bands in pixels, top to bottom."""
    image = Image.open(path).convert("RGB")
    width, height = image.size
    pixels = image.load()
    bands = []
    current = None
    for y in range(height):
        xs = [x for x in range(width) if max(pixels[x, y]) > threshold]
        if xs and current is None:
            current = [y, y, min(xs), max(xs)]
        elif xs:
            current[1] = y
            current[2] = min(current[2], min(xs))
            current[3] = max(current[3], max(xs))
        elif current is not None:
            bands.append(tuple(current))
            current = None
    if current is not None:
        bands.append(tuple(current))
    return bands


def report(path, scale, threshold, pitch):
    print(path)
    bands = measure(path, scale, threshold)
    previous_top = None
    for top, bottom, left, right in bands:
        line = (
            f"  y={top / scale:6.1f}-{bottom / scale:6.1f}pt h={(bottom - top) / scale:5.1f}"
            f" x={left / scale:5.1f}-{right / scale:5.1f} w={(right - left) / scale:5.1f}"
        )
        if pitch and previous_top is not None:
            line += f"  pitch={(top - previous_top) / scale:5.1f}"
        print(line)
        previous_top = top


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("images", nargs="+", help="PNG files to measure")
    parser.add_argument("--scale", type=float, default=3.0, help="pixels per point (default 3, for @3x)")
    parser.add_argument("--threshold", type=int, default=60, help="brightest channel above this counts as ink")
    parser.add_argument("--pitch", action="store_true", help="also print top-to-top distance between lines")
    args = parser.parse_args()
    for path in args.images:
        report(path, args.scale, args.threshold, args.pitch)


if __name__ == "__main__":
    main()
