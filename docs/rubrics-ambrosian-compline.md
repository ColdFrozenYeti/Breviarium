# Ambrosian Compline (1957): how the app builds it

Beta 6 (`docs/Beta_6_plan.md`). This is the reference for `AmbrosianCompline` and
`AmbrosianCalendar` in `BreviariumKit/Ambrosian/`, as `rubrics-1960-*.md` are for the
Roman hours. `docs/ambrosian-sources.md` governs it: no Roman fallback, every text with
its edition and page, nothing invented.

Everything marked **Unsourced** is a choice the sources don't make. Each one is listed
for the user's check at the end of B6-M5 (`Beta_6_plan.md` §8) and for Church of Ambrose.

## 1. Sources

| Source | What it gives | In the repository |
|---|---|---|
| *Ad Completorium Quotidianum iuxta ritum Sanctæ Ecclesiæ Mediolanensis*, *Divinum Officium MCMLVII* (Church of Ambrose, Milan 2025), four parts | the text of the hour, its rubrics, its seasons | `data/ambrosian/completorium-1957.txt` (transcription); the PDFs are not committed |
| *Breviarium Ambrosianum* 1957, *Rubricæ Generales* pp. XV–XVIII and the two tables after them (Church of Ambrose's photographs, pp. 12–17) | the *Kalendarium*, the *Tabula paschalis perpetua*, the *Tabella temporaria festorum mobilium* 1955–2000 | `data/ambrosian/kalendarium.txt` (the *Menses* column); the photographs are not committed |

Both are used with the owners' permission (`NOTICE.md`; the About screen says so).

Page references are `part.page`: `HI` *Pars hiemalis prima*, `HII` *hiemalis secunda*, `AI`
*æstiva prima*, `AII` *æstiva secunda*; `HI.6` is page 6 of *hiemalis prima*. The calendar's
pages are its printed Roman numerals (`XV`).

## 2. The order of the hour

One ordinary, the same every day of the week. It varies by the part of the year (§3.2),
by the festal or ferial form (§3.3) and by the Marian antiphon (§3.4). Each step names
the pieces of the transcription it takes, in order; `AmbrosianCompline.plan` is this
list.

| # | Section heading | Pieces | Pages (HI) | Notes |
|---|---|---|---|---|
| 1 | INTRODUCTIO | `praeparatio`, `convertenos`, `deusinadiutorium`, `hallelujah` | 2 | Lent: `laustibi` (*Laus tibi, Domine, Rex æternæ gloriæ*) for *Hallelujah* |
| 2 | HYMNUS | `hymnus-telucis` | 2 | Lent: `hymnus-luxalma` (HII.2) |
| 3 | PSALMODIA | `psalmus4`, *Glória*, `psalmus30`, *Glória*, `psalmus90`, *Glória*, `psalmus132`, `psalmus133`, `psalmus116`, *Glória*, *Hallelujah* | 2–5 | no antiphon; 132, 133 and 116 under one *Glória*; Lent: *Laus tibi* |
| 4 | HYMNUS | `hymnus-telucis` | HII.6 | Lent only; both hymns are said (the user, question 8) |
| 5 | EPISTOLELLA | `epistolella` | 5 | 1 Cor 16:13–14, ℟. *Deo gratias* |
| 6 | RESPONSORIUM BREVE | `responsorium` | 5 | reading order across the two columns: check 1 |
| 7 | CANTICUM | `salvanos-incipit`, `nuncdimittis`, `salvanos` | 5–6 | *Iterum*: the first verse again; reading order: check 1 |
| 8 | CAPITULUM | `capitulum`, *Hallelujah*, `kyrie`, `rubrica-festiva-<part>` | 6 | the part's own rubric on the festal form (§3.3) |
| 9 | PRECES | `preces`, `psalmus12`, *Glória*, *Hallelujah*, `aversio` | 7–8 | ferial form only; Lent prints *Amen.* (`amen-HII`, HII.9) before *Laus tibi* |
| 10 | ORATIO | `dominusvobiscum`, `oratio` | 8 | the three collects under one conclusion |
| 11 | CONCLUSIO | `dominusvobiscum`, `kyrie`, `benedictio`, `finis` | 8–9 | |
| 12 | ANTIPHONA FINALIS | `rubrica-antiphona` (HI and AII only), the antiphon, `fidelium` | 9 | none on Good Friday (§3.4) |
| 13 | CONFESSIO | `confessio`, or without a priest `confessio-sine-sacerdote` | 10 | §5 |

*Glória Patri* is the piece `gloriapatri`; the source's abbreviated *Gloria Patri… Sicut
erat…* after the *Nunc dimittis* is written out the same way (an expansion, §6).

The source's own red title at the head of a piece (*Hymnus.*, *Capitulum*, *Oratio*) is
dropped where the section heading already says it; other red titles (*Psalmus 4.*,
*Epistolella. I. Cor. 16*, *Symbolum Apostolorum.*) are shown as the psalm titles are in
the Roman hours.

## 3. The calendar

Nothing here comes from the Roman calendar. `AmbrosianCalendar` holds it.

### 3.1 The movable feasts

Easter is the Gregorian one (the Ambrosian Easter is the same; the *Tabula* agrees for
every year it covers). The rest follow from Easter as the *Tabula* lists them:

| Feast | Day |
|---|---|
| *Dominica in Septuagesima* | Easter − 63 |
| *Dominica I Quadragesimæ* (*in capite Quadragesimæ*) | Easter − 42 |
| *Ascensio Domini* | Easter + 39 |
| *Pentecostes* | Easter + 49 |
| *Corpus Christi* | Easter + 60 |
| *Dominica I Adventus* | the first Sunday after 11 November (*Dominica prima post Festum sancti Martini*) |

The *Tabella temporaria* (1955–2000) is the test: all 46 years match, but one. For 1995 it
prints Advent on **19** November; the rule gives **12** November (11 November 1995 was a
Saturday), and the *Tabula paschalis perpetua*, for 1995's letter and epact, gives 12 too.
It is taken to be a misprint of the *Tabella* (the test says so).

Years after 2000, which the *Tabella* doesn't cover, are computed the same way.

### 3.2 The part of the year

Compline takes its own date's part, never the next day's (the user, question 13: the eve
of a season is still the old season).

| Part | From | To |
|---|---|---|
| *Hiemalis secunda* (Lent) | the 1st Sunday of Lent | Holy Saturday |
| *Æstiva prima* | Easter | the Saturday after Pentecost (*usque ad Octavam Pentecostes inclusive*) |
| *Æstiva secunda* | the 1st Sunday after Pentecost | the Saturday before the 1st Sunday of October |
| *Hiemalis prima* | the 1st Sunday of October | the Saturday before Lent |

*Hiemalis prima* and *æstiva secunda* print the same Compline, so their boundary changes
nothing on the page but the festal rubric's page reference.

In Holy Week nothing else changes (the user, question 14).

### 3.3 The festal form

On the festal form the *Capitulum* goes straight to *Dominus vobiscum* and *Illumina*,
without the kneeling *preces*. The parts' own rubrics (`rubrica-festiva-*`):

- *Hiemalis prima* and *æstiva secunda* (HI.6, AII.6): Solemnities of the Lord, octaves,
  Sundays, Our Lady's feasts, the Nativity of St John Baptist (24 June), Ss Peter and Paul
  (29 June); and pontifical and patronal days, which a private recitation doesn't keep.
  - Solemnities of the Lord are the *Kalendarium*'s *Sol. Dom.* ranks.
  - Octaves: Christmas's (26–31 December, each *Commem. Octavæ*) and 1 January; the
    Epiphany's days are ranked *Sol. Dom.* in the *Kalendarium* already.
  - Our Lady's feasts: 2 February, 25 March, 2 July, 16 July, 5 August, 15 August,
    8 September, 12 September, 15 September, 21 November, 8 December. Not St Anne's,
    St Joachim's or St Joseph's, whose titles name her too.
- *Hiemalis secunda* (HII.7): Sundays, St Joseph (19 March) and the Annunciation (25 March).
- *Æstiva prima* (AI.6): every day, except the *Triduum Litaniarum*.

**Unsourced:**
- **Corpus Christi** is festal, as a Solemnity of the Lord, though a fixed calendar can't
  list it.
- **St Joseph and the Annunciation in Holy Week** take the ferial form: the rubric names
  them, but they give way to the week. (Under the Ambrosian rite they may be transferred;
  the sources here don't say.)
- **The *Triduum Litaniarum*** (the Ambrosian Rogation days) is taken to be the Monday to
  Wednesday after the Sunday after the Ascension (Easter + 43 to + 45).

### 3.4 The Marian antiphon

From the antiphons' own rubrics:

| Antiphon | From | To |
|---|---|---|
| *Ave, Regina cælorum* (HI.9, AII.9) | the Nativity of Our Lady (8 September) | Christmas, exclusive |
| *Alma Redemptoris Mater* (HI.9) | Christmas | Lent, exclusive |
| *Salve, Regina* (HII.10) | the 1st Sunday of Lent | Holy Saturday; *omittitur Fer. VI in Parasceve*: none on Good Friday |
| *Regina cæli* (AI.9) | Easter | Pentecost, inclusive |
| *Inviolata* (AII.9) | the 1st Sunday after Pentecost | the Nativity of Our Lady, exclusive |

**Unsourced:** the **Monday to Saturday after Pentecost** fall between *Regina cæli*
(*usque ad Pentecost. inclusive*) and *Inviolata* (*a Dominica I post Pentecostem*). They
take *Regina cæli*, the only antiphon *æstiva prima* prints, since its Compline runs to the
Saturday after Pentecost.

The rubric *Deinde dicitur una ex seq. ant. pro ratione temporis* is printed by HI and AII
only, which have two antiphons; it is shown there only.

### 3.5 The title block

- A movable feast of §3.1 is named by the *Tabula*'s heading, written out: *Dominica in
  Septuagesima*, *Dominica I Quadragesimæ*, *Pascha*, *Ascensio Domini*, *Pentecostes*,
  *Corpus Christi*, *Dominica I Adventus* (the *Tabula* abbreviates them; expansion).
- Otherwise the *Kalendarium*'s feast, with its rank above it and its commemoration below
  (*Commem.*; a *Vigilia seq.* note is left out, as it concerns the next day).
- In Lent the *Kalendarium* is empty on weekdays but for St Joseph and the Annunciation;
  a Lenten weekday is named by its weekday.
- Otherwise the weekday: *Dominica*, *Feria II* … *Feria VI*, *Sabbato*.

**Unsourced:** on a **Sunday** the *Kalendarium*'s feast is named only if it is a Solemnity
of the Lord or of the I or II class; otherwise the day is *Dominica*. The Ambrosian
precedence of Sundays is not in these sources; this affects only the title, never the
hour, since every Sunday takes the festal form.

**Unsourced:** the weekdays of **Easter week and Pentecost week** are named by the
*Kalendarium*'s feast, if any, as on any other weekday: the sources don't give the
precedence of these octaves. It changes only the title, as all of *æstiva prima* takes
the festal form.

The day title is Latin and follows the app's spelling (§4); the date line and footer are
the app's own.

## 4. Spelling

The app's rules (the user, question 9): **I, not J** (*adiutorium*, *eius*, *Iesum*), applied
by the data tool to the corrected transcription and the calendar; the source's own accents,
none added. One result to note: *Hallelujah* becomes ***Halleluiah***, by the same rule.

## 5. Settings

- **Priest** (*Sacerdos vel diaconus adest*), the user's rulings (questions 7 and 11):
  - off: ℣. *Dominus vobiscum* ℟. *Et cum spiritu tuo* becomes ℣. *Domine, exaudi orationem
    meam* ℟. *Et clamor meus ad te veniat*, as in the Roman office;
  - off: the *Confessio* is one *Confiteor*, the hebdomadary's (with St Ambrose), without
    *et vobis, fratres* and *et vos, fratres*, then *Misereatur nostri omnipotens Deus: et,
    dimissis peccatis nostris, perducat nos ad vitam æternam.* ℟. *Amen.*, and the rest as
    printed from *Indulgentiam*. The engine builds it from the printed *Confiteor*
    (`AmbrosianCompline.withoutPriest`), so its pages stay traceable;
  - on: the choir exchange as printed, with its rubrics.
- **English** and **Psalterium** don't apply: Ambrosian Compline is Latin only (question 4),
  with its own psalter. Settings disables both under *Ambrosianus*.
- **Rubrics**: the source's red lines (`!`) and its red directions inside a line, *(secreto)*,
  *(secr.)*, *(alta voce)*, are rubrics, red when shown and left out when off.

## 6. The data

### `completorium-1957.txt`

A diplomatic transcription: the text as printed, misprints and J included. Its header
gives the format:

```
[piece]  part.page ...   a piece and every page that prints it
V. / R.                  versicle / response
R. br.                   the short responsory's response
Ant.                     antiphon
!text                    a rubric (red in the source)
^text                    a heading or reference (red in the source: "Psalmus 4.")
a * b                    a psalm verse: first half * second half
_                        a break between stanzas or paragraphs
(anything else)          a line of prose or a hymn line
(text)                   inside a line, a red direction: "(secreto)"
```

A piece printed by several parts is transcribed once, from the part that prints it
correctly, and lists every page.

### `corrections.txt`

`piece | as printed | as shown | kind | where | note`, one per line:

| Kind | Meaning | Applied |
|---|---|---|
| `misprint` | an obvious typesetting error; the reading is certain | yes |
| `doubtful` | looks wrong, but the right reading isn't certain: left as printed | no; listed for the user and Church of Ambrose |
| `expansion` | an abbreviation written out (question 10): *Kyr. kyr. kyr.*, *Gloria Patri… Sicut erat…* | yes |
| `ruling` | the user's decision where the source is silent (§5) | built by the engine |
| `witness` | another part misprints what the transcription takes correctly from a part that prints it right | nothing to apply |

The data tool checks every applied line: its "as printed" text must occur exactly once
in its piece, or the build fails.

### `kalendarium.txt`

`MM-DD | feast | rank | commemoration or note | page`: the *Menses* column, as printed
(abbreviations kept). Days the calendar leaves empty are not listed. One editorial
change: a Solemnity of the Lord printed in full (*Solemne. Dom. I cl.*) is written as
everywhere else (*Sol. Dom. I cl.*), so the rank reads the same.

### In the bundle

`BreviariumData` reads the three files (`AmbrosianSource.data`), applies the corrections
and the spelling, and stores the result as `DataBundle.ambrosian`. The engine reads only
that: never the Divinum Officium corpus.

## 7. Tests

`Tests/OracleTests/AmbrosianComplineTests.swift`. Divinum Officium can't check this office,
so the tests come from the sources:

- the data builds, and the bundle carries it unchanged;
- every correction applies exactly once; no J survives in the Latin;
- the movable feasts against the *Tabella*, 1955–2000 (with the 1995 misprint);
- the part and the Marian antiphon on chosen dates of 2026, Good Friday without one;
- the festal form on Sundays, Our Lady's feasts, Paschaltide and the *Triduum
  Litaniarum*, Lent;
- the title block;
- the shape of the hour in each part and form (sections, both hymns in Lent);
- without a priest (§5);
- **only from its source**: every unit's text, every day of 2026 with the priest on and
  off, is found in the transcription (after corrections), every piece used has its pages,
  and none of the Roman Compline's own texts appears (*Iube, domne*, *Fratres: Sobrii
  estote*, *In manus tuas, Domine*, *Tu autem, Domine, miserere nobis*, *Benedicat et
  custodiat nos*, *Noctem quietam… concedat nobis Dominus omnipotens*; texts the two share,
  *Converte nos*, *Te lucis*, Psalm 4 or Psalm 30's *In manus tuas commendo*, are not
  listed).
