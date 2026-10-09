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
| *Missale Ambrosianum*, Milan: Daverio, 1954 (*editio quinta post typicam*), front matter pp. I–XLVIII (Church of Ambrose's scans, received 9 and 10 October 2026) | the *Kalendarium* (pp. XV–XVIII), the *Tabula paschalis perpetua* and *Tabella temporaria* 1955–2000, the *Series Missarum* (pp. X–XI: the names of the Sundays and days of the season), the *Rubricæ generales Missalis* (§§ 1–3: occurrence; §§ 38–43: colours) | `data/ambrosian/kalendarium.txt` (the *Menses* column); the scans are not committed |

Both are used with the owners' permission (`NOTICE.md`; the About screen says so).

The calendar and its rules are the **Missal's** of 1954, not the 1957 breviary's: the
first scans arrived as "Rubricae Generales" pages, and only the whole scan's title page
showed which book they are. The Missal's first rule is that *Missa … debet cum Officio diei
convenire*, so its occurrence rules are the Office's; but the breviary of three years later
could differ in a feast or a rank, and only its own calendar would show that.

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

The form follows the office the day keeps (§3.5): a feast moved to a Monday brings its
form with it, and one a privileged day impedes doesn't.

- **Corpus Christi** is festal: the *Series Missarum* calls it *In Solemnitate SS.
  Corporis Christi*, a Solemnity. Its **octave** (the rubric on red, § 40: *in Solemnitate
  Corporis Domini, et per Octavam*) is festal too, as an octave.
- **St Joseph and the Annunciation in Holy Week** are not kept: Holy Week is privileged
  (*Feriæ Hebdomadæ in Authentica … numquam fit de Sancto*, § 3), so the day is ferial.
- **The *Triduum Litaniarum*** is the Monday to Wednesday after the Sunday after the
  Ascension: the *Series Missarum* has *Dominica post Ascensionem*, then *Die primo,
  secundo, tertio in Litaniis*.
- **Unsourced:** the **Sacred Heart** and the **Holy Family** take the ferial form: the
  *Series Missarum* calls them *Festum*, not *Solemnitas*, and the rubric names only
  Solemnities of the Lord.

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

### 3.5 The office of the day

`AmbrosianCalendar.office`, by the Missal's *Rubricæ generales*:

- **The season** (*Proprium de Tempore*): every Sunday and day of the season is named as
  the *Series Missarum* names its Mass (pp. X–XI). The Sundays: *Dominica I–VI Adventus*;
  *post Nativitatem Domini*; *I–V post Epiphaniam*, and *VI post Epiphaniam* always on the
  Sunday before Septuagesima (*Missa quæ semper celebratur Dominica Septuagesimam proxime
  præcedente*); *in Septuagesima*, *in Sexagesima*, *in Quinquagesima*, *in Quadragesima*;
  *II–V Quadragesimæ: de Samaritana, de Abraham, de Cæco, de Lazaro*; *Palmarum*; *Pascha*;
  *I post Pascha, in Albis depositis*; *II–V post Pascha*; *post Ascensionem*; *Pentecostes*;
  *I post Pentecosten: SS. Trinitatis*; *II–XV post Pentecosten* until 29 August; *I–V
  post Decollationem*; *I* and *II Octobris*; *III Octobris: in Dedicatione Ecclesiæ
  Maioris*; *ultima Octobris: in Festo D. N. Iesu Christi Regis*; *I–III post
  Dedicationem* (counted with Christ the King's Sunday among them: only that count reaches
  the *Series*' third). The days: the weeks of Lent (*Feria II hebdomadæ I Quadragesimæ*),
  *Sabbato in traditione Symboli*, *Feria II–IV in Authentica*, *Feria V in Cœna Domini*,
  *Feria VI in Parasceve*, *Sabbato Sancto*, *Feria II … Sabbato in Albis*, the vigils, the
  three days *in Litaniis*, *Solemnitas SS. Corporis Christi*, *Festum SS. Cordis Iesu*
  (the Friday after its octave), *Festum S. Familiæ Iesu, Mariæ, Ioseph* (the Monday after
  the 3rd Sunday after the Epiphany).
- **Sundays** (§ 2): *De Dominica Officium et Missa numquam prætermittuntur*. Only a
  *Solemnitas Domini, non tamen Octava*, takes a Sunday, *cum commemoratione Dominicæ, quæ
  omittitur in Solemnitatibus Domini primæ classis*. And St Joseph on a Sunday of Lent is
  kept: the rubric on violet (§ 42) has *in Dominicis Quadragesimæ (nisi Festum S. Ioseph …
  occurrerit)*.
- **A saint on a Sunday** moves to the Monday (§ 2: *in feriam secundam immediate
  sequentem transferuntur officio paris ritus non impeditam*), unless the Monday has a
  feast of the same rank or higher, which impedes it. The ranks, highest first: *Sol. Dom.*
  I class, II class, plain; *Sol.* I class, II class, *maius*, plain; *Privil.*; then
  feasts with no rank (§ 1: *de Solemnitate Domini; vel Dominica; de Festo Solemni, vel
  Proprio … vel Simplici*).
- **Privileged days** (§ 3) keep no saint: *Feria sexta et Sabbatum quartæ et quintæ
  Hebdomadæ Adventus; Feria de Exceptato; Sabbato in Traditione Symboli; Feriæ Hebdomadæ in
  Authentica, et Triduum Litaniarum*, and the vigils of Christmas, the Epiphany and
  Pentecost. (The *Kalendarium* lists nothing on 15–23 December, so the days *de Exceptato*
  need no rule of their own.) Nor do the movable solemnities.
- **Lent**: the *Kalendarium* lists no saint in March but St Joseph and the Annunciation,
  and moves the Chair of St Peter at Antioch to 4 February when 22 February is in Lent
  (*Si Festum incidat in Quadragesimam, celebratur die 4 huius*); no other saint is kept on
  a day of Lent.
- **St Ambrose's Deposition** (4 April) is never kept on its date: *cuius commem. semper
  fit Feria V in Albis*, a commemoration on the Thursday of Easter week.

**Unsourced:**
- **Easter week** keeps no saint: it has its own Masses (*pro Baptizatis*, *de Octava*), but
  § 3 doesn't list it among the privileged days.
- The weekdays of **Pentecost week** and of **Corpus Christi's octave** keep their saints
  (§ 3 doesn't privilege them), and are named *… infra Octavam* when they have none.
- A **lower feast** on the Monday a Sunday's saint moves to is commemorated; an impeded one
  is not said at all; a saint on the day of the Holy Family or the Sacred Heart is
  commemorated.
- A **Sunday from 2 to 5 January** is named *Dominica post Nativitatem Domini*.
- § 3 read literally lets a **privileged day impede an I class feast**: the Immaculate
  Conception falls on the Friday of the 4th week of Advent when Advent begins on
  12 November (2023, 2028), and is then not kept. The breviary's rubrics may give way to
  such a feast; these don't say.

### 3.6 The title block

The office's name (§3.5), with the feast's rank above it and its commemorations below:
the *Kalendarium*'s own (*Commem.*; a *Vigilia seq.* note is left out, as it concerns the
next day), the Sunday's when a Solemnity takes it, and a lower feast's on the Monday.

### 3.7 The colour

*Jump to date* shows the colour of the office kept (§3.5), by the Missal's rubrics *De
coloribus paramentorum* (§§ 38–43):

| Colour | The season | Feasts |
|---|---|---|
| White | from the vigil of Christmas to the octave of the Epiphany; from Holy Saturday to the Sunday *in Albis depositis*, exclusive; the vigil and day of the Ascension; the Holy Trinity; the Dedication; the 6th Sunday of Advent (*Missus est*) | Solemnities of the Lord not red; Our Lady; the Angels; St John Baptist's Nativity; St Joseph; All Saints; St John the Evangelist; the Conversion of St Paul; both Chairs of St Peter; the Elevation of Ss Ambrose, Protasius and Gervasius; confessors, doctors, popes and bishops; virgins not martyrs; dedications |
| Red | from the vigil of Pentecost to its octave; the Sundays and weekdays after Pentecost to the Dedication of the cathedral; Corpus Christi and its octave; from the Saturday *in traditione Symboli* to Holy Saturday | the Circumcision; the Sacred Heart; the Holy Cross; the Beheading of St John; apostles and evangelists; the Holy Innocents; martyrs |
| Green | after the octave of the Epiphany to Septuagesima; after the Sunday *in Albis depositis* to the vigil of Pentecost; after the Dedication to Advent | abbots, St Anthony |
| Violet | Advent; Septuagesima to Lent; the Sundays of Lent; vigils | matrons |
| Black | the weekdays of Lent to the Saturday *in traditione Symboli*; the *Triduum Litaniarum* | the dead |

The feast's kind is read from its title in the *Kalendarium* (*Mart.*, *Mm.*, *Apost.*,
*Abb.*, *Matronæ*, *Virg.*, *Conf.*, *B. M. V.* …), with the named exceptions by date.
Unsourced: St Anne and St Joachim, *Matris* and *Patris B. M. V.*, are white; a feast whose
title says none of these takes the season's colour.

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
