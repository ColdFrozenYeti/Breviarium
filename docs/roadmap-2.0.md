# Roadmap to 2.0

Drafted on 10 October 2026, after 1.0, and settled the same day by the user's answers
(below); revised that evening, when 1.1 became the first bugfix release and 1.2 fonts and
themes. The earlier roadmap, [`roadmap.md`](roadmap.md), is complete. As before, each step
gets its own plan document and approval before any work starts, and nothing here goes
beyond the brief in `CLAUDE.md`.

![Roadmap](images/roadmap.svg)

## The order, and why

The same principle as for 1.0: what Divinum Officium (DO) contains can be checked against
it for every day from 2025 to 2040, so it comes first; what DO lacks waits on sources and
is checked against them page by page.

| Step | Contents | In DO? | Depends on |
|---|---|---|---|
| **1.1** | **The first bugfix release**: Ambrosian Compline as prayed (the prayers written out, the *Glória* as psalm verses, no rubric the app carries out, the Roman office's crosses on the texts the two share). | | Nothing |
| **1.2** | **Fonts and themes** (`1.2_plan.md`): a choice of typeface (Hoefler Text as now, a Renaissance serif, a sans serif, a typewriter, a readable comic face) and of colour theme (*Classic dark* as now, *Midnight blue*, *White*, *Sepia* and more), each from a gallery with a preview of the *Magnificat*. | | Free-licence fonts; the user's choice of themes |
| Alongside | **The release pass carried over from 1.0**: every hour of every office and rite checked on the phone; landscape verified; hyphenation at the largest text size. **The Ambrosian checks** (`ambrosian-compline-checks.md`): the user's corrections, then Church of Ambrose's review, and their written permission. | | The user's time on the phone; Church of Ambrose |
| When the user says | **The App Store release**: the paid Apple Developer Program, the texts' rights, the design's own identity (App Review guideline 4.1), the listing, and a signing step on top of CI's unsigned build (prerequisites in `CLAUDE.md`). No date or release number. | | The paid membership; the user's decisions on the design |
| **2.0 Beta 1** | **Votive offices** where the 1960 rubrics allow them, with the votive office picker `CLAUDE.md` already lists under *Later*. | Yes | Nothing |
| **2.0 Beta 2** | **The Ambrosian Office of the Dead** and **the Ambrosian Little Office**, each a standalone, precisely named office like *Completorium Ambrosianum*. | No | Their sources prepared: the Office of the Dead needs OCR of a combined Office and Mass book; the Little Office is LaTeX; edition, completeness and rights confirmed for each (`ambrosian-sources.md`) |
| **2.0 Beta 3** | **The full Ambrosian office** (the 1957 *Breviarium Ambrosianum*): every hour, with the calendar Beta 6 began. | No | Church of Ambrose's help (the user will ask them): a complete primary source, and its transcription, as for Compline. Until then this step waits, and 2.0 can ship without it |
| **2.0** | A release pass, then a freeze. | | Everything above |
| Maybe, later | **The Monastic office** (DO's *Monastic - 1963*). | Yes | Nothing; not planned |

- **1.1 and 1.2 first:** what the user found praying Ambrosian Compline, then the look of
  the page, before new offices; the phone checks go on alongside, as the App Store release
  needs a checked app.
- **Votive offices** are small and stay inside the Roman rite, which is fully checked.
- **The Ambrosian offices** can't be checked against DO. The Office of the Dead and the
  Little Office come first, as their sources exist; the full office follows with Church
  of Ambrose's help, building on Compline and the calendar already in the app.
- **The Monastic office** stays possible, but isn't planned.

## Decisions (10 October 2026)

1. ~~**The App Store release is 1.1**~~ Revised the same evening: 1.1 is the first bugfix
   release, 1.2 fonts and themes, and the App Store release comes when the user says so,
   with no date or number.
2. **The full Ambrosian office may come into the app**: it is a 2.0 step rather than
   "after 1.0, blocked", and it would come with Church of Ambrose's help, if the user can
   convince them.
3. **The Monastic office** goes to the *maybe, later* list.
4. **Votive offices** come first in 2.0 (not changed by the user).

## Open questions for later plans

- **The App Store release**: the design's own identity (name, icon, presentation; guideline
  4.1). The user decides before anything changes.
- **2.0 Beta 2**: who prepares the Office of the Dead's OCR and the Little Office's LaTeX,
  and the rights for each.
- **2.0 Beta 3**: whether Church of Ambrose will help, and with what: scans or a transcription of the four volumes, and permission to include them.
