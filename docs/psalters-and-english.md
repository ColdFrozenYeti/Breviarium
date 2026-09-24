# The psalters and the English: how Divinum Officium does it

Beta 1, milestone B1-M1 (`docs/Beta_1_plan.md`). This is a review document; no engine
code follows until it is approved. Every claim cites the pinned Divinum Officium checkout
(`data/divinum-officium`, commit `126a07f`) or a measurement made against it.

Paths below are relative to `data/divinum-officium/web/`. "Vespers psalms" means the 32
psalms that appear in the 2025–2040 oracle fixtures (109–116, 119–132, 135–141, 143,
144, 147), plus the Magnificat (`Psalm232.txt`).

## Summary

1. **The psalter switch touches only the psalm files.** With DO's "Pius XII Psalter"
   option off (its default, `www/horas/horas.setup:5`), the Latin column reads the plain
   `Latin/` tree. Nothing outside `Psalterium/Psalmorum/` changes for Vespers.
2. **The Vulgate and the English are the same structure, line for line.** Every
   Vespers psalm has the same verse lines, with the same references, in `Latin/` and
   `English/`. Pairing Vulgate Latin with English verse by verse is exact.
3. **Bea does not share that structure.** Its verse numbers mean something else, and its
   lines break at different points. Verse-by-verse pairing of Bea with English would be
   approximate. I recommend DO's own pairing for Bea: the whole psalm as one row.
   This changes a rule in `CLAUDE.md` and needs your approval.
4. **The Vulgate has three things the alpha barely met:**
   - eight `‡` marks that move the half-verse break;
   - no psalm titles;
   - its own Magnificat text, which places the cross differently.

   The B1-M3 audit will catch any slip in these.
5. **DO's English is complete for Vespers.** In 92 rendered evenings of 2026 not one
   English cell fell back to Latin.
6. **DO's English is mostly Douay-Rheims, not entirely.**
   - The psalter is Challoner's Douay-Rheims, differing from DRBO in about 33 of 5,540
     words.
   - Of 83 English chapters, 61 match DRBO. About a dozen use King James or modern
     wording. The rest are the breviary's own adaptations.
   - You need to decide which to follow (question 4 below).
7. **Proposed layout and pagination rules for two columns** are in the last section, for
   the B1-M5 prototype to test.

## 1. How the psalter and language options work

- **`$psalmvar`** is the "Pius XII Psalter" option. It is off by default
  (`www/horas/horas.setup:5`).
  - When it is on, `officium.pl:133-137` renames the Latin column's language from `Latin`
    to `Latin-Bea`, for the whole page.
  - `horasscripts.pl:468` and `:551-557` then read `Psalm<n>.txt` from `Latin-Bea/`
    instead of `Latin/`.
  - `Latin-Bea/` contains only `Psalterium/`, and for Vespers only `Psalmorum/` matters.
    Every other file falls back to `Latin/` through `checkfile`'s dash rule
    (`DivinumOfficium/SetupString.pl:794-797`).
- **`$lang1` and `$lang2`** are the two columns. `print_content` (`horas/webdia.pl:1003-1046`)
  builds both scripts in full and prints them side by side.
- **`$langfb`** is the fallback language, English by default (`officium.pl:130`).
  - An English file or section that is missing is filled from Latin: English, as the
    fallback language, is layered on top of Latin (`SetupString.pl:589-593`).
  - So wherever DO lacks English, its English column shows Latin. Section 5 measures how
    often that happens at Vespers: never, in the sample.
- **Other code keyed on the language name.** Only one Vespers code path tests
  `$lang eq 'Latin'` exactly: `specials/orationes.pl:476`. It rebuilds the commemorated
  office through `officestring($lang, …)` unless the language is plain Latin.
  - Under Bea, `$lang` is `Latin-Bea`, and that file falls back to `Latin/`, so both
    paths read the same text.
  - I expect no difference. If there is one, the Vulgate audit in B1-M3 will show it.
