# Breviarium — Beta 6 Implementation Plan (draft)

**Status: under way, 9 October 2026.** The questions are answered (§7) and the calendar
has arrived (§2a). The user asked on 9 October to move every check of theirs to the end of
B6-M5 (§8), so the milestones run without waiting; the owners' written permission is still
to come and doesn't block the work. Beta 6 is **Ambrosian Compline**, alone, plus two display fixes the user has
seen on the phone.

## Context

On 8 October 2026 the user narrowed the Ambrosian work: there aren't the resources yet
for the Ambrosian Office of the Dead (OCR of a combined Office and Mass book) or the
Little Office (Beta 7, from LaTeX). The Ambrosian rite ships with Compline alone. The
user supplied the Compline source: four PDFs, one for each part of the 1957 breviary.
`docs/ambrosian-sources.md` still governs: no Roman fallback, provenance for every text,
no claim of the full office, tests from the source page by page.

The same request adds two display fixes that apply to every rite:
- **side by side** (decided 8 and 9 October): with English on, every unit is set Latin
  left and English right, except the long Matins lessons, which stay stacked in portrait;
- **rubrics that aren't red**: direction text shown in white.

## 1. The source

| Field | Value |
|---|---|
| Title (all four) | *Ad Completorium Quotidianum iuxta ritum Sanctæ Ecclesiæ Mediolanensis* |
| Basis claimed | *Divinum Officium MCMLVII*, i.e. the 1957 *Breviarium Ambrosianum* |
| Parts | *Pars hiemalis prima* (12 pp.), *hiemalis secunda* (13), *æstiva prima* (12), *æstiva secunda* (13) |
| Made by | "Digitalized by @churchofambrose", Milan 2025; free at mrchurch.it/resources |
| Format | Typeset PDF (PDF24 / Ghostscript, 28 September 2025), with a usable text layer |
| Licence | **CC BY-NC-ND 4.0**: "not for sale and cannot be sold without explicit permission" |
| Colour | Red for rubrics, section titles, ℣/℟ and initials, as a printed breviary |

The text layer is good but not clean: the *æ* in *sǽcula* drops out ("s cula"), and the
modern typesetting has misprints a few times a page: *venitatem*, *quæriis*,
*costituisti*, *da te*, *superme*, *Beneficat*, *guadia*, *Snacti*, *Indulgetiam*,
*Arehængelo*, *Spirtum*, *eccatorum*, *Utrisuqe*, *nun*, *Christ carissima*, *tristita*.
Every unit would be transcribed by hand from the page image, with the text layer only as
a starting point.

### What the four parts contain

The four parts are one ordinary, *Completorium quotidianum*: the same every day of the
week (no weekday psalter), varying only by season and by a festal or ferial form.

| | Hiemalis I | Hiemalis II | Æstiva I | Æstiva II |
|---|---|---|---|---|
| Season (per `ambrosian-sources.md`) | 1st Sunday of October to Lent | 1st Sunday of Lent to Holy Saturday | Easter to the octave of Pentecost | 1st Sunday after Pentecost to the 1st Sunday of October |
| After *Deus in adiutorium* and the psalms | *Hallelujah* | *Laus tibi, Domine, Rex æternæ gloriæ* | *Hallelujah* | *Hallelujah* |
| Hymn | *Te lucis* before the psalms | *Lux alma, Christe* before the psalms **and** *Te lucis* after them | *Te lucis* before | *Te lucis* before |
| Festal form (no *preces*) on | Solemnities of the Lord, octaves, Sundays, Our Lady's feasts, St John Baptist, Ss Peter and Paul, pontifical and patronal days | Sundays, St Joseph, the Annunciation | all Paschaltide, except the *Triduum Litaniarum* | as Hiemalis I |
| Marian antiphon | *Ave, Regina cælorum* (Nativity of Our Lady to Christmas), *Alma Redemptoris* (Christmas to Lent) | *Salve, Regina* (not on Good Friday) | *Regina cæli* (Easter to Pentecost) | *Inviolata* (1st Sunday after Pentecost to the Nativity of Our Lady), *Ave, Regina* (after) |
| Its collect | *Porrige nobis* / *Gratiam tuam* | *Omnipotens sempiterne Deus, qui gloriosæ* | *Deus, qui per resurrectionem* | *Concede nobis* / *Porrige nobis* |

