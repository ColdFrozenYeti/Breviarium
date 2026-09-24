# Breviarium — Beta 1 Implementation Plan

## Context

The alpha delivered **Roman Vespers, 1960 rubrics, in Latin with the Pius XII (Bea)
psalter**, verified against Divinum Officium (DO) on every evening from 2025 to 2040 and on
all of 2044 ([`PLAN.md`](PLAN.md), [`alpha-retrospective.md`](alpha-retrospective.md)).
The betas extend it in four steps:

| Beta | Scope |
|---|---|
| **1 (this plan)** | **Vulgate psalter as the default** (Bea stays as an option) and the **English translation** |
| 2 | All the day hours: a *diurnale*, not just a *vespertinum* |
| 3 | The Ambrosian and Dominican rites |
| 4 | Matins |

Beta 1 still covers **Vespers only**. It changes *which* Latin psalter is shown by default,
and adds the parallel English that `CLAUDE.md` specifies and the alpha deferred. Everything
else carries over unchanged: fully offline, no Mac, sideloading, the non-negotiables.

**Why the Vulgate is cheaper than it sounds.** DO's Vulgate psalter is its plain
`web/www/horas/Latin/` tree. The "Pius XII Psalter" option only lays `Latin-Bea/Psalterium/`
over it (`officium.pl:132-136`, `$psalmvar`). The data bundle already carries both
(`DataBundle.latin` and `latinBea`), and the psalm parser already understands the Vulgate's
`109:1a`/`109:1b` verse numbering. **DO's English psalter is the Douay-Rheims**, divided
verse for verse like the Vulgate (`109:1a The Lord said to my Lord: * Sit thou at my right
hand:`). So with the Vulgate as the default, Latin and English pair one to one. The
`CLAUDE.md` rule "merge half-verses where the Bea and Vulgate divisions differ" is then
needed only in Bea mode.

**What the alpha already has for English.** `HourAssembler` fills the `english` field of
most main-office units from DO's English corpus. It has one bilingual oracle test
(16 September 2026) and 256 bilingual spot-check fixtures, all rendered with Bea Latin.
Not yet done: English for commemorations (every one is `english: nil`), a full-range
English oracle, and any English rendering in the app. The Settings toggle shows "Coming in
beta".

## How Claude works on this beta

These rules come from the alpha. They are the reason it reached zero mismatches, so they
are not optional.

1. **Read first.** Read `CLAUDE.md`, this plan, the tail of `PLAN.md` and
   `alpha-retrospective.md` at the start of every session.
2. **Never guess a rubric or a DO mechanism.** Every engine change cites the Perl line it
   ports (`web/cgi-bin/horas/…`) and a real fixture that proves it.
3. **Oracle discipline.**
   - Fixtures are never edited to make a test pass.
   - Every fix gets a named oracle test in the established shape: a `@Test` citing the
     date, a fixture excerpt in the doc comment, and assertions on both the model and the
     raw fixture.
4. **Measure before and after every change.** Run the full sweep against the last known
   baseline before committing. Any new mismatch date means revert and write it up in
   `PLAN.md`. Keep fixes narrow: one mechanism, one date shape.
5. **Check both directions from the start.** Every new audit gets its reverse: content
   shown but not in DO, *and* content in DO but not shown (the alpha missed 89 dates by
   only checking one way).
6. **Tests go through the app's construction path** (`DataBundle.makeSanctoralCalendar()`
   and its siblings). The app and the tests must never build the engine differently (the
   alpha had 262 dates of silent divergence).
7. **Measure the design, don't estimate it.** Compare snapshots to `design/reference/` with
   a pixel-measurement script and report element, measured value and expected value.
8. **Milestone gates.** At the end of each milestone: summary, test results, snapshots for
   UI work. Then wait for the user's approval.
9. **Commits and pull requests.**
   - Small commits, each with a `PLAN.md` addendum (in a new "Beta 1" section at its end).
   - Push to the session's designated branch and open a PR when CI is needed. Watch it
     until it is green.
10. **Cloud-session setup (recipe from the alpha):**
    - `git submodule update --init`.
    - Swift: start `dockerd` and use `mirror.gcr.io/library/swift:6.1-noble`
      (`download.swift.org` and Docker Hub pulls may be blocked).
    - DO rendering: install `libcgi-pm-perl` and run `officium.pl` directly via
      `scripts/docker/oracle-worker.sh` with `DO_ROOT`/`ORACLE_RAW` set. This was verified
      byte-identical to the container output.
    - CI artifacts download from `*.blob.core.windows.net`, which the environment's
      network settings must allow.

## Architecture changes

### `BreviariumKit`

