# Breviarium — Beta 4 Implementation Plan

## Context

Beta 3 completed the Roman office of the day, Matins to Compline, and was published on
26 September 2026. Beta 4 adds the three offices that sit beside it, and two small items
the user asked for:

1. **The Little Office of Our Lady** (*Officium parvum Beatæ Mariæ Virginis*), all eight
   hours.
2. **The Office of the Dead** (*Officium defunctorum*): Matins, Lauds and Vespers.
3. **The Martyrology** (*Martyrologium Romanum*), as an "hour" of its own in the picker
   (decided 2026-09-24).
4. **The liturgical colour dot**: each day in the *Jump to date* calendar gets a small
   dot of its liturgical colour (added 2026-09-26).
5. **Inline rubrics**: *(Fit reverentia)* in the *Te Deum* shows as a red rubric, hidden
   with rubrics off (asked 2026-09-26), and so do the other directions DO sets in small
   print inside a text (see question 5).

`CLAUDE.md` was refreshed for Beta 3 at the start of this plan.

## What Divinum Officium does (read at the pinned commit)

**The Little Office and the Office of the Dead are DO "votives".**
- `officium.pl` takes `votive=C12` (the Little Office) or `votive=C9` (the Dead). The
  winner becomes `Commune/C12` or `Commune/C9`, and the day's own office is not shown.
- The Little Office has seasonal forms (`horascommon.pl:1770-1785`): `C12N` from
  Christmas Eve's Vespers to 2 February, `C12A` in Advent and on the Annunciation, `C12Q`
  from Septuagesima to Easter, and `C12` for the rest of the year. `C12` itself is `ex C11` with the rules *Ave only*,
  *Votive nocturn* (one nocturn of three psalms by weekday), *Special Benedictio* and,
  after Septuagesima, *no Te Deum*.
- The Office of the Dead has only Matins, Lauds and Vespers (`gethoras`, `@horas[0, 1, 6]`),
  with the rules *Omit Incipit Hymnus Capitulum …*, *Special Conclusio*, *Requiem
  gloria*, *Votive nocturn* and *9 lectiones*.
- Our engine already meets both: `Commune/C9` wins on All Souls, and the Matins port has
  the `C9`/`C12` branches of `lectio`, `get_absolutio_et_benedictiones` and
  `contract_scripture`. Beta 4 makes them reachable on any date.
- English: DO has `Commune/C9`, `C12` and `C12A` in English. `C12N` and `C12Q` inherit
  `C12` (`@Commune/C12`), English included.