### The order of the hour, as read from the pages

Two-column pages make the reading order a judgement in places (marked †); B6-M2 sets
it out page by page for the user to confirm.

1. *Pater noster. Ave María.* (between asterisks; said secretly before the hour)
2. *Convérte nos, Deus, salutáris noster*, ℟. *Et avérte iracúndiam tuam a nobis*; ℣. *Deus,
   in adiutórium*, ℟. *Dómine, ad adiuvándum me festína*, *Glória Patri… Sicut erat…*,
   *Hallelujah* (Lent: *Laus tibi…*)
3. Hymn: *Te lucis* (Lent: *Lux alma, Christe*)
4. Psalms 4, 30 (verses 2–6), 90, 132, 133 and 116, each but 132 and 133 with *Glória
   Patri*; 132, 133 and 116 under one *Glória*; *Hallelujah* after the last (Lent: *Laus
   tibi…*). No antiphon over the psalms.
5. Lent only: hymn *Te lucis*
6. *Epistolella* (1 Cor 16:13–14), ℟. *Deo grátias*
7. *Responsorium breve*: *Pax multa diligéntibus*, *Iterum*, ℣. *Et non est illis
   scándalum*, ℣. *Glória Patri*, ℟. *Pax multa…* †
8. *Ant. Salva nos* (incipit), *Nunc dimíttis*, *Glória Patri… Sicut erat…*, *Iterum: Nunc
   dimíttis…* (first verse again), *Ant. Salva nos, Dómine, vigilántes…* with ℟. *Custódi
   nos dormiéntes*, ℣. *Ut vigilémus in Christo*, ℟. *Et requiescámus in pace* †
9. *Capitulum*: *Custódi nos, Dómine, ut pupíllam óculi…*, *Hallelujah* (Lent: *Laus tibi…*),
   *Kyr. kyr. kyr.*
10. **Festal form**: straight to ℣. *Dóminus vobíscum* and the collect *Illúmina*.
    **Ferial form**, kneeling: *Pater noster* (secretly), ℣℟, *In pace in idípsum*, the
    *Symbolum Apostolorum* (secretly to *remissiónem peccatórum*, then aloud), the *preces*
    (seven ℣℟), Psalm 12 with *Glória*, ℣. *Dómine, avérte fáciem tuam*… then the collect
11. ℣. *Dóminus vobíscum*, the collects *Illúmina*, *Noctem istam*, *Vísita* (one conclusion),
    ℣. *Dóminus vobíscum*, *Kyr. kyr. kyr.*, ℣. *Benedícat et exáudiat nos Deus*, ℣.
    *Dormiámus in pace*, ℣. *Benedicámus Dómino*
12. *Pater noster* (secretly), ℣℟, ℣. *Noctem quiétam et finem perféctum*
13. The Marian antiphon of the season, its ℣℟ and collect, ℣. *Fidélium ánimæ*
14. In choir: the *Confiteor* of the hebdomadary and the choir's reply, *Misereátur*,
    *Indulgéntiam*, ℣. *Adiutórium nostrum*, ℣. *Sit nomen Dómini*

## 2. What the source does not decide

The source names its forms by feast and season, but has **no calendar**. To choose the
festal or ferial form on a date, the app has to know which days are Sundays (easy),
Paschaltide (easy: the Ambrosian Easter is the Roman one), the *Triduum Litaniarum*,
Our Lady's feasts, Solemnities of the Lord and octaves *in the Ambrosian calendar*, and
St Joseph and the Annunciation in Lent. The Roman calendar can't supply them (rule 1 of
`ambrosian-sources.md`).

