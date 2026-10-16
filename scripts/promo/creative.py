#!/usr/bin/env python3
"""Composes the App Store creative assets from the promo stills (PromoUITests).

  - header.png: the product page header, 3840x1646 (21:9), five screens fanned
    around the centre, with no text (the page shows the app's name below it).
  - search.png: the search results asset, 3840x2560 (3:2), a short caption over three
    screens, so the app's purpose is plain at a glance.

Both keep their subject in the centre, as Apple asks, and have no alpha channel. They
share compose.py's ground, frame and gold edge. Build tooling only (Pillow).

    python3 -B scripts/promo/creative.py <stills-dir> <out-dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from compose import GOLD, GROUND_BOTTOM, GROUND_TOP, INK, RUBRIC, font, rounded  # noqa: E402


def ground(w: int, h: int) -> Image.Image:
    """compose.py's warm dark ground, as a glow from the centre rather than the top."""
    image = Image.new("RGB", (w, h))
    pixels = image.load()
    cx, cy, reach = w / 2, h * 0.45, (w * w / 4 + h * h / 4) ** 0.5
    for y in range(h):
        for x in range(0, w, 4):
            t = min(1.0, ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / (reach * 0.75))
            colour = tuple(round(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM))
            for dx in range(4):
                if x + dx < w:
                    pixels[x + dx, y] = colour
    return image


def phone(canvas: Image.Image, still: Path, height: int, cx: int, top: int, dim: float = 0.0) -> Image.Image:
    shot = Image.open(still).convert("RGB")
    scale = height / shot.height
    shot = shot.resize((round(shot.width * scale), height), Image.LANCZOS)
    if dim:
        shot = Image.blend(shot, Image.new("RGB", shot.size, (0, 0, 0)), dim)
    radius = round(150 * scale)
    x = cx - shot.width // 2
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        [x - 6, top - 6, x + shot.width + 6, top + shot.height + 6], radius + 6,
        fill=GOLD + (round(110 * (1 - dim)),),
    )
    canvas = Image.alpha_composite(canvas, glow.filter(ImageFilter.GaussianBlur(40)))
    edge = tuple(round(c * (1 - dim)) for c in GOLD) + (255,)
    ImageDraw.Draw(canvas).rounded_rectangle(
        [x - 4, top - 4, x + shot.width + 3, top + shot.height + 3], radius + 4, fill=edge
    )
    canvas.alpha_composite(rounded(shot, radius), (x, top))
    return canvas


def pick(stills: Path, name: str) -> Path:
    matches = sorted(stills.glob(f"{name}*.png"))
    if not matches:
        sys.exit(f"missing: {name}")
    return matches[0]


def header(stills: Path) -> Image.Image:
    w, h = 3840, 1646
    canvas = ground(w, h).convert("RGBA")
    # Outermost first, so the centre screen sits on top.
    layout = [
        ("promo-05-calendar", 1080, w // 2 - 1300, 0.45),
        ("promo-07-easter-lauds", 1080, w // 2 + 1300, 0.45),
        ("promo-03-english", 1260, w // 2 - 680, 0.2),
        ("promo-06-vellum-matins", 1260, w // 2 + 680, 0.2),
        ("promo-01-christmas-vespers", 1440, w // 2, 0.0),
    ]
    for name, height, cx, dim in layout:
        canvas = phone(canvas, pick(stills, name), height, cx, (h - height) // 2 + 40, dim)
    return canvas.convert("RGB")


def search(stills: Path) -> Image.Image:
    w, h = 3840, 2560
    canvas = ground(w, h).convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    title = font("GentiumBookPlus-Bold.ttf", 190)
    sub = font("SourceSans3-Regular.ttf", 92)
    line = "The traditional Divine Office"
    draw.text(((w - draw.textlength(line, font=title)) / 2, 150), line, font=title, fill=INK)
    draw.line([(w / 2 - 110, 445), (w / 2 + 110, 445)], fill=GOLD, width=6)
    line = "Every hour, in Latin and English, for any day"
    draw.text(((w - draw.textlength(line, font=sub)) / 2, 490), line, font=sub, fill=RUBRIC)
    top, height = 760, 2000  # runs off the bottom edge
    for name, cx in [
        ("promo-03-english", w // 2 - 1150),
        ("promo-06-vellum-matins", w // 2 + 1150),
        ("promo-01-christmas-vespers", w // 2),
    ]:
        canvas = phone(canvas, pick(stills, name), height, cx, top)
    return canvas.convert("RGB")


def main() -> None:
    stills, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for name, make in [("header", header), ("search", search)]:
        target = out / f"{name}.png"
        make(stills).save(target, optimize=True)
        print(target)


if __name__ == "__main__":
    main()
