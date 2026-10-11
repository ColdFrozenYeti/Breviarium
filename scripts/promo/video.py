#!/usr/bin/env python3
"""Cuts the promo videos from promo.yml's screen recording (PromoUITests' tours).

Two outputs, both H.264 with a silent AAC track:
  - app-preview.mp4: the App Store app preview, 886x1920 at 30 fps, under 30 s, the
    recording alone;
  - promo.mp4: a 1080x1920 promo for social media, the recording in a gold-edged frame
    under a caption per scene, between a title card and a closing card, in the style of
    compose.py's screenshots.

Build tooling only (Pillow, and ffmpeg from imageio-ffmpeg or the PATH).

    python3 -B scripts/promo/video.py <recording.mov> <out-dir>

The cut points are seconds into the recording, read off a frame sheet of the 11
October 2026 run; a new recording needs them read again.
"""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.path.insert(0, str(Path(__file__).parent))
from compose import FONTS, GOLD, GROUND_BOTTOM, GROUND_TOP, INK, RUBRIC, ROOT  # noqa: E402

FPS = 30
FADE = 0.4

# (start, end, caption, subline), in the order shown.
SCENES = [
    (265.6, 275.6, "Turn the page", "Christmas Vespers, set like a printed book"),
    (287.0, 289.6, "Every hour", "From Matins to Compline"),
    (292.6, 295.6, "Every hour", "From Matins to Compline"),
    (309.4, 316.6, "Any day, any year", "Computed on your phone, with its colour"),
    (329.8, 335.6, "Latin and English", "Side by side, verse by verse"),
    (361.6, 363.6, "Eight themes", "And six typefaces"),
    (372.6, 375.4, "Eight themes", "And six typefaces"),
    (381.2, 386.8, "Eight themes", "And six typefaces"),
]

# The App Store preview's cut of the same scenes, kept under 30 seconds.
PREVIEW = [(265.6, 275.0), (287.0, 289.4), (292.6, 295.0), (310.4, 316.0), (330.8, 334.8),
           (361.6, 363.2), (372.8, 375.0), (381.2, 384.6)]

# The simulator's recording has a frame only when the screen changes, so a scene that
# opens on a still page would have no frame at its start: each scene is read from
# LEAD seconds earlier, and the fps filter repeats the last frame through the gap.
LEAD = 20.0


def seek(start: float, end: float) -> tuple[list[str], str]:
    """The input options and the filter prefix that give exactly start..end, filled."""
    lead = min(LEAD, start)
    return (["-ss", f"{start - lead:.3f}", "-t", f"{end - start + lead:.3f}"],
            f"fps={FPS},tpad=stop_mode=clone:stop_duration=5,trim=start={lead:.3f}:duration={end - start:.3f},setpts=PTS-STARTPTS")


def ffmpeg() -> str:
    try:
        import imageio_ffmpeg

        return imageio_ffmpeg.get_ffmpeg_exe()
    except ImportError:
        return shutil.which("ffmpeg") or "ffmpeg"


def run(*args: str) -> None:
    subprocess.run([ffmpeg(), "-hide_banner", "-loglevel", "error", "-y", *args], check=True)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def ground(w: int, h: int) -> Image.Image:
    image = Image.new("RGB", (w, h))
    draw = ImageDraw.Draw(image)
    for y in range(h):
        t = min(1.0, y / (h * 0.6))
        draw.line([(0, y), (w, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM)))
    return image


def centred(draw: ImageDraw.ImageDraw, y: float, text: str, face: ImageFont.FreeTypeFont, fill, w: int) -> None:
    draw.text(((w - draw.textlength(text, font=face)) / 2, y), text, font=face, fill=fill)


# The social promo's layout: 1080x1920, the screen 1380 high from y = 470.
PW, PH = 1080, 1920
SCREEN_H = 1380
SCREEN_W = round(SCREEN_H * 1320 / 2868) // 2 * 2
SCREEN_X, SCREEN_Y = (PW - SCREEN_W) // 2, 470
RADIUS = round(150 * SCREEN_H / 2868)


def scene_background(caption: str, subline: str) -> Image.Image:
    canvas = ground(PW, PH)
    draw = ImageDraw.Draw(canvas)
    centred(draw, 150, caption, font("GentiumBookPlus-Bold.ttf", 96), INK, PW)
    draw.line([(PW / 2 - 60, 285), (PW / 2 + 60, 285)], fill=GOLD, width=4)
    centred(draw, 315, subline, font("SourceSans3-Regular.ttf", 44), RUBRIC, PW)
    x, y, w, h = SCREEN_X, SCREEN_Y, SCREEN_W, SCREEN_H
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle([x - 6, y - 6, x + w + 6, y + h + 6], RADIUS + 6, fill=GOLD + (110,))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(36)))
    ImageDraw.Draw(canvas).rounded_rectangle([x - 4, y - 4, x + w + 3, y + h + 3], RADIUS + 4, fill=GOLD + (255,))
    return canvas.convert("RGB")


def screen_mask() -> Image.Image:
    mask = Image.new("L", (SCREEN_W, SCREEN_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SCREEN_W - 1, SCREEN_H - 1], RADIUS, fill=255)
    return mask