- **Options.** Introduce an `OfficeOptions` value carrying `priest`, `psalter`
  (`.vulgate` or `.pius12`) and `english`, passed wherever `priest:` is passed today. It is
  the seam the later betas extend (hour, rite).
- **Corpus selection.** `DataBundle.makeLatinCorpus(psalter:)`:
  - `.vulgate` → `latin` alone;
  - `.pius12` → `latinBea` layered over `latin` (today's behaviour).

  The context builder, occurrence, concurrence and commemorations are unaffected; only
  the psalm and canticle text and the psalm titles change. Confirm with the oracle rather
  than assume it.
- **English everywhere.** Every `Unit` the assembler emits carries its English, including
  commemorations (antiphon, versicle, collect, the "Commemoratio" rubric) and rubrics, as
  DO's bilingual render does.
- **Alignment.** Pairing by structural unit, per `CLAUDE.md`:
  - psalms verse by verse in Vulgate mode (one to one); in Bea mode, each psalm paired
    whole (decided in B1-M1);
  - hymns by stanza;
  - everything else by whole unit.

  Where DO has no English for a section, follow DO's own fallback (`$langfb`), not a
  guess.

### `BreviariumData`

- No new sources are expected. `English/` and both Latin trees are already bundled.
  Report the bundle size again at the end of B1-M2.
- If B1-M1 finds that DO's English differs from Douay-Rheims as published on DRBO, raise
  it before adding any other source (see Open questions).

### App

- **Settings.**
  - *Psalterium:* Vulgata (default) / Pii XII.
  - *English translation* becomes a live toggle.
  - Both persist like the existing settings, and UI tests pin them at launch.
- **Parallel layout in the TextKit typesetter and readers.**
  - Verse material (psalms, canticles, antiphons, hymn stanzas, versicles and responses)
    is set in two columns, Latin left and English right, each with the same typographic
    rules.
  - Prose (chapter, collect) is stacked Latin then English in portrait, and side by side
    in landscape.
  - **Pagination must keep working like a book.** A two-column row that doesn't fit
    continues on the next page. Both columns split at line boundaries, and neither column
    is ever cut mid-line. This is the hardest UI problem of the beta: B1-M5 starts with a
    prototype and a measured decision (see Risks).
- **Alpha carry-overs:**
  - **fix hymn stanzas** (a bug introduced by the TextKit port, see B1-M0): hymns
    currently show as evenly spaced single lines, with no visible stanza grouping;
  - keep a psalm title with its first verse (no title alone at a page bottom);
  - the main day title gets its monthday suffix ("…III. Augusti") and is audited like the
    commemoration titles.

### Oracle fixtures

`data/oracle-fixtures/` gains two Vulgate sets alongside the existing Bea ones. The Bea
sets stay as the regression suite for the option.

| Set | Range | Options |
|---|---|---|
| `main/` (existing, Bea) | 2025–2040 | Latin, priest off |
| **`vulgate/`** (new) | 2025–2040 | Latin, priest off |
| **`bilingual/`** (new) | 2025–2040 | Vulgate Latin + English, priest off |
| `spot-check` (existing) | ~128 dates | Bea, other combinations |
| **`holdout/2044`** (extended) | 2044 | Vulgate + English, priest on and off, next to the existing Bea Latin set |

Generated with `scripts/generate-oracle-fixtures.sh` and
`scripts/generate-holdout-fixtures.sh`, extended with a psalter and language parameter.
`data/SOURCE.md` records the new sets.

## Milestones

### B1-M0 — Housekeeping and baseline

Goal: start the beta from a clean, measured baseline.

1. Re-run every alpha check on the current `main` and record the numbers. Expected: both
   full-range audits 0, all 732 hold-out cases pass, full suite green.
2. **CI:** add `concurrency` with `cancel-in-progress` to `kit-ci.yml` and `app-ci.yml`,
   so stacked pushes stop wasting macOS minutes.
3. **CI budget:** move the long full-range audits into a separate Linux workflow run on
   demand and on `main`, if Kit CI grows past about 10 minutes with the new fixture sets.
4. **Bugfix: hymns show as single lines, not stanzas.**
   - **Symptom.** In the M5 snapshots (for example 19 November 2026, "Fortem virili
     pectore") every line of the hymn is spaced like a stanza of its own (about 26 pt
     pitch), so the stanzas can't be told apart. Only the final doxology, the last unit,
     is set tight at the normal 23 pt.
   - **Cause.** The engine is correct: `HourAssembler.hymnStanzas` splits at DO's `_`
     lines and emits one `.prose` unit per stanza, its lines joined with `\n`. But
     `OfficeTypesetter` appends each unit as one paragraph with the stanza gap as
     `paragraphSpacing`, and in TextKit every `\n` inside it starts a new paragraph. So
     the gap lands after every line instead of after the stanza. The old SwiftUI
     renderer drew a stanza as one `Text` block, which is why the alpha's earlier
     snapshots were right; the regression came in with the TextKit port (`2ef9957`).
   - **Fix.** Typesetter only: break the lines inside a stanza with the Unicode line
     separator (U+2028), or give only a stanza's last line the gap. Lines within a
     stanza keep the 23 pt pitch, with the stanza gap only between stanzas. Check the
     same pattern in any other multi-line unit (prose with internal line breaks).
   - **Verify.** Measure a hymn page with the pixel script: 23 pt pitch within a stanza
     and a clear gap between stanzas, at default and XXL, in both reading modes. Add a
     hymn page to the snapshot matrix so this can't regress silently. The English
     layout in B1-M5 pairs hymns stanza by stanza, so it depends on this.
5. **`CLAUDE.md` corrections:**
   - the reference-screenshot file name (`Format.png`, not
     `universalis-compline-night.png`);
   - the psalter default (Vulgate, with Bea as an option);
   - the oracle fixture scope for Beta 1.

   These edits are listed for approval before they are made.
6. **Exit criterion:** baseline recorded in `PLAN.md`; CI changes green; hymn stanzas
   measured correct in the snapshots; `CLAUDE.md` edits approved.

### B1-M1 — Understand the psalters and the English (no code)

Goal: read, don't guess. One review document, `docs/psalters-and-english.md`, cited to
the pinned DO commit:

- how `psalmvar`, `lang1`, `lang2` and `langfb` interact (`officium.pl`, `horas.pl`);
- every difference between the Vulgate and Bea psalters that reaches Vespers:
  - verse numbering and half-verse splits;
  - psalm titles (the Bea files carry them; the Vulgate files do not);
  - divided psalms (`[1]`/`[2]` parts);
  - the `—` stanza markers that appear only in Bea;
  - the canticle (Magnificat) text;
- how DO lays out the bilingual Vespers page (which units pair, and what happens when one
  side is missing);
- the English corpus:
  - is the psalter Douay-Rheims as on DRBO? Compare a sample of psalms and one chapter
    per season;
  - where DO's English differs from the Latin structure;
  - how the commemoration English is built (`getcommemoratio` with `$lang`);
- a concrete proposal for the two-column layout rules and the pagination split policy.

**Exit criterion:** the user reviews and approves the document before engine code.

### B1-M2 — Fixtures and data

1. Extend the fixture scripts with the psalter and language parameters. Verify on a sample
   that host renders equal container renders, as the alpha did.
2. Generate `vulgate/` and `bilingual/` for 2025–2040, and the 2044 Vulgate+English
   hold-out with priest on and off. Check determinism by generating a year twice.
3. Report the fixture sizes and the bundle size.
4. **Exit criterion:** fixtures committed and documented in `data/SOURCE.md`. The existing
   Bea suite is still green.

### B1-M3 — Vulgate in the engine

1. `OfficeOptions` and `makeLatinCorpus(psalter:)`, used by the app and by every test.
2. Parametrize the full-range content audit, the commemoration audit and the hold-out
   test by psalter.
3. Bring the **Vulgate** audits to 0/0/0/0/0/0/0 and 0 commemoration dates. Fix any
   gaps with the alpha's methodology (Perl citation, named test, sweep, revert on
   regression).
