# Breviarium — Beta 3 Implementation Plan

## Context

Beta 2 delivered the **Roman diurnal**: Lauds, Prime, Terce, Sext, None, Vespers and
Compline under the 1960 rubrics, in either psalter and with the English. It is verified
against Divinum Officium (DO) for every day from 2025 to 2040 and all of 2044
([`PLAN.md`](PLAN.md), [`beta-2-retrospective.md`](beta-2-retrospective.md)). The order to
1.0 is in [`roadmap.md`](roadmap.md).

| Beta | Scope |
|---|---|
| 2 (released) | The day hours |
| **3 (this plan)** | **Matins, the new icon, and the title block's commemoration line** |
| 4 | The Little Office of Our Lady, the Office of the Dead, the Martyrology |
| 5 | The Dominican rite |
| 6, 7 | The Ambrosian rite and its Little Office |

Beta 3 finishes the Roman office. *Ad Matutinum* joins the hour picker, in both psalters
and with English, in the same book-style reader. Everything else carries over: fully
offline, no Mac, sideloading, and the non-negotiables in `CLAUDE.md`.

**What DO gives us.** Matins has its own skeleton, `web/www/horas/Ordinarium/Matutinum.txt`:
*Incipit*, *Invitatorium*, *Hymnus*, *Psalmi cum lectionibus*, *Oratio*, *Conclusio*.
Its sections are filled by `web/cgi-bin/horas/specmatins.pl` (1,864 lines), which the
engine hasn't ported yet:
- `invitatorium`: Psalm 94 with its antiphon repeated and halved through the psalm;
- `hymnusmatutinum`: the hymn, with the seasonal rules;
- `psalmi_matutinum` and `nocturn`: the psalms by nocturn, with their antiphons and
  versicles;
- `lectiones`, `lectio`, `get_absolutio_et_benedictiones`: the lessons, with the
  absolution before each nocturn and the blessing before each lesson;
- `responsory_gloria`, `matins_lectio_responsory_alleluia`: the responsories after the
  lessons, with the *Gloria Patri* on the last of each nocturn;
- `gettype1960`: **the 1960 lesson types.** A day is `LT1960_FERIAL`, `SUNDAY`,
  `SANCTORAL`, `OCTAVEII` or `DEFAULT`, which decides one nocturn of three lessons or
  three nocturns of nine;
- `contract_scripture`: the 1960 rule that joins Scripture lessons into one;
- `tedeum_required`: when the *Te Deum* replaces the last responsory;
- `initiarule`, `resolveitable`, `tferifile`, `StJamesRule`, `prevdayl1`: which Scripture
  (*Scriptura occurrens*) is read, and when a displaced book's opening lessons move.

**What is new.** Most of Beta 2 extended mechanisms Vespers already had. Beta 3 is
mostly new mechanisms:
- the invitatory;
- the nocturn structure;
- the lessons, which are the first long prose the engine assembles from three sources
  (the day's Scripture, the saint's own lessons, and homilies on the Gospel);
- the responsories, the first unit with a repeated half;
- the 1960 rules that shorten Matins.

**The text is also much longer.** A nine-lesson Matins is several times the length of
Vespers. That matters for the fixtures (size), the reader (page count, TOC jumps) and the
English (long prose, stacked in portrait).

**Also in Beta 3:**
- **The new app icon.** The user's illuminated **B**, made to
  [`icon-spec.md`](icon-spec.md). It came through chat as a 1024 × 1024 WebP, opaque and
  lossy. It goes in as a PNG and is swapped for the lossless original when that arrives.
  Under an iOS-style mask the flourishes clear the corners, and it reads at 120 px.
- **The title block's commemoration line** (*Commemoratio ad Laudes tantum: …*), carried
  over from Beta 2.

## How Claude works on this beta

