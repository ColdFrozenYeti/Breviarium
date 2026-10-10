#!/usr/bin/env python3
"""Glyph coverage of the bundled fonts (1.2, docs/1.2_plan.md section 2).

Collects every character in the texts the app is built from (Divinum Officium's Latin,
Latin-Bea and English trees, and the Ambrosian transcription) and checks it against each
bundled font's character map, in all four styles. Prints, per font, the characters it
lacks with how often each occurs and an example file; iOS draws those from another font.

Comic Neue has no ae-acute, so the typesetter writes it as ae + U+0301
(FontChoice.spelled); that spelling is applied before checking it.

Build tooling only (fontTools); nothing from it is linked into the app.

    python3 scripts/font-coverage.py            # report
    python3 scripts/font-coverage.py --strict   # exit 1 if a Latin character is missing
"""
import argparse
import collections
import pathlib
import sys
import unicodedata

from fontTools.ttLib import TTFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
DO = ROOT / "data/divinum-officium/web/www/horas"
SOURCES = {
    "Latin": [DO / "Latin", DO / "Latin-Bea", ROOT / "data/ambrosian"],
    "English": [DO / "English"],
}
FONTS = ROOT / "App/Breviarium/Fonts"
FAMILIES = {
    "IBM Plex Mono": "IBMPlexMono",
    "Comic Neue": "ComicNeue",
}
STYLES = ["Regular", "Italic", "Bold", "BoldItalic"]
# Characters the typesetter never draws as text: control and formatting characters.
IGNORED_CATEGORIES = {"Cc", "Cf", "Zl", "Zp"}


def spelled(family, text):
    if family == "Comic Neue":
        return text.replace("ǽ", "ǽ").replace("Ǽ", "Ǽ")
    return text


def collect(paths):
    counts = collections.Counter()
    example = {}
    for base in paths:
        if not base.exists():
            sys.exit(f"missing source tree: {base} (git submodule update --init?)")
        for path in sorted(base.rglob("*")):
            if not path.is_file() or path.suffix not in {".txt", ".json", ".md", ""}:
                continue
            try:
                text = path.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                continue
            # DO writes J where the app shows I (CLAUDE.md); J is in every font anyway.
            text = unicodedata.normalize("NFC", text)
            for ch in text:
                if unicodedata.category(ch) in IGNORED_CATEGORIES or ch in " \t":
                    continue
                counts[ch] += 1
                example.setdefault(ch, path.relative_to(ROOT))
    return counts, example


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    corpora = {lang: collect(paths) for lang, paths in SOURCES.items()}
    for lang, (counts, _) in corpora.items():
        print(f"{lang}: {len(counts)} distinct characters")
    print()

    failed = False
    for family, prefix in FAMILIES.items():
        cmaps = {style: set(TTFont(FONTS / f"{prefix}-{style}.ttf").getBestCmap()) for style in STYLES}
        print(f"== {family}")
        for lang, (counts, example) in corpora.items():
            missing = collections.defaultdict(list)
            for ch, n in counts.items():
                needed = spelled(family, ch)
                for style, cmap in cmaps.items():
                    if any(ord(c) not in cmap for c in needed):
                        missing[ch].append(style)
            if not missing:
                print(f"  {lang}: every character, in all four styles")
                continue
            print(f"  {lang}: {len(missing)} characters drawn from another font")
            for ch in sorted(missing, key=lambda c: -counts[c]):
                styles = missing[ch]
                which = "all styles" if len(styles) == len(STYLES) else ", ".join(styles)
                name = unicodedata.name(ch, f"U+{ord(ch):04X}")
                print(f"    U+{ord(ch):04X} {ch}  {name}: {counts[ch]}x ({which}), e.g. {example[ch]}")
                if lang == "Latin" and ch not in "✠✙":
                    failed = True
        print()
    if args.strict and failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