4. **Exit criterion:** Vulgate and Bea both at zero in every audit; 2044 Vulgate hold-out
   passes; full suite green.

### B1-M4 — English in the engine

1. English for every unit, including commemorations and rubrics, following DO's pairing
   and fallback.
2. Alignment per `CLAUDE.md`: Vulgate psalms by verse line, Bea psalms whole (decided in
   B1-M1), with named tests for both.
3. New audits over the `bilingual/` range, in both directions:
   - **English content:** every English piece we render appears in DO's page;
   - **English completeness:** every English unit DO shows has one in our output;
   - **pairing:** every Latin unit carries the English unit DO pairs with it.
4. **Exit criterion:** all English audits at zero over 2025–2040 and on the 2044
   hold-out (priest on and off).

### B1-M5 — English and the psalter setting in the app

1. Settings: *Psalterium* and a live *English translation* toggle. Persisted, and pinned
   in UI tests.
2. **Prototype first:** a two-column typesetting and pagination spike, measured on a long
   psalm at XXL in both orientations. Present the result and the chosen split policy for
   approval before building it out.
3. Build the parallel layout into `OfficeTypesetter` and both readers (horizontal pages,
   with slide and curl, and vertical scroll).
4. Carry-overs: psalm title kept with its first verse; main day-title monthday suffix.
   Hymns are set as stanzas already (fixed in B1-M0); the English hymn column pairs
   stanza by stanza.
