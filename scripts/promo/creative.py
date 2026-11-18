#!/usr/bin/env python3
"""Composes the App Store creative assets from the promo stills (PromoUITests).

  - header.png: the product page header, 3840x1646 (21:9), with no text (the page shows
    the app's name below it);
  - search.png: the search results asset, 3840x2560 (3:2), a short caption above the
    screens, so the app's purpose is plain at a glance.

Since 1.7 both show the three devices in one image: the iPad's two-page spread in the
middle, the iPhone in front of its left edge and the open iPhone Duo on its side in front
of its right edge, from the iPhone's, the iPad's and the Duo's own stills.

Both keep their subject in the centre, as Apple asks, and have no alpha channel. They
share compose.py's ground, frame and gold edge. Build tooling only (Pillow).

    python3 -B scripts/promo/creative.py <iphone-stills> <ipad-stills> <duo-side-stills> <out-dir>
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
from compose import GOLD, GROUND_BOTTOM, GROUND_TOP, INK, RUBRIC, font, named_stills, rounded  # noqa: E402


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


def device(canvas: Image.Image, shot: Image.Image, height: int, cx: int, top: int, corner: int, dim: float = 0.0) -> Image.Image:
    """A screen in compose.py's frame, `height` pixels high, centred on `cx`; `corner` is
    its corner radius at the still's own size."""
    scale = height / shot.height
    shot = shot.resize((round(shot.width * scale), height), Image.LANCZOS)
    if dim:
        shot = Image.blend(shot, Image.new("RGB", shot.size, (0, 0, 0)), dim)
    radius = round(corner * scale)
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


class Stills:
    """The three devices' stills, by name (compose.py's `named_stills`, which reads the CI
    export's manifest), each turned upright and given its own corner."""

    def __init__(self, iphone: Path, ipad: Path, duo_side: Path):
        self.found = {**named_stills(iphone), **named_stills(ipad), **named_stills(duo_side)}

    def get(self, name: str) -> Image.Image:
        if name not in self.found:
            sys.exit(f"missing: {name}")
        shot = Image.open(self.found[name]).convert("RGB")
        # A landscape window's capture keeps the screen's orientation: the iPad's is
        # turned one way, the Duo's the other (compose.py).
        if name.startswith("ipad-") and shot.height > shot.width:
            shot = shot.rotate(90, expand=True)
        elif name.startswith("duo-side-") and shot.height > shot.width:
            shot = shot.rotate(-90, expand=True)
        return shot

    @staticmethod
    def corner(name: str) -> int:
        # The iPhone's rounded screen; the iPad's and the open Duo's squarer ones.
        return 150 if name.startswith("promo-") else 60


def family(canvas: Image.Image, stills: Stills, cx: int, bottom: int, ipad_height: int,
           names: tuple[str, str, str]) -> Image.Image:
    """The iPad in the middle, then the iPhone and the Duo in front of its edges, their
    bottoms level with the iPad's."""
    ipad, iphone, duo = names
    shot = stills.get(ipad)
    ipad_width = round(shot.width * ipad_height / shot.height)
    canvas = device(canvas, shot, ipad_height, cx, bottom - ipad_height, stills.corner(ipad))
    phone_height = round(ipad_height * 0.92)
    phone_shot = stills.get(iphone)
    phone_width = round(phone_shot.width * phone_height / phone_shot.height)
    canvas = device(canvas, phone_shot, phone_height, cx - ipad_width // 2 - phone_width // 5,
                    bottom - phone_height + round(ipad_height * 0.06), stills.corner(iphone))
    duo_height = round(ipad_height * 0.62)
    duo_shot = stills.get(duo)
    duo_width = round(duo_shot.width * duo_height / duo_shot.height)
    canvas = device(canvas, duo_shot, duo_height, cx + ipad_width // 2 + duo_width // 8,
                    bottom - duo_height + round(ipad_height * 0.06), stills.corner(duo))
    return canvas


def header(stills: Stills) -> Image.Image:
    w, h = 3840, 1646
    canvas = ground(w, h).convert("RGBA")
    canvas = family(canvas, stills, w // 2 - 60, h - 150, 1180,
                    ("ipad-02-facing", "promo-01-christmas-vespers", "duo-side-01-spread"))
    return canvas.convert("RGB")


def search(stills: Stills) -> Image.Image:
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
    canvas = family(canvas, stills, w // 2 - 70, h - 170, 1500,
                    ("ipad-02-facing", "promo-01-christmas-vespers", "duo-side-01-spread"))
    return canvas.convert("RGB")


def main() -> None:
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    stills = Stills(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
    out = Path(sys.argv[4])
    out.mkdir(parents=True, exist_ok=True)
    for name, make in [("header", header), ("search", search)]:
        target = out / f"{name}.png"
        make(stills).save(target, optimize=True)
        print(target)


if __name__ == "__main__":
    main()
