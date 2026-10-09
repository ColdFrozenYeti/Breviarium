# Roadmap to 2.0

**Draft, 10 October 2026, for the user's approval.** 1.0 was released on 10 October 2026
(the earlier roadmap, [`roadmap.md`](roadmap.md), is complete). This one proposes the
order to 2.0. As before, each step gets its own plan document and approval before any work
starts, and nothing here goes beyond the brief in `CLAUDE.md`.

![Roadmap](images/roadmap.svg)

## The order, and why

The same principle as for 1.0: what Divinum Officium (DO) contains can be checked against
it for every day from 2025 to 2040, so it comes first; what DO lacks waits on sources and
is checked against them page by page.

| Step | Contents | In DO? | Depends on |
|---|---|---|---|
| **1.1** | **The release pass carried over from 1.0**: every hour of every office and rite checked on the phone; landscape verified; hyphenation at the largest text size. **The Ambrosian checks** (`ambrosian-compline-checks.md`): the user's corrections, then Church of Ambrose's review, and their written permission. | | The user's time on the phone; Church of Ambrose |
| **2.0 Beta 1** | **Votive offices** where the 1960 rubrics allow them, with the votive office picker `CLAUDE.md` already lists under *Later*. | Yes | Nothing |
| **2.0 Beta 2** | **The Monastic office**: DO's *Monastic - 1963*, its own psalter, calendar and Matins, as a third *Ritus* (or a fourth, after *Ambrosianus*). | Yes | The rite plug-in, proven twice |
| **2.0 Beta 3** | **The Ambrosian Office of the Dead** and **the Ambrosian Little Office**, each a standalone, precisely named office like *Completorium Ambrosianum*. | No | Their sources prepared: the Office of the Dead needs OCR of a combined Office and Mass book; the Little Office is LaTeX; edition, completeness and rights confirmed for each (`ambrosian-sources.md`) |
| **2.0** | A release pass like 1.1's, then a freeze. | | Everything above |
| Alongside | **The App Store release** (planned since 6 October 2026): the paid Apple Developer Program, the texts' rights, the design's own identity (App Review guideline 4.1), the listing, and a signing step on top of CI's unsigned build. Its prerequisites are in `CLAUDE.md`. It can happen at 1.1 or at 2.0. | | The paid membership; the user's decisions on the design |
| Blocked | **The full Ambrosian office** (the 1957 *Breviarium Ambrosianum*, four volumes). | No | A complete primary source, which isn't available digitally |

- **The release pass first (1.1):** 1.0 shipped before its planned phone checks; they come
  before new offices, so that what's built on is known to be right.
- **Votive offices before the Monastic office:** they are small and stay inside the Roman
  rite, which is fully checked.
- **The Monastic office** is the larger step: a new psalter distribution and calendar, but
  DO has it, so it can be checked like the Dominican office was.
- **The Ambrosian offices last:** they can't be checked against DO, and their sources
  aren't ready.

## Open questions for the user

1. **The order.** Votive offices, then the Monastic office, then the Ambrosian Office of the
   Dead and Little Office: is this right, or should one of them come first?
2. **The Monastic office**: is it wanted in 2.0, or after it? (The 1.0 roadmap listed it
   only as *possible*.)
3. **The App Store**: at 1.1, once the release pass is done, or at 2.0?
4. **Anything else** for 2.0 within the brief (for example the Monastic Little Office, or
   the Dominican votive offices)?