5. The full snapshot matrix from `CLAUDE.md`: ferial day, commemoration day, I class
   feast and Holy Week day; page 1 and a psalmody page; English off and on; portrait,
   plus landscape with English on; default and largest text size. In both psalters for at
   least the ferial day.
6. Measure against `design/reference/` with the pixel script and fix differences.
7. **Exit criterion:** CI green; snapshots measured and shown; user approval.

### B1-M6 — Beta 1 release

1. Update `docs/install-on-iphone.md`'s on-device checklist: the psalter switch, English
   on and off in both orientations, and page turns with two columns.
2. The user runs **Build IPA** and sideloads it.
3. A short "Beta 1" addendum to `alpha-retrospective.md` (or a `beta-1-retrospective.md`):
   what went right, what went wrong, and what to carry into Beta 2.
4. **Exit criterion:** the user confirms the checklist on the phone.

## Testing strategy detail

- **Suites:**
  - Kit unit tests;
  - named oracle tests;
  - full-range audits per psalter (content, commemorations) and per language (English
    content, completeness, pairing);
  - the 2044 hold-out per psalter and language, with priest on and off;
  - UI snapshot matrix.
- **Baseline table.** Every commit that touches the engine records the per-category
  numbers for every audit in `PLAN.md`. A number that goes up is a regression, even if
  another goes down.
- **CI time.** The full-range audits take about 5 minutes each on the alpha's single
  set; Beta 1 roughly triples that. B1-M0 decides whether they move out of the per-push
  Kit CI into an on-demand Linux workflow. They stay mandatory before any engine commit
  either way (run locally or in that workflow).

## Risks

- **Two-column pagination.** Book-style flow with two columns, where rows split across
  pages at line boundaries in both columns, has no ready-made iOS API: `NSTextTable` is
  macOS-only. The likely approach is:
  - each aligned pair becomes a row whose height is the taller column;
  - a custom paginator packs rows into pages and splits a row by lines when it doesn't
    fit;
  - each column is drawn with its own TextKit container.

  Mitigation: the B1-M5 spike, measured, with a fallback to discuss if it is too complex
  (rows never split, so a page ends between rows).
- **DO's English vs Douay-Rheims.** If DO's English psalter or Scripture differs from
  DRBO, `CLAUDE.md`'s source rule and the oracle disagree. B1-M1 measures the size of the
  difference before anything is decided.
- **Hidden psalter differences.** Bea-specific handling may have crept into the engine
  during the alpha (psalm titles, the `‡` dagger rule, divided psalms). The Vulgate audit
  finds these; fix each narrowly, with the Bea audit as the regression guard.
- **Fixture volume.** Two new full-range sets roughly double the committed fixture size
  (the Bea set is about 11.5 MB). Acceptable for a private repository, but measured and
  reported in B1-M2.
- **English completeness in DO.** Some DO sections may lack English. The engine must
  follow DO's own fallback, and the completeness audit must treat DO's output as the
  truth, not the Latin structure.
- **Cloud-session tooling.** As in the alpha: the network policy and missing tools. The
  recipe above avoids most of it; record any new workaround in `PLAN.md`.

## Decisions

Settled by the user:

1. **Vulgate is the default psalter; Pius XII (Bea) stays as an option.** ("Bea was not
   the right one to choose, but we keep it an option.")
2. **English translation is in Beta 1**, as `CLAUDE.md`'s parallel-text specification
   describes.
3. **Beta 1 is still Vespers only.** The other day hours are Beta 2, the Ambrosian and
   Dominican rites Beta 3, and Matins Beta 4.
4. Carried over from the alpha:
   - the title-size ratios in `CLAUDE.md` stand;
   - book-style pagination with the Scrolling and Page turn settings stands;
   - the UIKit/TextKit exception stays confined to the typesetter and readers.

Open questions, to be answered before the milestone named:

1. **Setting names (B1-M5):** "Psalterium: Vulgata / Pii XII", in Latin like the other
   toggles, or English labels?
2. ~~English rubrics~~ **Decided in B1-M1:** show DO's English rubric in the English
   column, beside the Latin.
3. ~~English title block~~ **Decided in B1-M1:** the day title stays Latin only.
4. ~~DRBO vs DO English~~ **Decided in B1-M1:** follow DO's English as it is for Beta 1.
   Replacing the dozen chapters worded like the King James Version with DRBO text is a
   possible follow-up (`psalters-and-english.md` §6).
5. **Two-column split policy (B1-M5):** `psalters-and-english.md` §7 is approved as the
   prototype's starting point; the final policy is decided on its evidence.
6. **Bea pairing (decided in B1-M1):** with the Pius XII psalter and English on, each
   psalm is paired whole; `CLAUDE.md` updated.
