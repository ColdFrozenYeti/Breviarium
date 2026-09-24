# Breviarium — Beta 2 Implementation Plan

## Context

Beta 1 delivered **Roman Vespers, 1960 rubrics**, in either psalter (Vulgate by default,
Pius XII as an option) and with the parallel English. It is verified against Divinum
Officium (DO) on every evening from 2025 to 2040 and on all of 2044, in both directions
([`PLAN.md`](PLAN.md), [`beta-1-retrospective.md`](beta-1-retrospective.md)).

| Beta | Scope |
|---|---|
| 1 (done) | Vulgate psalter by default, and the English translation |
| **2 (this plan)** | **All the day hours: a *diurnale*, not just a *vespertinum*** |
| 3 | The Ambrosian and Dominican rites |
| 4 | Matins |

Beta 2 adds the six other day hours:
- *Ad Laudes*;
- *Ad Primam*;
- *Ad Tertiam*, *Ad Sextam* and *Ad Nonam* (the little hours);
- *Ad Completorium*.

Each comes in both psalters, with English, and with the same book-style reader. Matins
stays for Beta 4. Everything else carries over: fully offline, no Mac, sideloading, and
the non-negotiables in `CLAUDE.md`.

**What DO gives us.** Each hour has its own skeleton in
`web/www/horas/Ordinarium/`, built the same way as Vespers:
- `Laudes.txt`;
- `Prima.txt`;
- `Minor.txt`, one file shared by Terce, Sext and None;
- `Completorium.txt`.

Their `#Section` groups are filled by the same `specials.pl` routines the engine
already ports for Vespers:
- `psalmi.pl`: `psalmi_major` for Lauds, `psalmi_minor` for the little hours and Prime;
- `capitulis.pl`: `capitulum_minor`, `minor_reponsory`;
- `hymni.pl`, `orationes.pl`, `preces.pl`;
- `specprima.pl`: Prime's *lectio brevis*.

So most of Beta 2 extends mechanisms that already exist and are already audited, rather
than building new ones.

**What is new, by hour:**
- **Lauds**, the largest part:
  - the Benedictus;
  - Lauds I and Lauds II (the penitential psalter on some ferias);
  - the Sunday and feast psalms;
  - commemorations at Lauds, including the *Commemoratio ad Laudes tantum* that
    `CLAUDE.md`'s title-block example shows for 16 September 2026;
  - the *preces feriales*;
  - DO's suffrage logic, which the 1960 rubrics mostly switch off (`checksuffragium`,
    `specials.pl:699`).
- **Prime:**
  - its own psalm scheme;
  - the *Pretiosa* section;
  - the *lectio brevis*;
  - the Sunday and ferial preces;
  - the Martyrology, which `CLAUDE.md` lists as a later on/off setting (see open
    questions).
- **Terce, Sext and None:**
  - antiphons taken from Lauds;
  - the chapter with its short responsory;
  - the psalms of the day.
- **Compline:**
  - the fixed opening (*Jube, domne*, the short lesson, the *Confiteor*);
  - the Nunc dimittis;
  - the seasonal Marian antiphon (*Antiphona finalis*);
  - the same "which day is this" question as Vespers.

**The app side.** `design/reference/Hours Picker.png` shows Universalis's hour list.
Beta 2 needs one reduced to our hours. Mass, readings, the Angelus and the Rosary are
excluded by `CLAUDE.md`.

## How Claude works on this beta

Beta 1's rules still apply unchanged ([`Beta_1_plan.md`](Beta_1_plan.md), "How Claude
works on this beta"): read first, never guess a rubric, oracle discipline, measure before
and after, check both directions, and hold milestone gates. The Beta 1 retrospective
adds these:

1. **Don't cancel a CI run you need.** Batch pushes. A pull request's path filter covers
   the whole PR, so even a docs-only push restarts every workflow.
2. **Check a long local run right after starting it,** and never truncate the lines that
   carry its verdict.
3. **Every audit gets a J→I and mixed-language tolerance from the start,** matching the
   content audit, so audit gaps don't look like engine bugs.
4. **UI tests reset their state at launch** (orientation, settings) and capture landscape
   from the app window.

## Architecture changes

- **One assembler per hour, behind the rite interface.**
  - `HourAssembler.assembleVespers` becomes one case of
    `assemble(_ hour: CanonicalHour, …)`, with `CanonicalHour` being `.laudes`,
    `.prima`, `.tertia`, `.sexta`, `.nona`, `.vesperae` or `.completorium`.
  - The shared parts are skeleton parsing, macros, the Oratio preamble, the English
    layer and the alleluia rules. They move into helpers used by every hour.
  - Vespers keeps its exact behaviour, and its audits must stay at zero through the
    refactor.