**The Martyrology is part of Prime in DO** (`specprima.pl:139-200`, `martyrologium`):
- It reads the **next day's** entry from `Martyrologium1960/MM-DD.txt` (it is read at
  Prime the day before), adds the moon's age (`_luna`, from the golden number), a movable
  entry from `Mobile.txt` (e.g. Easter Sunday's), and the closing *Pretiosa* prayer
  (`Conclmart`).
- Our Prime fixtures for 2025–2040 already contain it: `withoutMartyrology` strips it from
  the Prime audit today. So the Martyrology already has a 16-year oracle.
- English: DO has no 1960 English Martyrology. It falls back to the older `Martyrologium`
  English, whose entries don't always match the 1960 Latin (see question 3).

**The liturgical colour** is DO's `liturgical_color()` on the day's title; our
`LiturgicalColorClassifier` is its port (Alpha). The fixtures strip HTML, so the colour
isn't in them; it will be checked with unit tests and against DO's raw page for a sample
of dates.

**(Fit reverentia)** is `/:(Fit reverentia):/` in `Psalterium/Common/Prayers.txt` (the
*Te Deum*), `/: :/` being DO's small-print mark. We drop the marks and keep the words as
ordinary text today. The Benedicite has *(Fit reverentia:)* in its own text
(`Psalm210.txt`), and the invitatory has *(genuflectitur)*.

## Architecture changes

- **An office choice beside the hour** (a setting, decision 1). `HourAssembler.assemble`
  gains an `officium: .diei | .parvumBMV | .defunctorum` parameter. For the two votives the winner is
  the votive Commune, as DO sets it, and everything else (conditionals, psalter, English)
  is unchanged. The Kit decides which hours each office has.
- **The Martyrology** is its own assembler in the Kit (`Martyrology.swift`): the next day's
  entry, the moon's age, the movable entry, and the conclusion, returned as an `Hour` with
  one section so the app's readers show it like any hour.
- **Inline rubrics**: a new text span type, not a new unit. A `Unit`'s text can carry
  `‹rubric›` spans that the typesetter draws in rubric red and drops with rubrics off.
  The same mechanism later serves the Dominican rite.
- **The colour**: `LiturgicalDay.color` already exists. The *Jump to date* sheet reads it
  per day through a small Kit function, cached per month so the calendar stays quick.
- **The rite abstraction** is not touched yet; Beta 5 (Dominican) is the first to need it.

## Oracle fixtures

- **The Little Office**: every hour, every day of 2026 and 2027, `votive=C12`, Vulgate
  Latin + English, priest off, plus the Pius XII psalter (flat). Two years cover every
  season and weekday; its text doesn't change otherwise. About 6,000 renders.
- **The Office of the Dead**: Matins, Lauds and Vespers, every day of 2026, both
  psalters, plus priest on for a week (its *Dominus vobiscum* forms). About 1,100 renders.
- **Hold-out**: 2044 for both votives, priest off and on.
- **The Martyrology**: no new renders; the Prime fixtures 2025–2040 and the 2044 hold-out.
- `scripts/generate-fixture-set.sh` gains a votive argument; sizes and hashes go in
  `data/SOURCE.md` as before.

## Milestones

### B4-M0 — Housekeeping (small)
- `CLAUDE.md` refreshed for Beta 3 (done with this plan).
- Baseline: the fast suite and every Oracle audit job green on `main`.
- *(Fit reverentia)* and the other inline directions as red rubrics (decision 5), with a
  snapshot of the *Te Deum*.

### B4-M1 — Understand the three offices (document, no code)
`docs/rubrics-1960-votives.md`: how DO builds the Little Office and the Office of the Dead
at each hour, and the Martyrology, cited to the pinned commit, with the headings proposed
for each (e.g. the Martyrology's date line, entries and *Pretiosa*).

### B4-M2 — Fixtures
The sets above, and `OracleFixture` reading them.

### B4-M3 — The two votive offices in the engine
- The Little Office, hour by hour, audited on 2026–2027 and the hold-out, in both psalters
  and English.
- The Office of the Dead, the same.
- Named edge cases: the Little Office in Advent, at Christmas, after the Purification,
  in Lent (*no Te Deum*) and at Easter; the Office of the Dead with the priest on and off;
  and the Dead on All Souls, which must equal the day's own office.

### B4-M4 — The Martyrology and the colour in the engine
- `Martyrology.swift`, audited against the Martyrology in every Prime fixture 2025–2040 and
  2044, in Latin (decision 3).
- The day's colour for the calendar, with unit tests and a check against DO's raw HTML
  for a sample of dates across every colour.

### B4-M5 — The app
- *Officium* in Settings under *Ritus Romanus*; the picker lists the chosen office's hours
  and the Martyrology row (decision 1).
- The colour dot in *Jump to date* (decision 4).
- Snapshots: the picker; each Little Office hour's page 1; the Dead's Matins, Lauds and
  Vespers; the Martyrology for an ordinary day and Easter Sunday; the calendar in a month
  with every colour; the *Te Deum* with rubrics on and off.

### B4-M6 — Release
As Beta 3: release notes in the app and in `docs/releases/beta-4.md`, README and roadmap,
install checklist, retrospective, a PR and an IPA, merged and published after you've
tried it on the phone.

**Exit:** every Beta 3 audit still at zero, the new ones at zero, CI green.

## How Claude works on this beta

As in Beta 3: once this plan is approved, the milestones run without waiting at each gate,
stopping only for an unresolved rubric, a suspected DO error, or a capability a free Apple
ID can't sign. From the Beta 3 retrospective: commit and push after every green step, read
build errors before reading an audit report, and put any judgement call at the top of the
report for you to confirm.

## Decisions (answered 2026-09-26, plan approved)

1. **The office is a setting, under the rite.** Settings → *Ritus* → *Romanus* gives the
   choice of *Officium*: *Officium diei* (the default), *Officium parvum B.M.V.* and
   *Officium defunctorum*. The hour picker then lists that office's hours: all eight for
   the day's office and the Little Office, Matins, Lauds and Vespers for the Dead. The
   *Martyrologium* is its own row in the picker under every office.
2. **The Martyrology follows the traditional system**, as DO does: it is read at Prime on
   the eve, so a date shows the next day's entry, announced with that day's date and the
   moon's age.
3. **The Martyrology is Latin only**, with or without English on (DO has no 1960 English).
4. **The colour dot** takes the day's own office (the one Lauds shows): white as a white
   dot, black as a grey ring, and rose, violet, red and green in tones that read well on
   black.
5. **Every inline direction becomes a rubric**: *(Fit reverentia)* in the *Te Deum*, the
   Benedicite's *(Fit reverentia:)*, *(genuflectitur)* in the invitatory, and the other
   small-print `/: :/` directions inside a text: red, and hidden with rubrics off.
6. **No line under the title at Vespers and Compline**, as in Beta 3.

7. **A missing hour opens the previous one** (answered 2026-09-26). The clock picks the hour
   as for the day's office; if the chosen office hasn't it, the app opens the nearest
   earlier hour it has. For the Office of the Dead: Matins until 05:00, Lauds from 05:00
   to 20:00 (Terce, Sext and None fall back to Lauds), and Vespers from 17:00 on
   (Compline falls back to Vespers). The picker lists only the office's own hours, so
   the Dead shows Matins, Lauds and Vespers and no Terce.