**Answered (questions 5 and 6):** the user has photographs of the Ambrosian calendar, a
perpetual paschal table and a table of movable feasts. They become a second source
(the same intake as §1: photos kept out of the repository, every date traceable to a
photo). The movable-feast table stops in 2000, so the engine computes the movable feasts
itself, from the Easter computus and the rules the table embodies (the six-week Ambrosian
Advent, the Ambrosian Lent from its first Sunday, the *Triduum Litaniarum*), and the
table's years up to 2000 become test cases for that computation. The same calendar gives
the title block its day name.

## 2a. The calendar source (received 9 October 2026)

Six scanned pages, *Rubricæ Generales* pp. 12–17 (Church of Ambrose), from the 1957
breviary's front matter (printed pages XV–XVIII and the two tables after them):

- **Kalendarium Ambrosianum**, January to December: each day's feast and its Ambrosian
  rank (*Sol. Dom.* = *Solemnitas Domini*, *Sol. majus*, *Solemne*, *Sol.*, *Privil.*, I and II
  class), commemorations and vigils, with the epact, dominical letter and Roman date
  columns.
- **Elucidatio Kalendarii**: how to use the epacts and letters.
- **Tabula Paschalis Perpetua**: for each dominical letter and epact, Septuagesima, the 1st
  Sunday of Lent, Easter, Ascension, Pentecost, Corpus Christi and the 1st Sunday of
  Advent; with its rules: *Adventus Domini inchoatur Dominica prima post Festum sancti
  Martini*; Lent begins on the *Dominica in capite Quadragesimæ*; the Ember days; the
  *tempus clausum* for weddings.
- **Tabella temporaria festorum mobilium**, 1955–2000: the same dates by year.

