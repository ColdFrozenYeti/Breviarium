# The Little Office, the Office of the Dead and the Martyrology: how Divinum Officium builds them

Beta 4, milestone B4-M1. Read at the pinned commit (`data/SOURCE.md`) and checked against
DO's renders of 16 September 2026 (`votive=C12` and `votive=C9`, every hour) and the Prime
fixtures. Paths are under `web/cgi-bin/horas/` unless given in full.

## 1. The two votive offices are ordinary hours with another winner

DO has no separate code path for either office. `officium.pl` takes `votive=C12` or
`votive=C9`, and `horascommon.pl:1770-1830` swaps the day's winner for the votive's Commune
after occurrence has run:

- **The winner** becomes `Commune/<votive>.txt`; `$rule` and `$rank` are read from it
  (`C12`: IV class, *Officium parvum Beatæ Mariæ Virginis*; `C9`: I class, *Officium
  Defunctorum*). The page title is the votive's own (`[Officium]`), with no line under it.
- **The Little Office's season** (`:1774-1785`) picks the file:
  | File | When |
  |---|---|
  | `C12N` | Christmas Eve's Vespers and Compline, 25 December to 2 February |
  | `C12A` | Advent, and the Annunciation (the winner is `03-25`) |
  | `C12Q` | Septuagesima to Easter (`Quadp`, `Quad`) |
  | `C12` | the rest of the year |

  `C12N` and `C12Q` inherit `C12` (`@Commune/C12`) and change a few antiphons and the
  *Te Deum*. The Commune of the Little Office is `C11` (Our Lady's feasts), `ex`.
- **The Office of the Dead** keeps the day's winner as its (never shown) commemoration and
  takes `C9` as winner, with no Commune.
- Everything else runs unchanged: the conditionals (`tempore`, `feria`), the psalter
  option, the priest option, the English.

So the engine's work is to let `HourAssembler` take the votive winner for any date, and to
follow the rules the two Communes carry.

## 2. The Little Office of Our Lady (`Commune/C12`)

`[Rule]`: *ex C11; Ave only; Doxology=Nat; Omit Suffragium mute; Special Benedictio;
Votive nocturn; Psalmi Dominica; Antiphonas horas; Feria Te Deum*, and *(sed tempore post
septuagesimam) no Te Deum*.

| Hour | As DO renders it (16 September 2026) |
|---|---|
| Matins | Incipit; invitatory *Ave María, grátia plena* (*Ave only*); hymn *Quem terra*; one nocturn (*Votive nocturn*: three psalms by weekday, 95–97 on Wednesday); versicle; *Pater* secreto; three blessings (*Nos cum prole pia* …, `Special Benedictio`); three lessons from Sirach 24; the *Te Deum* outside Septuagesima; collect; conclusion |
| Lauds | Incipit; five psalms (Sunday's, 92 99 62 Benedicite 148) under five Marian antiphons; chapter, hymn *O gloriósa vírginum*, versicle; Benedictus antiphon; collect; conclusion. No preces, no suffrage |
| Prime, Terce, Sext, None | Incipit; hymn *Meménto, rerum Cónditor* with the Marian doxology; three psalms under one antiphon; chapter and versicle (no short responsory); collect; conclusion |
| Vespers | as Lauds, with Vespers' psalms and the Magnificat |
| Compline | as the day's Compline in shape, with the Marian hymn, chapter and final antiphon |

## 3. The Office of the Dead (`Commune/C9`)

`[Rule]`: *Psalmi Dominica; Antiphonas horas; Capitulum Versum 2 ad Laudes et Vesperas;
Omit Incipit Hymnus Capitulum Lectio Preces Capitulum Commemoratio Suffragium; Special
Conclusio; Limit Benedictiones Oratio; Requiem gloria; Votive nocturn; 9 lectiones*.

Only Matins, Lauds and Vespers exist (`dialogcommon.pl:54-60`, `@horas[0, 1, 6]`).

| Hour | As DO renders it |
|---|---|
| Matins | no Incipit; invitatory *Regem, cui ómnia vivunt*; no hymn; three nocturns of three psalms (5–7, 22–26, 39–41) with their versicles; *Pater* secreto; nine lessons from Job, no blessings (*Limit Benedictiones*); no *Te Deum*; *Pater noster* and the collect; *Requiem* conclusion |
| Lauds | no Incipit; psalms 50, 64, 62, the Canticle of Ezechias, 150; *Audívi vocem* in place of the chapter; Benedictus antiphon *Ego sum*; *Pater noster*, collect; *Requiem* conclusion |
| Vespers | no Incipit; psalms 114, 119, 120, 129, 137; *Audívi vocem*; Magnificat antiphon *Omne quod dat mihi Pater*; *Pater noster*, collect; *Requiem* conclusion |

*Requiem gloria*: every psalm ends with *Réquiem ætérnam … Et lux perpétua* in place of the
*Glória Patri*. The engine already renders all of this on All Souls, where `C9` wins the
day; Beta 4 makes it available on any date.

## 4. The Martyrology (`specials/specprima.pl:137-200`)

DO reads it as a section of Prime (`#Martyrologium` in `Ordinarium/Prima.txt`), marked
*anticipatur*: the entry is the **next day's** (`nextday`), from `Martyrologium1960/MM-DD.txt`.

1. The first line of the file is the date in the Roman calendar (*Quintodécimo Kaléndas
   Octóbris*), to which DO adds the moon's age (*Luna quinta*, `_luna`, from the golden
   number and the Martyrology's lunar letters, `_luna_table`).
2. After it, *Anno Dómini 2026*.
3. If the day has a movable entry (`Mobile.txt`, keyed by week and weekday; `Defuncti` when
   the winner is the Dead's), it replaces the first `_` in the file.
4. Then the entries, one per line, and the conclusion (`Conclmart`: *Et álibi aliórum
   plurimórum …* with *Deo grátias*).

DO omits the Martyrology where the office's rule says *Omit … Martyrologium*
(`specials.pl:83-96`): the three days of the Triduum, whose Prime fixtures show
*Martyrologium{omittitur}*. The app then shows the red rubric *Martyrologium omittitur.*
under the heading (B4-M4). The date announced comes from tomorrow's `get_sday` key, so
the leap day reads `02-29`; the moon's age is DO's `_luna_table`, ported exactly; a
`/: … :/` line is a rubric, and Christmas's inline *Hic vox elevatur…* an inline rubric.

**English**: none for the 1960 Martyrology; the app shows it in Latin only (decision 3).

## 5. Headings the app will show

- **The Little Office**: the day office's headings (INTRODUCTIO, INVITATORIUM, HYMNUS,
  AD NOCTURNUM, PSALMODIA, CAPITULUM, CANTICUM, ORATIO, CONCLUSIO …); the title block
  shows *Officium parvum Beatæ Mariæ Virginis*.
- **The Office of the Dead**: the same, without INTRODUCTIO and HYMNUS (they're omitted);
  the versicle *Audívi vocem* under VERSUS; *Officium defunctorum* in the title.
- **The Martyrology**: the title *Martyrologium*, the hour title *Martyrologium*, and one
  section, MARTYROLOGIUM, holding the date line (as a rubric-free heading line), the
  entries as prose paragraphs, and the conclusion.

## 6. How it's checked

- The two votives: new fixtures (`votive=C12` every hour of 2026 and 2027; `votive=C9`
  Matins, Lauds and Vespers of 2026; 2044 as hold-out; both psalters), audited like every
  other hour.
- The Martyrology: the Martyrology section of every Prime fixture, 2025–2040 and 2044.

## 7. What the engine had to add (B4-M3, B4-M4)

Found against the fixtures, each cited to the pinned commit:

- **The swap follows concurrence.** At Vespers and Compline DO swaps the votive in after
  concurrence, so on the eve of a Sunday of Advent or of the Annunciation the Little
  Office already takes that form, and `$vespera` stays.
- **The Little Office's Commune is always `C11` (`ex`)**, `C12N` included, whose own
  `[Rank]` names none; and on Our Lady's own feasts (the day's Commune is `C11`) *no Te
  Deum* becomes *Feria Te Deum* (the Purification after Septuagesima, the Annunciation).
- **`C9` has no `[Rank]`.** It keeps the day's rank, raised to 6 below 3, is its own
  Commune, always has three nocturns (`gettype1960` skips it), and reads its ninth
  responsory from `Responsory91`.
- **The season still counts where DO reads `$dayname[0]`**: the suppressed and bracketed
  alleluias, *Benedicamus Domino, allelúia, allelúia* in the Easter octave, the Passiontide
  *Gloria omittitur*, and the Greater Litanies (for the Office of the Dead only, from the
  day's office it keeps as a commemoration, and in April). What `alleluia_required`
  decides (the added alleluias) stays excluded.
- **The Office of the Dead's *Requiem* comes before the Triduum's *Gloria omittitur***
  (`horas.pl:297-311`).
- **Small ones**: the Little Office's own `[Capitulum Vespera]` at Vespers
  (`capitulis.pl:13`); Perl's `\u` in a substitution (the English `C12` responsory); the
  special hours' `#` headings as section kinds; inline alleluias in special hours.
- **On All Souls** DO renders the Office of the Dead chosen as the office differently
  from the day's own office: `C9`'s lessons from Job 10 and 13 against All Souls' own,
  and the plain conclusion against *Conclusio specialis*. The engine follows DO in both.

## 8. The colour dot (B4-M4)

The day's own office's colour, DO's `liturgical_color` on its title, checked against the
colour DO gives the title on its own Lauds page for seven dates. Two changes for the
calendar: Our Lady's feasts, which DO marks blue, show white, their liturgical colour;
and Gaudete and Laetare Sundays, violet in DO, show rose.
