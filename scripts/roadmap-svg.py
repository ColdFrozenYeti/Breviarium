# Draws docs/images/roadmap.svg, the README roadmap, in the app's night-mode palette.
# Build tooling only (nothing here ships in the app). Edit `rows` when a beta moves on,
# then run: python3 scripts/roadmap-svg.py

from xml.sax.saxutils import escape as e
W = 880
ROW = 66
TOP = 96
rows = [
    ("done", "Alpha", "Released", "Roman Vespers under the 1960 rubrics, computed for any date"),
    ("done", "Beta 1", "Released", "The Vulgate psalter by default, and the parallel English"),
    ("done", "Beta 2", "Released", "The day hours, Lauds to Compline, and the hour picker"),
    ("next", "Beta 3", "Next", "Matins · the new app icon · the title block’s commemoration line"),
    ("plan", "Beta 4", "Planned", "Little Office of Our Lady (Roman) · Office of the Dead · the Martyrology"),
    ("plan", "Beta 5", "Planned", "The Dominican rite (Ordo Prædicatorum, 1962)"),
    ("wait", "Beta 6", "Needs a source", "The Ambrosian rite, from a text source still to be chosen"),
    ("plan", "Beta 7", "Planned", "Little Office of Our Lady (Ambrosian)"),
    ("goal", "1.0", "Goal", "Phone checks, landscape and the largest text size, then a freeze"),
    ("later", "After 1.0", "Possible", "The Monastic office (1963), and votive offices"),
]
H = TOP + ROW * len(rows) + 28
BG, WHITE, RUBRIC, ICON, CHROME, DIM = "#000000", "#FFFFFF", "#FF8080", "#FF4D33", "#B2B2B2", "#5C5C5C"
X = 64  # timeline x
serif = "'Hoefler Text', 'Iowan Old Style', Georgia, 'Times New Roman', serif"
sans = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
out = []
a = out.append
a(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-labelledby="t d">')
a('<title id="t">Breviarium roadmap</title>')
a('<desc id="d">Alpha, Beta 1 and Beta 2 are released. Next: Beta 3, Matins and the new icon. Then Beta 4, the Little Office of Our Lady, the Office of the Dead and the Martyrology; Beta 5, the Dominican rite; Beta 6, the Ambrosian rite, which needs a source; Beta 7, the Ambrosian Little Office; then 1.0. The Monastic office is possible after 1.0.</desc>')
a(f'<rect width="{W}" height="{H}" rx="18" fill="{BG}"/>')
a(f'<text x="{X-24}" y="52" font-family="{serif}" font-size="30" font-weight="700" fill="{WHITE}" letter-spacing="1.5">ROADMAP</text>')
a(f'<text x="{W-40}" y="52" text-anchor="end" font-family="{sans}" font-size="15" font-style="italic" fill="{RUBRIC}">Alpha to 1.0</text>')
a(f'<line x1="{X-24}" y1="68" x2="{X+59}" y2="68" stroke="{WHITE}" stroke-width="1"/>')
ys = [TOP + ROW * i + 22 for i in range(len(rows))]
# connecting line: solid through the released ones, dashed after
last_done = max(i for i, r in enumerate(rows) if r[0] == "done")
a(f'<line x1="{X}" y1="{ys[0]}" x2="{X}" y2="{ys[last_done+1]}" stroke="{ICON}" stroke-width="2"/>')
a(f'<line x1="{X}" y1="{ys[last_done+1]}" x2="{X}" y2="{ys[-2]}" stroke="{DIM}" stroke-width="2" stroke-dasharray="4 5"/>')
a(f'<line x1="{X}" y1="{ys[-2]}" x2="{X}" y2="{ys[-1]}" stroke="{DIM}" stroke-width="1.5" stroke-dasharray="1 5" stroke-linecap="round"/>')
for (kind, name, status, detail), y in zip(rows, ys):
    if kind == "done":
        a(f'<circle cx="{X}" cy="{y}" r="11" fill="{ICON}"/>')
        a(f'<path d="M{X-5} {y} l3.5 3.8 l6.5 -7.6" fill="none" stroke="{BG}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
        sc = CHROME
    elif kind == "next":
        a(f'<circle cx="{X}" cy="{y}" r="11" fill="{BG}" stroke="{ICON}" stroke-width="2.5"/>')
        a(f'<circle cx="{X}" cy="{y}" r="4.5" fill="{ICON}"/>')
        sc = ICON
    elif kind == "goal":
        a(f'<rect x="{X-10}" y="{y-10}" width="20" height="20" transform="rotate(45 {X} {y})" fill="{BG}" stroke="{WHITE}" stroke-width="2"/>')
        sc = WHITE
    elif kind == "wait":
        a(f'<circle cx="{X}" cy="{y}" r="10" fill="{BG}" stroke="{RUBRIC}" stroke-width="2" stroke-dasharray="3 3"/>')
        sc = RUBRIC
    elif kind == "later":
        a(f'<circle cx="{X}" cy="{y}" r="7" fill="{BG}" stroke="{DIM}" stroke-width="1.5" stroke-dasharray="2 3"/>')
        sc = CHROME
    else:
        a(f'<circle cx="{X}" cy="{y}" r="10" fill="{BG}" stroke="{CHROME}" stroke-width="2"/>')
        sc = CHROME
    name_fill = CHROME if kind in ("done", "later") else WHITE
    a(f'<text x="{X+32}" y="{y+2}" font-family="{serif}" font-size="21" font-weight="700" fill="{name_fill}">{e(name)}</text>')
    a(f'<text x="{W-40}" y="{y+1}" text-anchor="end" font-family="{sans}" font-size="12.5" font-weight="600" letter-spacing="1.2" fill="{sc}">{e(status.upper())}</text>')
    style = ' font-style="italic"' if kind == "later" else ""
    a(f'<text x="{X+32}" y="{y+25}" font-family="{sans}" font-size="15" fill="{CHROME}"{style}>{e(detail)}</text>')
a('</svg>')
open(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', 'docs', 'images', 'roadmap.svg'), 'w').write("\n".join(out) + "\n")