The engine computes the movable feasts from Easter and these rules, and the *Tabella*'s
46 years (1955–2000) are its test cases, with the perpetual table as a second check.
Only what Compline needs is transcribed now (the ranks that choose the festal form,
the day's name for the title block); the rest waits for a full Ambrosian office.

## 3. Rights

The PDFs are **CC BY-NC-ND 4.0**. The texts themselves are very old (the Vulgate-era
psalms, St Ambrose's hymns, the ancient collects), and a faithful re-typesetting of them
probably adds no copyright of its own; but the 1957 rubrics may still be in copyright
in Italy, and *NoDerivatives* forbids sharing an adapted version. Normalising the
spelling (J→I, accents), correcting misprints and splitting the text into the app's
units are arguably adaptations. The app's code is GPL and on the App Store, so
*NonCommercial* also needs care: the app is free, but the GPL lets anyone sell it.

**Answered (question 1):** the user knows both owners of Church of Ambrose and has their
full verbal permission to use the work; a written confirmation will follow. The permission
is recorded in `NOTICE.md` and shown on the About screen, with credit to Church of Ambrose.
The PDFs themselves still stay out of the repository; the transcription goes in, under the
owners' permission rather than the GPL, listed as third-party material in `NOTICE.md`.

## 4. Proposed design

### Engine (`BreviariumKit`)

- `Rite.ambrosianus`, a provider of its own behind the rite interface. It has one office,
  *Completorium Ambrosianum*, and no calendar beyond what Compline needs: Easter (the
  shared computus), the season boundaries in §1, and the Ambrosian calendar (questions 5 and 6).
- **No Divinum Officium path at all**: the Ambrosian provider never reads the DO
  corpus, so no Roman text can reach it. A negative test checks that no unit's text
  appears in the Roman Compline of any day.
- **The data**: a hand transcription, `data/ambrosian/completorium-1957.txt`, in a small format of its own: each unit with its part and page
  (`[HP 3]`), the diplomatic text, and a separate corrections table (`misprint → reading,
  page, reason`). The data tool turns it into the bundle, applying the corrections and
  the orthography rules.
- The engine assembles the hour from the date: part, form (festal or ferial), hymn(s),
  *Hallelujah* or *Laus tibi*, and the Marian antiphon and collect.

### App

- *Ritus → Ambrosianus* becomes selectable and shows one office, **Completorium
  Ambrosianum** (`CLAUDE.md`: name only what exists). The hour picker lists just *Ad
  Completorium*; the app opens on it at any time of day under this rite.
- Settings that don't apply are disabled under *Ambrosianus*: *Psalterium* (the
  Ambrosian psalter is its own) and English (Latin only, question 4).
- *Sacerdos vel diaconus adest* applies (question 7): off, *Dóminus vobíscum* becomes
  *Dómine, exáudi oratiónem meam*, ℟. *Et clamor meus ad te véniat*; and the Confiteor
  follows the Roman pattern (question 11).
- The title block: the date line, then the day from the Ambrosian calendar (question 6).

### Tests (no oracle)

- **Page fixtures**: for each of the four parts, the whole hour as the pages give it,
  in both forms, as expected unit lists written by hand from the page images.
- **Date tests**: each season boundary, Good Friday (no *Salve*), the *Triduum
  Litaniarum*, the Marian antiphon changeovers (Christmas, Lent, Easter, Pentecost,
  8 September), and the Saturday evenings before them.
- **Provenance**: every unit carries a part and page, and the test fails if one doesn't.
- **No Roman text**: as above.
- **Review** (question 16): the user checks every form against the PDFs, then the owners
  of Church of Ambrose give it a final reading before it ships.

## 5. The two display fixes

### Side by side, all but the lessons (decided 8 and 9 October 2026)

`OfficeTypesetter.typesetParallel` stacks every prose unit in portrait (`isProse`:
chapters, collects, lessons, and the short units *Amen.*, *Orémus.*, *Allelúia.*). That
is what puts two *Amen*s one above the other: the engine sends a bare *Amen.* as prose
after the Marian antiphon's collect, after *Visita*, and elsewhere, and the typesetter
stacks it. The fix: side by side in portrait as in landscape for every unit except a Matins lesson
(`Unit.lesson`), which stays stacked in portrait. `CLAUDE.md` ("Prose … is stacked … in
portrait") and the snapshot matrix change with it.

### Rubrics that aren't red

A scan of every hour on nine dates, under both rites (9 October), found four kinds of
direction shown in white:

1. ***(fit reverentia)* in lower case.** `InlineRubrics` matches only *(Fit reverentia)*
   with a capital, so the bow in Psalm 110:9 (*Sanctum et terríbile nomen eius*), Psalm
   112:2 (*Sit nomen Dómini benedíctum*) and Psalm 67:5 (*Dóminus nomen illi*) stays white.
2. **The English *(bow head)*** in lower case, beside those verses, for the same reason.
3. **The Te Deum's English directions**, which DO writes without parentheses: *During
   the following verse all make a profound bow…*, *Kneel for the following verse*, and
   *bow head* run straight into *Holy, Holy, Holy*.
4. **Whole rubrics sent as prose**: *Sequens stropha, si coram Sanctissimo exposito
   Officium persolvatur, dicitur flexis genibus* before *Tantum ergo* (Corpus Christi
   Vespers, 4 June 2026), white and with its English.

The fix: match the directions without regard to case; mark the Te Deum's English ones
by their wording; send DO's whole-line directions as rubrics, not prose; then a wider
scan (every hour, every day of one year, both rites) for any direction left white, and an
engine test that lists them. Plus any case the user has seen that the scan didn't
(question 17).

## 6. Milestones

- **B6-M0** — Housekeeping: the roadmap and `CLAUDE.md` (Beta 6 = Ambrosian Compline;
  the Ambrosian Office of the Dead and Little Office moved to *After 1.0*), the four-icon
  and licence work merged, the permission in `NOTICE.md` and About, a clean baseline.
- **B6-M1** — The display fixes: side by side throughout, and the rubrics, with
  snapshots before and after. Every Roman and Dominican audit unchanged.
- **B6-M2** — `docs/rubrics-ambrosian-compline.md`: the source, its forms, the
  reconstructed order with page references, the corrections and expansions table, the
  calendar (from the photos) and the movable-feast rules, for approval.
- **B6-M3** — The transcription and the Ambrosian calendar, with their tests.
- **B6-M4** — The Ambrosian provider in the engine.
- **B6-M5** — The app: *Ambrosianus*, the picker, the settings, snapshots of each form.
- **B6-M6** — Release: notes, README, roadmap, retrospective, PR, IPA.

## 7. Questions and answers (9 October 2026)

1. **Rights.** The user has the owners' full verbal permission; written confirmation to
   follow; credited on the About screen and in `NOTICE.md`.
2. **The Ambrosian Office of the Dead and Little Office**: deferred to *After 1.0*.
3. **Side by side**: every unit, except the Matins lessons, which stay stacked in
   portrait (the user first said "throughout", then confirmed "all but lessons").
4. **English under *Ambrosianus***: none; Latin only, the English setting disabled.
5. **Festal or ferial form**: from the Ambrosian calendar, which the user will supply as
   photographs (calendar, perpetual paschal table, movable feasts to 2000).
6. **Title block**: the day from that calendar. Movable feasts are computed, not read
   from the table, since it stops in 2000.
7. **Priest setting**: applies. Off, *Dómine, exáudi oratiónem meam* replaces *Dóminus
   vobíscum*, as in the Roman office.
8. **Lent's two hymns**: both, as printed: *Lux alma, Christe* before the psalms, *Te
   lucis* after them.
9. **Spelling**: the app's rules (J→I, so *Halleluia*, *Iesum*, *adiutórium*), keeping the
   source's own accents and adding none.
10. **Misprints**: corrected, each logged with page and reason for review; doubtful ones
    asked about, not guessed.
11. **Confiteor**: by the priest setting. On: the whole choir exchange as printed. Off:
    one Confiteor as in the Roman Compline, without *et vobis, fratres* / *et vos, fratres*
    or *et tibi, pater* / *et te, pater* (keeping the Ambrosian saints, *beáto Ambrósio
    confessóri*), then *Misereátur nostri…* and *Indulgéntiam*.
12. **Abbreviations**: expanded (*Kýrie, eléison* three times, the full *Glória Patri* and
    *Sicut erat*), each logged as editorial; the incipit *Ant. Salva nos* stays an
    incipit, as printed.
13. **Review**: the user first, then the owners.
14. **Eves**: Compline always takes its own date's season; the change comes on the
    Sunday evening (Saturday before Lent is still *hiemalis I*; Holy Saturday is Lent).
15. **Holy Week**: nothing else changes; only the *Salve* is left out on Good Friday,
    with nothing in its place.
16. **Settings**: *Ritus → Ambrosianus* lists one office, *Completorium Ambrosianum*.
17. **Rubrics seen on the phone**: the four kinds in §5 are the ones.

### Still needed from the user

- The calendar photographs (calendar, perpetual paschal table, movable-feast table).
- The owners' written permission, when convenient (work doesn't wait on it).

## 8. The user's checks, all at the end of B6-M5 (decided 9 October 2026)

Work goes ahead on Claude's reading of the sources; every judgement is logged where the
user can check it in one sitting at the end of B6-M5, before the owners' review:

1. **The reading order** of the two-column pages (§1, the † places), in
   `docs/rubrics-ambrosian-compline.md`, with page references.
2. **The corrections table**: every misprint corrected, with page and reason; doubtful
   readings flagged rather than guessed.
3. **The expansions table**: *Kýrie, eléison*, *Glória Patri*, the user's rulings
   (*Dómine, exáudi*; the single Confiteor), each marked as editorial.
4. **The calendar transcription**: every entry used, with its photo and position, and
   the festal-form decision it drives, as one table to read through.
5. **The movable feasts**: the computed dates for 1955–2000 against the *Tabella*, and a
   sample of years after 2000.
6. **Screenshots** of every form on the phone or from CI: the four parts, festal and
   ferial, priest on and off, the five Marian antiphons, Good Friday.

If a check turns up a misreading, it's a data edit and a test, not a redesign.