- **Which day an hour belongs to.**
  - Lauds to None follow the day's own occurrence.
  - Vespers and Compline follow `Concurrence`: Compline belongs to the office whose
    Vespers was said that evening, as in DO.
  - `LiturgicalCalendarEngine.vespersDay` generalises to `day(for: CanonicalHour)`, so
    each hour's title block matches DO's.
- **`Section.Kind` grows** for the new sections:
  - *Benedictus*, *Nunc dimittis*;
  - *Responsorium breve*, *Lectio brevis*;
  - Prime's *Martyrologium* slot (not shown in Beta 2);
  - *Antiphona finalis* and the Compline opening.

  The heading set and its mapping to DO's sections are proposed in B2-M1 for approval,
  as `CLAUDE.md` requires.
- **The data bundle** already carries every file these hours use; B2-M1 confirms this.

## Oracle fixtures

A new set per hour, rendered from the pinned DO commit with
`scripts/generate-fixture-set.sh`. It gains an hour parameter:
`oracle-worker.sh` currently hard-codes `command=prayVespera`, and the other hours use
`prayLaudes`, `prayPrima`, `prayTertia`, `praySexta`, `prayNona` and `prayCompletorium`.

| Set | Range | Options |
|---|---|---|
| `hours/<hour>/` | 2025–2040 | Vulgate Latin + English (bilingual rows), priest off |
| `hours-bea/<hour>/` | 2025–2040 | Pius XII Latin only, priest off (psalmody regression) |
| `holdout/2044-<hour>` | 2044 | Vulgate + English, priest on and off |

The bilingual set's Latin column is the Vulgate Latin, so one set serves the Latin audits
and the English audits together, as in Beta 1.

**Size.** The Vespers bilingual set is 23 MB for 16 years. The little hours are much
shorter than Vespers, and Lauds is about the same length. The estimate for all six hours
is 80–110 MB with Bea included, or 60–80 MB without. B2-M2 measures it (open question 4).

**CI time.** Oracle audits takes about 20 minutes for Vespers. The new audits run as a
matrix, one job per hour in parallel, so wall-clock time stays about the same.

## Milestones

### B2-M0 — Housekeeping (small)

- Restart the branch from `main` (done).
- **Baseline:** fast suite 346 tests, and every full-range audit at 0.
- **Beta 1 carry-overs that don't depend on the new hours:**
  - XXL hyphenation of "sæculórum": a small Latin hyphenation exception list for the
    two-column layout;
  - an audit of the rank line (*III. classis*) against DO's title.
- `CLAUDE.md`: record the scope change ("The alpha is Roman Vespers only" becomes the
  diurnale in Beta 2) and the hour-picker entry. These edits are listed for approval
  before they are made.

### B2-M1 — Understand the day hours (document, no code)

A new document, `docs/rubrics-1960-day-hours.md`, cited to the pinned DO commit. It
covers:
- each hour's skeleton and the `specials.pl` routine behind every `#Section`;
- Lauds:
  - Lauds I versus II;
  - Sunday and feast psalms;
  - Benedictus antiphons;
  - commemorations at Lauds versus Vespers;
  - the preces;
  - the suffrage, and why 1960 omits it;
- the little hours:
  - antiphons taken from Lauds;
  - the psalm distribution;
  - the chapter and short responsory;
  - the seasonal variants (Paschaltide, Passiontide, the Triduum);
- Prime:
  - the *Pretiosa*;
  - the *lectio brevis*;
  - the preces;
  - where DO puts the Martyrology;
- Compline:
  - the fixed parts;
  - the Triduum and Easter Octave forms;
  - the Marian antiphons and when each is sung;
  - which day Compline belongs to;
- the proposed section headings for each hour, and how they map to DO's sections.

**Exit:** your approval of the document.

### B2-M2 — Fixtures

- Add the hour parameter to the worker and fixture scripts. Render the sets above and
  record their sizes and hashes in `data/SOURCE.md`.
- Extend `OracleFixture` to read per-hour sets.
- A new workflow matrix runs the per-hour audits. They start *expected-failing* (no
  engine yet), and reporting stays advisory until each hour's milestone turns it on.

### B2-M3 — Compline and the little hours in the engine

