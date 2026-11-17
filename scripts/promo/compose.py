#!/usr/bin/env python3
"""Composes the App Store screenshots from the promo stills (PromoUITests).

Each image is 1320x2868 (6.9" iPhone, the App Store's required size): a caption in the
app's own bundled fonts above the screenshot, which sits in a rounded frame on a dark
ground. With --ipad (1.4), 2752x2064, the 13" iPad's size in landscape, from the iPad's
stills (the two-page spread), turned upright first. With --duo (1.7), 2007x2853, the
iPhone Duo's open inner screen, and with --duo-outer, 1398x2034, its folded outer screen
(Apple's screenshot specification), from the iPhone's stills taken on the Duo; the
layout is the iPhone's, scaled to the height. Build tooling only (Pillow); nothing here
ships in the app.

    python3 -B scripts/promo/compose.py [--ipad | --duo | --duo-outer] <stills-dir> <out-dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "App/Breviarium/Fonts"
W, H = 1320, 2868
IPAD = False
# The iPhone layout's sizes are for 2868 px; the Duo's two screens scale them to their own
# height (1.7).
F = 1.0

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

# The iPad's (1.4): one line each, above a landscape screenshot.
SHOTS_IPAD = [
    ("ipad-01-spread", "The traditional Divine Office", "Breviarium Romanum, 1960 rubrics, as an open book"),
    ("ipad-02-facing", "Latin and English, on facing pages", "Douay-Rheims and Divinum Officium"),
    ("ipad-03-calendar", "Any day, any year", "The Kalendarium, computed on your iPad"),
    ("ipad-04-hours", "Every hour, from Matins to Compline", "With the Martyrology after Prime"),
    ("ipad-05-vellum-matins", "Matins, with every lesson", "All Saints, in the Vellum theme"),
    ("ipad-06-themes", "Eight themes, six typefaces", "Dark for the night, light for the day"),
    ("ipad-07-dominican", "The Dominican office too", "Ordo Prædicatorum, 1962"),
    ("ipad-08-ambrosian", "And Ambrosian Compline", "From the 1957 Ambrosian breviary"),
    ("ipad-09-settings", "Fully offline", "No account, no tracking, no data collected"),
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

    title_font = font("GentiumBookPlus-Bold.ttf", round(112 * F))
    sub_font = font("SourceSans3-Regular.ttf", round(50 * F))
    y = 120 if IPAD else round(190 * F)
    for line in caption.split("\n"):
        width = draw.textlength(line, font=title_font)
        draw.text(((W - width) / 2, y), line, font=title_font, fill=INK)
        y += round(132 * F)
    y += 24 if IPAD else round(44 * F)
    draw.line([(W / 2 - 70 * F, y), (W / 2 + 70 * F, y)], fill=GOLD, width=max(2, round(4 * F)))
    y += 28 if IPAD else round(40 * F)
    width = draw.textlength(subline, font=sub_font)
    draw.text(((W - width) / 2, y), subline, font=sub_font, fill=RUBRIC)

    shot = Image.open(still).convert("RGB")
    if IPAD and shot.height > shot.width:
        # A landscape window's capture keeps the screen's orientation (landscape left).
        shot = shot.rotate(90, expand=True)
    top = 470 if IPAD else round(760 * F)
    scale = (H - top + 120) / shot.height  # runs off the bottom edge a little
    scale = min(scale, 0.84 * W / shot.width)
    shot = shot.resize((round(shot.width * scale), round(shot.height * scale)), Image.LANCZOS)
    radius = round((60 if IPAD else 150) * scale)
    if shot.width > shot.height * 0.6:
        # The open Duo's page is nearly square: a smaller corner, as on the iPad.
        radius = round(60 * scale)
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
    global W, H, IPAD, F
    args = sys.argv[1:]
    if args and args[0] == "--ipad":
        IPAD = True
        W, H = 2752, 2064
        args = args[1:]
    elif args and args[0] in ("--duo", "--duo-outer"):
        W, H = (2007, 2853) if args[0] == "--duo" else (1398, 2034)
        F = H / 2868
        args = args[1:]
    stills, out = Path(args[0]), Path(args[1])
    out.mkdir(parents=True, exist_ok=True)
    for index, (name, caption, subline) in enumerate(SHOTS_IPAD if IPAD else SHOTS, start=1):
        matches = sorted(stills.glob(f"{name}*.png"))
        if not matches:
            print(f"missing: {name}")
            continue
        image = compose(matches[0], caption, subline)
        target = out / f"{index:02d}-{name.split('-', 2)[2]}.png"
        image.save(target, optimize=True)
        print(target)


if __name__ == "__main__":
    main()