- **Display options that apply to every language.** `horasscripts.pl:397-419`, with the
  defaults from `horas.setup:17-20` (`$nonumbers=0`, `$noinnumbers=1`, `$noflexa=1`):
  - the letter on a split verse (`1a` → `1`) and inline references (`(5a)`) are removed;
  - any other text in parentheses is shown as a rubric, for example `(fit reverentia)`
    and its English counterpart `(bow head)`;
  - `‡` becomes the half-verse break: `A ‡ B * C` is displayed as `A * B C` (`:418`);
  - `†` (the flex) is removed (`:419`).

  The engine already does all of this for Bea's Latin. The English needs the same
  treatment.

## 2. Vulgate against Bea, as it reaches Vespers

| | Vulgate (`Latin/`) | Bea (`Latin-Bea/`) |
|---|---|---|
| **Verse references** | Breviary verse lines, split `a`/`b` where the breviary divides a verse (`109:1a`, `109:1b`); some psalms count the title as verse 1, so 139 and 141 start at verse 2 | Numbered in sequence, one number per line (Psalm 130 is 1–5 where the Vulgate has 1a, 1b, 2a, 2b, 3). Psalm 115 is numbered 10–18, continuing Psalm 114 ("pars altera") |
| **Line counts** | – | The same as the Vulgate in 29 of 32 psalms. 109 has 7 lines against 8, 111 has 10 against 9, and 135 has 26 against 27 |
| **Psalm titles** | None in the files; DO shows `Psalmus 109 [1]` | A `(title)` first line, shown as `Psalmus 109 — Messias rex, sacerdos victor [1]` (`horasscripts.pl:581-596`) |
| **Stanza marks** | None | A trailing `—` on some lines (for example 109:3 and 113:2), shown as-is |
| **`‡` (moves the half-verse break)** | 8 lines: 114:4b, 114:8, 115:7b, 124:2b, 137:7, 137:8, 138:14, 144:19 | 1 line: 144:19 |
| **`†` (flex, removed)** | 18 lines | 10 lines |
| **Divided psalms** (`Psalmi major.txt`: 135(1-9), 138(1-13)/(14-24), 143(1-8)/(9-15), 144(1-7)/(8-13a)/(13b-21)) | The range filter (`horasscripts.pl:598-614`) is applied to each psalter's own numbering | Same filter, but Bea's numbers differ, so the split can fall on a different line. Example: 143(1-8) takes 9 lines in each psalter, ending at different words |
| **Magnificat** | Its own text, with the cross before the asterisk: *Magníficat ✠ \* ánima mea Dóminum* | A different translation, with the cross after the asterisk: *Magníficat \* ✠ ánima mea Dóminum* |

**What this means for the engine (B1-M3).**
- The engine needs no new rubrical logic for the Vulgate: the calendar, occurrence,
  concurrence and commemorations don't depend on the psalter.
- The risks are in text handling:
  - `‡` is common in the Vulgate, where Bea had it once;
  - the psalm-title code must emit no subtitle;
  - the divided psalms must apply their ranges to Vulgate numbering;
  - the Magnificat's cross placement differs.
- The Vulgate content audit is the test, as planned.

## 3. The English corpus against the Vulgate

- **Structure.** All 202 Latin psalm and canticle files have an English counterpart. For
  every Vespers psalm and the Magnificat, the English file has the same lines with the
  same references as the Vulgate. There is one typo: English `Psalm122.txt` numbers a
  line `122:2y`, where the Latin has `2a`.
  - Outside Vespers, five canticle files (250, 251, 266–268) differ from the Latin in
    line count. These are Beta 2 or Beta 4 material; they're noted here so they aren't
    rediscovered.
- **Markers.** The English lines carry the same markers as the Latin:
  - `†`;
  - inline `(5a)` references;
  - `(bow head)` wherever the Latin has `(fit reverentia)`;
  - the `+` cross on the Magnificat's first line.

  They go through the same display rules as the Latin (section 1), except J→I, which
  never touches English.
- **Hymns.**
  - Every hymn used at Roman Vespers has an English version. The only hymns missing an
    English version are the Monastic variants (`HymnusM …` and `SanctiM/`), which we
    never use.
  - Where both exist, the English has the same number of stanzas as the Latin. This is
    what the B1-M0 fix and the stanza pairing in B1-M5 depend on.
  - Six hymns have a different number of lines within a stanza. That affects row
    height only.
  - `Sancti/08-15.txt` [Hymnus Vespera] carries, after the 1960 hymn, a second, older
    hymn (*O quam glorifica*) that has no English.