These go first because they are the closest to Vespers: fixed or simple structure, the
same psalm machinery, and Compline shares Vespers' concurrence.
- The refactor to `assemble(_ hour:)`, with the Vespers audits held at zero throughout.
- **Compline:**
  - its opening;
  - the psalms, which change by day of the week under 1960;
  - the hymn;
  - the chapter and short responsory;
  - the Nunc dimittis with its antiphon;
  - the preces;
  - the collect *Visita*;
  - the Marian antiphon.
- **Terce, Sext and None:**
  - the hymn;
  - the psalms;
  - the antiphon taken from Lauds;
  - the chapter and short responsory;
  - the collect of the day.
- Audits: content, coverage, psalmody, English and title, both directions, full range,
  plus the 2044 hold-out.

**Exit:** every audit at 0 for these four hours, in both psalters.

### B2-M4 — Prime and Lauds in the engine

- **Prime:**
  - its psalms, which differ on Sundays and feasts;
  - the *Pretiosa* block;
  - the *lectio brevis* by season;
  - the preces;
  - the Martyrology left out (see open question 2).
- **Lauds:**
  - psalms I and II;
  - antiphons;
  - chapter, hymn and versicle;
  - the Benedictus;
  - the preces;
  - commemorations, including those at Lauds only.
- **The title block's commemoration line** (Beta 1 carry-over). Lauds is where the
  commemoration line has to be built, so it is filled here and audited against DO's
  title for every hour, e.g. *Commemoratio ad Laudes tantum: Ss. Euphemiæ, Luciæ et
  Geminiani Martyrum* on 16 September 2026.
- Named tests: `CLAUDE.md`'s edge-case list, per hour where it applies. This covers:
  - the Triduum, where the little hours and Compline take special forms;
  - Christmas and the Epiphany;
  - Ember days;
  - All Souls;
  - Our Lady on Saturday.

**Exit:** every audit at 0 for all seven hours.

### B2-M5 — The hours in the app

- **Hour picker**, modelled on `Hours Picker.png` and reduced to our seven hours:
  - rows *Ad Laudes*, *Ad Primam*, *Ad Tertiam*, *Ad Sextam*, *Ad Nonam*, *Ad Vesperas*,
    *Ad Completorium*;
  - separator rules and a check mark on the current hour.
  - It opens from the navigation title, which becomes a button.
- **Which hour opens at launch** (open question 1).
- **Next and previous hour:** a swipe past the last page moves to the next hour, as in
  Universalis. This is optional; see open question 5.
- Every hour uses the existing readers: English on and off, both psalters, slide, curl
  and vertical.
- Snapshot matrix per hour for two dates (a ferial day and a I class feast), page 1 and
  a middle page. Plus Compline on Holy Saturday and Lauds on 16 September 2026, the
  title-block example.

**Exit:** CI green, snapshots checked and shown to you, your approval.

### B2-M6 — Release

- `docs/install-on-iphone.md`: add each hour to the on-device checklist, plus the hour
  picker.
- Build IPA, and you install it on the phone.
- `docs/beta-2-retrospective.md`.

## Open questions (for your answer before B2-M1 ends)

1. **Which hour opens at launch?**
   - (a) The hour for the time of day, which is what Universalis does. My suggestion:
     Lauds until 9:00, Terce until 12:00, Sext until 15:00, None until 17:00, Vespers
     until 20:00, Compline after that, with Prime folded into the morning slot.
   - (b) The last hour you had open.
   - (c) Always Vespers.

   I recommend (a), with the boundaries in Settings later if you want them.
2. **The Martyrology at Prime.** `CLAUDE.md` lists it as a later on/off setting. Keep it
   out of Beta 2 and leave the section empty? I recommend yes. It needs its own data
   (the 1960 Martyrology texts and the moveable-feast rules) and is a milestone of its
   own.
3. **Compline's date.** Selecting a date and opening Compline would give the Compline
   prayed that night, after that day's Vespers, as DO does. Is that the behaviour you
   want?
4. **Fixture scope.** Should the Pius XII set be kept for all six hours (+~25 MB), or
   only Lauds and Compline, where Pius XII has its own psalm texts that differ most?
   The little hours' psalms (118 and the gradual psalms) are the same mechanism either
   way. I recommend keeping it for all six hours, since the size is acceptable for a
   private repository.
5. **Moving between hours:** only through the picker, or also by swiping past the last
   page, as in Universalis? The swipe is easy in the horizontal reader, but it changes
   what "last page" means for the page counter.