Beta 1's and Beta 2's rules still apply ([`Beta_2_plan.md`](Beta_2_plan.md), "How Claude
works on this beta"): read first, never guess a rubric, oracle discipline, measure before
and after, check both directions, and hold milestone gates. Beta 2's retrospective and its
phone test add these:

1. **Build first, then run the test binary directly** (`audit2.sh`), one process per hour
   group, and use `debugOneDayHour` for single dates.
2. **Paging bugs are checked on the pages themselves.** Every new layout gets UI tests
   that capture its awkward pages, where a heading or reference could be stranded or the
   end of the hour lost. Beta 2's cut-off ending was invisible to every test that only
   read the text.
3. **Batch App CI.** Each macOS run takes about 30 minutes. App CI runs by hand only when
   screenshots are needed, and the pull request's own run is the one that counts.

**Overnight mode (as for Beta 2).** Once this plan is approved, the milestones run
without waiting at each gate. The approval is the gate. The gates still get written up in
`PLAN.md` with their results, so the morning report can show them. Three things stop
the run and wait for you:
- a rubric the plan doesn't settle and DO's code doesn't answer;
- a suspected DO error, reported with the Codex Rubricarum evidence and never "fixed" in
  a fixture;
- anything that would need a capability a free Apple ID can't sign.

## Architecture changes

- **`CanonicalHour.matutinum`**, assembled by a new `assembleMatutinum` behind the same
  `assemble(_ hour:)` as the other hours. It uses the helpers they already share:
  skeleton, macros, the English layer and the alleluia rules.
- **New units in the text model,** proposed in B3-M1 with their typography:
  - **Lessons** (*Lectio i* … *ix*): prose with a heading, preceded by *Iube, domne,
    benedícere* and its blessing, and ending with *Tu autem, Dómine, miserére nobis* /
    *Deo grátias*.
  - **Responsories:** a respond, a verse, and the respond's second half repeated, which
    is marked with `*` in DO's text. The last responsory of each nocturn adds the
    *Gloria Patri* before the repeat.
  - **The invitatory:** Psalm 94 interleaved with its antiphon, whole and halved, as DO
    renders it.
- **Section headings** for Matins (e.g. INVITATORIUM, HYMNUS, NOCTURNUS I …, LECTIO I …,
  TE DEUM), and how they map to DO's sections, are proposed in B3-M1 for approval, as
  `CLAUDE.md` requires.
- **Which day Matins belongs to.** Matins follows the day's own occurrence, like Lauds.
  Christmas night and the Triduum (Tenebræ) are checked explicitly.
- **The data bundle** gains the files only Matins uses: the lessons, the responsories,
  the Scripture tables, and the Matins psalter. B3-M1 lists them. The bundle's size is
  measured before and after, and reported.
- **The commemoration line.** DO computes it in `occurrence()`
  (`horascommon.pl:538-830`, `$officename[2]`) over many branches: "Tempora:",
  "Scriptura ut in:", "Transfer:", and the Vespers forms. It becomes
  `DayTitle.commemorationLine`, which the app already displays when the engine supplies
  one.

## Oracle fixtures

New sets rendered from the pinned DO commit with `scripts/generate-fixture-set.sh`, whose
hour parameter gains `prayMatutinum`:

| Set | Range | Options |
|---|---|---|
| `hours/Matutinum/` | 2025–2040 | Vulgate Latin + English (bilingual rows), priest off |
| `hours-bea/Matutinum/` | 2025–2040 | Pius XII Latin only, priest off (psalmody regression) |
| `holdout/2044-Matutinum` | 2044 | Vulgate + English, priest on and off |

**Size.** The Vespers bilingual set is 23 MB for 16 years. Matins has three times the
lessons and far longer prose, so the estimate is **70–110 MB** for the bilingual set,
**30–45 MB** for Pius XII, and about **10 MB** for the 2044 hold-out. The fixtures are
212 MB today, so they would reach roughly 330–380 MB. That is fine for a private
repository, since each file is a per-year archive well under GitHub's 100 MB limit.
B3-M2 measures it (open question 3).

**Audits.** Oracle audits gains a `matutinum` job in its matrix. The existing audits
extend to Matins: content, coverage, psalmody, English, and title. So does
`dayHoursFullRangeHoldout2044`.

## Milestones

### B3-M0 — Housekeeping and the icon (small)

- **Baseline:** fast suite (348 tests), and every full-range audit at zero, on
  `main` at the Beta 2 merge.
- **The icon:**
  - `icon-1024.png` replaces the old one in `AppIcon.appiconset`, converted from the
    WebP and confirmed 1024 × 1024, 8-bit RGB, with no alpha channel;
  - a UI test captures the simulator's Home Screen, so the icon can be seen on a device
    frame;
  - the lossless original replaces it when you send it, with no other change.
- **Release notes:** the app's *Release notes* screen gains a "Beta 3" section, filled
  as the beta lands.

### B3-M1 — Understand Matins (document, no code)

A new document, `docs/rubrics-1960-matins.md`, cited to the pinned DO commit. It covers:
- the skeleton and the routine behind each section;
- **the 1960 lesson types** (`gettype1960`):
  - which days get one nocturn of three lessons and which get three nocturns of nine;
  - the Christmas octave (`OCTAVEII`);
  - the `9 lectiones 1960` rule;
- the invitatory: its antiphon and how it's split, and the days without one (the Triduum,
  Epiphany);
- the psalms by nocturn: ferial against festal distributions, with their antiphons and
  versicles, in both psalters;
- **the lessons:**
  - *Scriptura occurrens*, its tables, and when a displaced book's openings move
    (`initiarule`);
  - the saints' lessons, and the 1960 contraction into one third lesson
    (`contract_scripture`);
  - homilies;
  - the absolutions and blessings, and whether the priest toggle changes them;