- **Office names stay Latin.** English files keep `[Officium]` in Latin, for example
  `English/Tempora/Pent23-0.txt`. So DO's English commemoration heading reads
  "Commemoration of Dominica XXIII Post Pentecosten I. Novembris" (spot-check fixture,
  1 November 2026). The day title is shown once, in Latin, above both columns.

## 4. How DO pairs the two columns

- **Pairing is by script unit, not by verse.** `print_content` alternates one unit from
  each column's script, one table row per pair (`webdia.pl:1011-1043`). `getunit`
  (`:1050-1074`) ends a unit at a blank line. The result, observed on 17 November 2026:

  | Row | Latin cell | English cell |
  |---|---|---|
  | 1 | Incipit | Start |
  | 2–6 | Each psalm, with its antiphon before and after, and its Gloria | The same psalm in English |
  | 7 | Capitulum + Hymnus + Versus together | Chapter + Hymn + Verse |
  | 8 | The Magnificat, with its antiphons | The same |
  | 9 | *Preces Feriales* (omitted) | *Weekday Intercessions* (omit) |
  | 10 | Oratio, with its commemorations | Prayer |
  | 11 | Conclusio | Conclusion |

- **What happens when one side is missing.** Missing English never leaves a blank cell,
  because the Latin fallback fills it (section 1). An `{omittitur}` unit gets a row on
  both sides.
- **What we do differently.** `CLAUDE.md` asks for finer pairing than DO's:
  - verses side by side, verse by verse;
  - hymns stanza by stanza;
  - everything else by whole unit.

  The oracle still checks the text of each side. Pairing is our layout decision, checked
  by our own tests.

## 5. Is the English complete?

- **Method.** Rendered DO locally (host Perl, `officium.pl`, `lang1=Latin`,
  `lang2=English`, `Rubrics 1960`) for every 4th day of 2026, 92 evenings. Flagged
  any English cell containing three or more accented Latin words.
- **Result: none.** No English cell fell back to Latin on any of the 92 evenings.
- **Why a file comparison overstates the gaps.** A raw comparison of section names finds
  472 Vespers-type sections that exist in Latin but not in English. It overstates the
  problem, because English files inherit sections through their file-level `@` preamble.
  The rendered output is the truth.
- **What B1-M4 does.** The English completeness audit checks this over every day
  2025–2040. If DO ever shows Latin in its English column, we show the same, following
  DO's fallback, and the audit records it.

## 6. Is DO's English the Douay-Rheims as published on DRBO?

**Method.** Fetched the DRBO chapters (drbo.org, research only; nothing enters the app)
and word-diffed them against DO's English, ignoring:
- punctuation and case;
- verse markers and text in parentheses;
- DRBO's Challoner footnotes.

**Psalms (32 psalms and the Magnificat, 5,540 words).**
- The text is Challoner's Douay-Rheims.
- About 33 words differ, 0.6%:
  - spelling: *mayst* for *mayest*, *stumbling block* for *stumblingblock*;
  - small words: *to* for *unto*, *upon* for *on*, *compassed* for *encompassed*;
  - a handful of real variant readings, for example 138:3 *my life* where DRBO has
    *my line*, and 144 *his* where DRBO has *thy*.
- Two further differences are verse numbering only: DO's 125:6b and 135:26b are DRBO's
  verses 7 and 27, with the same text.
- The Magnificat omits DRBO's opening "And Mary said:", as the liturgy does.

**Chapters (every English `[Capitulum Laudes]`/`[Capitulum Vespera…]` section that
starts with a reference, 83 in all).**
- **61 match DRBO.** The only differences are the breviary's own incipits (*Brethren:*,
  *My beloved:*) and abridgements that follow the Latin. Examples:
  - Wisdom 3:1-3 skips the middle clause of verse 2;
  - Titus 3:4-5 stops at *he saved us*.