def card(lines: list[tuple[str, str, int, tuple]], icon: Path | None) -> Image.Image:
    canvas = ground(PW, PH)
    draw = ImageDraw.Draw(canvas)
    y = 560
    if icon:
        art = Image.open(icon).convert("RGB").resize((300, 300), Image.LANCZOS)
        mask = Image.new("L", art.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle([0, 0, 299, 299], 68, fill=255)
        canvas.paste(art, ((PW - 300) // 2, y), mask)
        y += 380
    for text, face, size, fill in lines:
        if text == "-":
            draw.line([(PW / 2 - 60, y + 10), (PW / 2 + 60, y + 10)], fill=GOLD, width=4)
            y += 50
            continue
        centred(draw, y, text, font(face, size), fill, PW)
        y += round(size * 1.3)
    return canvas


def xfade_chain(clips: list[Path], durations: list[float], out: Path, extra: list[str]) -> None:
    """Joins the clips with FADE-second cross-fades and adds a silent stereo track."""
    inputs: list[str] = []
    for clip in clips:
        inputs += ["-i", str(clip)]
    filters, last, offset = [], "0:v", 0.0
    for index in range(1, len(clips)):
        offset += durations[index - 1] - FADE
        label = f"v{index}"
        filters.append(f"[{last}][{index}:v]xfade=transition=fade:duration={FADE}:offset={offset:.3f}[{label}]")
        last = label
    total = sum(durations) - FADE * (len(clips) - 1)
    run(
        *inputs, "-f", "lavfi", "-t", f"{total:.3f}", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
        "-filter_complex", ";".join(filters) if filters else "[0:v]null[v0]", "-map", f"[{last if filters else 'v0'}]",
        "-map", f"{len(clips)}:a", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-profile:v", "high", "-r", str(FPS),
        "-b:v", "10M", "-c:a", "aac", "-b:a", "256k", "-shortest", "-movflags", "+faststart", *extra, str(out),
    )
    print(out, f"{total:.1f} s")


def main() -> None:
    recording, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(dir=out))

    # The App Store preview: the scenes alone, 886x1920.
    clips, durations = [], []
    for index, (start, end) in enumerate(PREVIEW):
        clip = work / f"preview-{index}.mp4"
        options, fill = seek(start, end)
        run(*options, "-i", str(recording), "-an", "-vf",
            f"{fill},scale=886:-2:flags=lanczos,crop=886:1920:0:(ih-1920)/2,setsar=1",
            "-c:v", "libx264", "-crf", "12", "-pix_fmt", "yuv420p", str(clip))
        clips.append(clip)
        durations.append(end - start)
    xfade_chain(clips, durations, out / "app-preview.mp4", [])

    # The social promo: a title card, the scenes framed under captions, a closing card.
    mask = work / "mask.png"
    screen_mask().save(mask)
    icon = ROOT / "App/Breviarium/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
    title = work / "title.png"
    card([("Breviarium", "GentiumBookPlus-Bold.ttf", 120, INK), ("-", "", 0, GOLD),
          ("The traditional Divine Office", "SourceSans3-Regular.ttf", 52, RUBRIC)], icon).convert("RGB").save(title)
    closing = work / "closing.png"
    card([("Breviarium", "GentiumBookPlus-Bold.ttf", 120, INK), ("-", "", 0, GOLD),
          ("Roman, Dominican and Ambrosian", "SourceSans3-Regular.ttf", 48, RUBRIC),
          ("Fully offline. No account, no tracking.", "SourceSans3-Regular.ttf", 48, RUBRIC)], icon).convert("RGB").save(closing)

    clips, durations = [], []
    for name, still, seconds in [("title", title, 3.0)]:
        clip = work / f"{name}.mp4"
        run("-loop", "1", "-t", f"{seconds}", "-i", str(still), "-vf", f"fps={FPS},format=yuv420p",
            "-c:v", "libx264", "-crf", "12", str(clip))
        clips.append(clip)
        durations.append(seconds)
    for index, (start, end, caption, subline) in enumerate(SCENES):
        background = work / f"ground-{index}.png"
        scene_background(caption, subline).save(background)
        clip = work / f"scene-{index}.mp4"
        length = f"{end - start:.3f}"
        run("-loop", "1", "-t", length, "-i", str(background), *seek(start, end)[0], "-i", str(recording),
            "-loop", "1", "-t", length, "-i", str(mask), "-filter_complex",
            f"[1:v]{seek(start, end)[1]},scale={SCREEN_W}:{SCREEN_H}:flags=lanczos,format=rgba[s];"
            f"[2:v]format=gray,scale={SCREEN_W}:{SCREEN_H}[m];[s][m]alphamerge[r];"
            f"[0:v][r]overlay={SCREEN_X}:{SCREEN_Y}:shortest=1,fps={FPS},format=yuv420p",
            "-an", "-c:v", "libx264", "-crf", "12", str(clip))
        clips.append(clip)
        durations.append(end - start)
    clip = work / "closing.mp4"
    run("-loop", "1", "-t", "3.5", "-i", str(closing), "-vf", f"fps={FPS},format=yuv420p",
        "-c:v", "libx264", "-crf", "12", str(clip))
    clips.append(clip)
    durations.append(3.5)
    xfade_chain(clips, durations, out / "promo.mp4", [])

    shutil.rmtree(work)


if __name__ == "__main__":
    main()
