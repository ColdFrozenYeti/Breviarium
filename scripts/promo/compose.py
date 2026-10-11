#!/usr/bin/env python3
"""Composes the App Store screenshots from the promo stills (PromoUITests).

Each image is 1320x2868 (6.9" iPhone, the App Store's required size): a caption in the
app's own bundled fonts above the screenshot, which sits in a rounded frame on a dark
ground. Build tooling only (Pillow); nothing here ships in the app.

    python3 -B scripts/promo/compose.py <stills-dir> <out-dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "App/Breviarium/Fonts"
W, H = 1320, 2868

INK = (255, 255, 255)
RUBRIC = (255, 128, 128)  # #FF8080, the Nox theme's rubric red
GOLD = (184, 145, 47)  # #B8912F, the calendar's gold edge
GROUND_TOP = (24, 18, 14)
GROUND_BOTTOM = (0, 0, 0)

# (still, caption, subline), in the listing's order.
SHOTS = [
    ("promo-01-christmas-vespers", "The traditional\nDivine Office", "Breviarium Romanum, 1960 rubrics"),
    ("promo-03-english", "Latin and English,\nside by side", "Douay-Rheims and Divinum Officium"),
    ("promo-04-hours", "Every hour, from\nMatins to Compline", "With the Martyrology after Prime"),
    ("promo-05-calendar", "Any day,\nany year", "Computed on your phone, with its colour"),
    ("promo-07-easter-lauds", "Through the\nwhole year", "Easter Lauds, in the Media nox theme"),
    ("promo-08-themes", "Eight themes,\nsix typefaces", "Dark for the night, light for the day"),
    ("promo-06-vellum-matins", "Matins, with\nevery lesson", "All Saints, in the Vellum theme"),
    ("promo-09-dominican", "The Dominican\noffice too", "Ordo Prædicatorum, 1962"),
    ("promo-10-ambrosian", "And Ambrosian\nCompline", "From the 1957 Ambrosian breviary"),
    ("promo-11-settings", "Fully offline", "No account, no tracking, no data collected"),
]


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def ground() -> Image.Image:
    image = Image.new("RGB", (W, H))
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = min(1.0, y / (H * 0.6))
        colour = tuple(round(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM))
        draw.line([(0, y), (W, y)], fill=colour)
    return image


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius, fill=255)
    out = image.convert("RGBA")
    out.putalpha(mask)
    return out


def compose(still: Path, caption: str, subline: str) -> Image.Image:
    canvas = ground()
    draw = ImageDraw.Draw(canvas)

    title_font = font("GentiumBookPlus-Bold.ttf", 112)
    sub_font = font("SourceSans3-Regular.ttf", 50)
    y = 190
    for line in caption.split("\n"):
        width = draw.textlength(line, font=title_font)
        draw.text(((W - width) / 2, y), line, font=title_font, fill=INK)
        y += 132
    y += 44
    draw.line([(W / 2 - 70, y), (W / 2 + 70, y)], fill=GOLD, width=4)
    y += 40
    width = draw.textlength(subline, font=sub_font)
    draw.text(((W - width) / 2, y), subline, font=sub_font, fill=RUBRIC)

    shot = Image.open(still).convert("RGB")
    top = 760
    scale = (H - top + 120) / shot.height  # runs off the bottom edge a little
    scale = min(scale, 0.84 * W / shot.width)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    radius = round(150 * scale)
    framed = rounded(shot, radius)
    x = (W - shot.width) // 2

    # A soft gold glow behind the frame, then a thin gold edge.
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        [x - 6, top - 6, x + shot.width + 6, top + shot.height + 6], radius + 6, fill=GOLD + (110,)
    )
    glow = glow.filter(ImageFilter.GaussianBlur(40))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), glow)
    edge = ImageDraw.Draw(canvas)
    edge.rounded_rectangle([x - 4, top - 4, x + shot.width + 3, top + shot.height + 3], radius + 4, fill=GOLD + (255,))
    canvas.alpha_composite(framed, (x, top))
    return canvas.convert("RGB")


def main() -> None:
    stills, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    for index, (name, caption, subline) in enumerate(SHOTS, start=1):
        matches = sorted(stills.glob(f"{name}*.png"))
        if not matches:
            print(f"missing: {name}")
            continue
        image = compose(matches[0], caption, subline)
        target = out / f"{index:02d}-{name.removeprefix('promo-')[3:]}.png"
        image.save(target, optimize=True)
        print(target)


if __name__ == "__main__":
    main()