- **About a dozen use King James or modern wording, not Douay-Rheims.** Examples:

  | Where | DO's English | DRBO |
  |---|---|---|
  | Pentecost, Acts 2:1-2 | "the day of Pentecost was fully come… with one accord… a rushing mighty wind" | "the days of the Pentecost were accomplished… together… a mighty wind coming" |
  | 1 January, Titus 2:11-12 | "The grace of God that bringeth salvation… teaching us… worldly lusts… righteously" | "the grace of God our Saviour… instructing us… worldly desires… justly" |
  | Transfiguration, Phil 3:20-21 | "shall change our vile body, that it may be fashioned like unto his glorious body" | "will reform the body of our lowness, made like to the body of his glory" |
  | 29 June, Acts 12:1-3 | "to vex certain of the church" | "to afflict some of the church" |
  | 30 June, 2 Tim 4:7-8 | "a crown of righteousness… the righteous judge" | "a crown of justice… the just judge" |
  | St Raphael, Tob 12:12 | "Then… thine" | "When… thy" |
  | Sacred Heart, Eph 3:8-9 | "the fellowship of the mystery" | "the dispensation of the mystery" |
  | Common of Confessor Bishops, Sir 44:16-17 | "Behold an high priest… righteous… propitiation" | "Henoch… perfect, just… reconciliation" |

  - Others in this group: Rev 1:1-2, Jas 5:7-8, Dan 9:21-22, 1 Pet 5:6-7, 2 Cor 9:6.
  - A few of these are the breviary adapting the text, as the Latin does, for example
    *Behold an high priest* for Sirach 44. That is right as it stands.
  - The rest are a different translation.
- **DO is also inconsistent in the incipit:** *Brethren:* in some chapters, *Brothers:*
  in others.
- **Not measured:** the collects, antiphons and responsories. These are DO's own
  translation by design (`CLAUDE.md`: "Divinum Officium's English for everything else"),
  so there is no Douay-Rheims text to compare them with.

**What this means.** `CLAUDE.md` says "Douay-Rheims (as on DRBO) for Scripture". DO's
psalter meets that, apart from the 0.6% of small variants. DO's chapters meet it about
three times in four. Question 4 below asks which to follow.

## 7. Proposed layout rules for two columns (for the B1-M5 prototype)

**Rows.** The engine's `Unit`s already carry English slots (`Calendar/Hour.swift`). The
typesetter turns each unit into one row with a Latin side and an English side:

| Unit | Row | Notes |
|---|---|---|
| Psalm or canticle verse, Vulgate | One row per verse line | Exact: the lines correspond one to one (section 3) |
| Psalm or canticle, Bea | One row per whole psalm | Each column flows freely, as in DO (question 1) |
| Gloria Patri | One row per half-verse pair | |
| Antiphon | One row | |
| Hymn stanza | One row per stanza | The stanza gap goes after the row |
| Versicle and response | One row | Never split across pages |
| Chapter, collect, commemoration collect | Portrait: stacked, the Latin paragraph then the English paragraph, full width. Landscape: one side-by-side row | As `CLAUDE.md` specifies |
| Rubric | Side by side when DO has English for it, otherwise Latin only | Question 2 |
| Section heading, separator, psalm title, page-1 header | Full width, Latin only | Fixed elements stay Latin (`CLAUDE.md`) |

**Columns.**
- Two equal columns inside the existing 28 pt margins, with a gutter between them. I'd
  start the gutter at about 1× body size (19 pt at default) and settle it by measuring in
  the prototype.
- Each column uses the full typographic system: the same fonts, the 23 pt line pitch,
  the 23 pt second-half indent, and italic responses.
- A row's height is the height of its taller side. Both sides start at the row's top.

**Splitting rows across pages.**
- Rows are packed onto a page top to bottom. When a row doesn't fit, it splits at a line
  boundary in both columns: each column shows the lines that fit in the space left, and
  continues at the top of the next page. No line is ever cut.
- **Keep-with-next:**
  - a section heading or a psalm title never ends a page;
  - a psalm title stays with its first verse row (the alpha carry-over);
  - an antiphon row before a psalm stays with the first verse row.
- **Never split:** versicle and response rows, and any row of 3 lines or fewer on its
  taller side.
- **Minimum split:** a taller row splits only if at least 2 lines of its taller side stay
  behind and at least 2 move on.