- **the responsories:** where the *Gloria* goes, the Paschaltide alleluias, and when the
  *Te Deum* replaces the last one (`tedeum_required`);
- the special forms: Christmas, the Epiphany, the Triduum (Tenebræ), the Easter octave,
  Pentecost, and All Souls;
- **the proposed Matins section headings and typography** for lessons, responsories and
  the invitatory, consistent with `Format.png` and the day hours;
- the commemoration line: which of DO's `occurrence()` branches the 1960 Roman calendar
  reaches.

**Exit:** the document is committed (overnight mode, see above). Anything in it that
needs your decision goes into the morning report instead of stopping the run, unless it
blocks the engine work.

### B3-M2 — Fixtures

- `prayMatutinum` in the worker and fixture scripts. Render the three sets and record
  their sizes and hashes in `data/SOURCE.md`.
- `OracleFixture` reads Matins like the other hours.
- The new Oracle audits job starts *expected-failing* and reports advisory until B3-M3
  turns it on.

### B3-M3 — Matins in the engine

- In this order, each audited before the next is started:
  1. the invitatory and the hymn;
  2. the psalms and nocturns, in both psalters;
  3. the lessons: Scripture, saints and homilies, with the 1960 contraction;
  4. the responsories and the *Te Deum*;
  5. the special forms.
- Named tests: `CLAUDE.md`'s edge-case list for Matins, including:
  - Christmas (the three Masses' Gospels and their homilies);
  - Epiphany (no invitatory);
  - the Triduum (Tenebræ);
  - the Easter and Pentecost octaves;
  - All Saints and All Souls;
  - Our Lady on Saturday;
  - Ember days;
  - the Annunciation transferred;
  - leap-year February (where *Scriptura occurrens* follows the calendar);
  - 16 September 2026.
- **The commemoration line,** audited against DO's title for every hour.

**Exit:** every audit at zero for Matins in both psalters, the day hours and Vespers still
at zero, and the 2044 hold-out passing.

### B3-M4 — Matins in the app

- *Ad Matutinum* heads the hour picker, before *Ad Laudes*.
- Typesetting for the new units:
  - lesson headings;
  - responsories with their repeat;
  - the invitatory's interleaved antiphon.

  In both readers, English on and off. With English on, lessons are prose, stacked in
  portrait.
- The paged reader on a long hour: page count, table-of-contents jumps to each lesson, and
  no heading, lesson title or reference stranded at the foot of a page.
- **Snapshots:**
  - Matins page 1, a lesson page, a responsory page and the last page;
  - for a ferial day (one nocturn), a III class feast (the contracted third lesson), a
    I class feast (nine lessons with the *Te Deum*) and Good Friday (Tenebræ);
  - English off and on, at default and largest text size;
  - plus the title-block commemoration line on 16 September 2026, and the icon on the
    Home Screen.

**Exit:** CI green, and the snapshots checked (for the morning report).

### B3-M5 — Release

- `docs/install-on-iphone.md`: Matins, the icon and the commemoration line on the
  on-device checklist.
- The *Release notes* screen and `docs/releases/beta-3.md` are updated, and the README
  and roadmap picture are moved on to Beta 3.
- `docs/beta-3-retrospective.md`.
- A pull request with the morning report, and a Build IPA artifact from the branch. Beta
  2's paging bugs were only visible on the phone, so the PR isn't merged and the release
  isn't published until you've tried it (open question 5).

## Open questions (recommendations first)

1. **Matins in the launch schedule.** The app opens on the hour for the time of day,
   Lauds until 09:00.
   - **(a) Matins from 00:00 to 05:00, then Lauds.** Recommended; it matches when Matins
     is said on its own.
   - (b) Matins only from the picker, with the launch schedule unchanged.
2. **Matins for the next day.** The night before is when Matins is anticipated.
   - **(a) Always the chosen date's own Matins, as DO shows it.** Recommended; this is how
     the fixtures check it.
   - (b) A later setting for anticipating the next day's Matins from the evening.
3. **Pius XII fixtures for Matins:** keep them (+30–45 MB)? Recommended yes, as in
   Beta 2. Matins has the most psalms of any hour.
4. **Lessons' headings:** shown as section headings ("LECTIO I" in bold caps), or as a
   smaller italic line within the nocturn (*Lectio i*)? B3-M1 mocks up both. Recommended:
   the nocturns are the sections, and the lessons take the smaller italic line. Nine
   full-size headings would dominate the page and crowd the table of contents.
5. **Merge and release:** open a PR and build an IPA, but merge and publish only after
   you've tried it on the phone? Recommended yes.
6. **The icon's lossless original:** send the PNG when convenient. Until then the WebP,
   converted, goes in.
