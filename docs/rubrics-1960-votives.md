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

DO omits the Martyrology on some days (*Martyrologium{omittitur}*, e.g. Holy Saturday);
which days, and what the app shows then, is settled in B4-M4 against the Prime fixtures.

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