- **Fallback, if the prototype shows this is too complex:** rows never split, and a page
  ends between rows. A row taller than a page (a long stacked collect at XXL) is the one
  exception.

**How to build it (to be proved by the prototype).**
- iOS has no text-table layout: `NSTextTable` is macOS-only.
- Each row lays out each side in its own TextKit container, at column width and
  unbounded height. That gives the line-fragment rectangles for each side.
- A paginator packs rows into pages by those rectangles, applying the split rules above.
- Each page is a view that draws its slices of each column with `drawGlyphs(forGlyphRange:at:)`.
- `UIPageViewController` is unchanged, so the slide and curl page turns keep working.
- Vertical scroll uses the same slices, laid out in one tall stack.
- English off keeps today's reader untouched unless the prototype shows one renderer can
  cleanly do both.
- All of this stays inside the approved UIKit exception (`OfficeTypesetter.swift`,
  `OfficeReaders.swift`).

## 8. Consequences for the next milestones

- **B1-M2, fixtures.**
  - `scripts/docker/oracle-worker.sh` currently hard-codes `lang1=Latin-Bea`. It needs a
    psalter parameter: Vulgate is `lang1=Latin`; Latin-only is `lang2=Latin`; bilingual
    is `lang2=English`.
  - Today's normaliser flattens the page into one line of text, which mixes the two
    columns. The existing bilingual spot-check files show this: "…Allelúia. 1 Start ℣. O
    God…".
  - That flattening breaks two things. J→I must apply to the Latin column only, and the
    pairing audit needs to know which cell is which. **Proposal:** bilingual fixtures
    keep the table: one row per line, Latin cell and English cell separated by a tab,
    each normalised on its own.
  - One render takes about 0.7 s on the host, so a full year takes about 4 minutes per
    option set.
- **B1-M3, Vulgate engine.** The watch list from section 2: `‡`, no titles, the
  divided-psalm ranges, the Magnificat cross.
- **B1-M4, English engine.**
  - Pair Vulgate verses by line position, which is identical to pairing by reference and
    avoids the `2y` typo.
  - Pair Bea psalms whole, if question 1 is approved.
  - Apply section 1's display rules to English, and never apply J→I to it.
  - Commemoration headings: "Commemoration of <Latin office name>".
- **B1-M5, app.** Prototype the section 7 rules, measure them, then build.

## Questions for you

**All five answered yes on 2026-09-24:** every recommendation below is adopted.

1. **Bea with English on: pair each psalm as a whole, not verse by verse?**
   - *Recommended:* yes. Bea's verse numbers can't be matched to the English, and its
     lines break half a line away from the English in places. DO pairs whole psalms too.
   - This replaces `CLAUDE.md`'s "merging half-verses where the Bea and Vulgate divisions
     differ" with "in Bea mode, psalms are paired whole". The Vulgate, the default, is
     paired verse by verse exactly.
2. **English rubrics** (Beta 1 open question 2): when rubrics are on, show DO's English
   rubric in the English column, beside the Latin one?
   - *Recommended:* yes. It follows DO, and the English column otherwise has gaps.
3. **English title block** (open question 3): keep the day title in Latin only?
   - *Recommended:* yes. DO does the same, and it is a fixed element under `CLAUDE.md`.
4. **DRBO against DO's English** (open question 4):
   - **(a) Follow DO as it is.** The English oracle audits work unchanged. The small
     psalm variants and the dozen KJV-worded chapters stay.
   - **(b) Follow DO, but replace the dozen non-Douay chapters with DRBO text,** from a
     short, hand-checked table in the data tool. The English audit then carries a list of
     known, cited exceptions for those chapters, the way the alpha documented DO bugs.
     The psalter stays as DO has it.
   - **(c) Bundle a full DRBO text** for all Scripture. This is a new source to vendor,
     much more work, and it gives up the oracle for English Scripture.
   - *Recommended:* **(a) for Beta 1, with (b) as a follow-up if the KJV wording
     bothers you in use.** The psalter, which is most of what you read, already is
     Douay-Rheims.
5. **Two-column rules** (open question 5): approve section 7 as the starting point for
   the B1-M5 prototype. The final split policy is still decided on the prototype's
   evidence, as planned.
