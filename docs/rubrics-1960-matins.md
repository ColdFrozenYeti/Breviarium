# Matins under the 1960 rubrics: how Divinum Officium builds it

B3-M1 (Beta 3). This describes how Divinum Officium (DO) builds *Ad Matutinum* under
`Rubrics 1960 - 1960`, cited to the pinned commit (`data/SOURCE.md`). It also records the
section headings and typography this project uses for it. It is the engine's reference
in the same way as [`rubrics-1960-vespers.md`](rubrics-1960-vespers.md) and
[`rubrics-1960-day-hours.md`](rubrics-1960-day-hours.md).

- Paths under `cgi-bin/` are `web/cgi-bin/horas/`.
- Paths under `horas/` are `web/www/horas/Latin/` (the Vulgate) or `Latin-Bea/` (Pius XII
  psalms only).
- Examples are DO's own renders (`prayMatutinum`, priest off) for 25 September 2026
  (Ember Friday), 16 September 2026 (Ss. Cornelius and Cyprian, III class), 27 September
  2026 (a Sunday after Pentecost), 25 December 2026 and 3 April 2026 (Good Friday).

## 1. The skeleton

`horas/Ordinarium/Matutinum.txt`, walked by `specials.pl` like every other hour.
Under 1960 the parts in effect are:

| DO group | What it holds under 1960 | Filled by |
|---|---|---|
| `#Incipit` | *Dómine, lábia mea apéries* and its response, *Deus in adiutórium*, *Glória Patri*, *Allelúia* / *Laus tibi*. The *Pater*, *Ave* and *Credo* said in secret are omitted in 1960 (`(sed rubrica 196 … omittuntur)`). | the skeleton and its macros |
| `#Invitatorium` | Psalm 94 with its antiphon | `specials.pl:165-180` → `invitatorium` (`specmatins.pl:26-148`) |
| `#Hymnus` | the hymn | `hymnusmatutinum` (`specmatins.pl:152-203`) |
| `#Psalmi cum lectionibus` | the nocturns: psalms, versicle, *Pater noster*, absolution, blessings, lessons, responsories, and the *Te Deum* | `psalmi_matutinum` (`specmatins.pl:236-465`) → `nocturn`, `lectiones`, `lectio` |
| `$rubrica Matutinum` | *Reliqua omittuntur, nisi Laudes separandæ sint.* (a rubric) | `Psalterium/Common/Rubricae.txt:[Matutinum]` |
| `#Oratio` | the collect of the day, as at Lauds | `orationes.pl`, index 0 (`specials.pl:574`) |
| `#Conclusio` | *Dómine, exáudi* (or *Dóminus vobíscum*), *Benedicámus Dómino*, *Fidélium ánimæ* | the skeleton |

**Which day:** Matins follows the day's own occurrence, like Lauds (`Occurrence`, not
`Concurrence`). The chosen date's own Matins is shown, with no anticipation (Beta 3,
decision 2).

**The Triduum** (3 April 2026): the rules of `Tempora/Quad6-4`, `6-5` and `6-6`
remove the Incipit, the invitatory, the hymn, the blessings, the Gloria and the
Conclusio (DO prints `{omittitur}`). The absolutions go too: *Pater noster dicitur totum
secreto* replaces them. The psalms and antiphons come from the proper. No office in the
1960 corpus has a whole-hour `[Special Matutinum]`, so there is no equivalent of the
day hours' `assembleSpecialHour` for Matins.

## 2. The 1960 lesson types (`gettype1960`, `specmatins.pl:1455-1487`)

| Type | When (`$version =~ /196/`) | Matins |
|---|---|---|
| `LT1960_OCTAVEII` | `$dayname[1] =~ /post Nativitatem/` | one nocturn, three lessons (Christmas octave days) |
| `LT1960_FERIAL` | rank below 2, or the day's name contains *feria*, *vigilia* or *die* | one nocturn of nine psalms, three lessons |
| `LT1960_SUNDAY` | a *Dominica … semiduplex*, or `Pasc1-0` | one nocturn of nine psalms, three lessons: two of Scripture, contracted, then the homily |
| `LT1960_SANCTORAL` | rank below 5 (III class feasts) | one nocturn of nine psalms, three lessons: two of Scripture, then the saint's |
| `LT1960_DEFAULT` | everything else (I and II class feasts), or `9 lectiones 1960` in the rule | three nocturns of three psalms and three lessons each |

`psalmi_matutinum` builds three nocturns only when the rule says `9 lectio` **and** the
type is `DEFAULT` and the rank is at least 2 (`:331-366`). Otherwise it builds the single
nocturn (`:368-464`).
- **Nine psalms** (`@psalmi > 9`): indices 0–2, 5–7 and 10–12 of the day's psalm list,
  with the versicle at 13–14 (`Ord Versus per annum`).
- **Paschaltide ferias** take three psalms instead.

## 3. The invitatory (`specmatins.pl:26-148`)

- **The antiphon.**
  - The office's own `[Invit]` if it has one (`getproprium("Invit")`).
  - Otherwise `Psalterium/Special/Matutinum Special.txt:[Invit]`, line `$dayofweek`. Line
    7 is Sunday's from January to March and from the Sundays after Pentecost numbered
    1xx (`:47`).
  - Or a seasonal set: `gettempora('Invitatorium')` gives `Invit Adv`, `Quad`, `Quad5`,
    `Pasch` and so on.
- **The antiphon is split at `*`:** `$ant` is the whole, and `$ant2` the part after the
  `*` (*Veníte, adorémus*).
- **The psalm:** `Psalterium/Invitatorium.txt`, or `Latin-Bea/` with the Pius XII
  psalter. Five strophes, with `$ant`/`$ant2` between them and `&Gloria` near the end.
  - Marks: `+ * ^ = _` are strophe-division marks, removed (`:139`). `/:(genuflectitur):/`
    is an inline rubric.
  - Variants: `Invit2` (only the first half of the antiphon, the Sundays of
    Septuagesima), `Quad5-6` Passiontide (no *Gloria*, `&Gloria2`), and Mondays after
    Epiphany and Pentecost (`:117-122`).
- **No invitatory:** the Triduum (`{omittitur}`), and the Epiphany, whose rule omits it.

## 4. The hymn (`specmatins.pl:152-203`)

- The office's own `[Hymnus Matutinum]` first. `hymnshift` and `hymnmerge` handle a
  first-Vespers hymn displaced by concurrence, as at Vespers.
- **Otherwise the psalter's hymn:**
  - `Matutinum Special.txt:[Day<n> Hymnus]`;
  - `[Day0 Hymnus1]` on Sundays from January to March and after Pentecost (`:185-194`);
  - or the season's (`[Hymnus Adv]`, `Quad`, `Quad5`, `Pasch`).
- Doxology and alleluia handling are shared with the other hours.

## 5. The psalms (`psalmi_matutinum`, `nocturn`)

- **Source:** `Psalterium/Psalmi/Psalmi matutinum.txt:[Day<dow>]`. Fifteen lines per
  day: three nocturns of three `antiphon;;psalm` lines each, plus a versicle pair.
  - Advent Sundays use `[Adv 0 Ant Matutinum]` (`:249-255`).
  - The office's own `[Ant Matutinum]` replaces the list (`getantmatutinum`,
    `:1820-1864`). A short proper list is filled out with `Nocturn <n> Versum` lines.
- **Seasonal versicles:** Advent, Lent, Passiontide and Paschaltide replace them from
  `[<Season> <n> Versum]` (`:264-278`, `:343-357`).
- **Paschaltide** (`ant_matutinum_paschal`, `:1562-1609`): one alleluia antiphon over
  each nocturn's psalms on ferias. On Paschaltide Sundays, 1960 puts one antiphon over
  the whole nocturn.
- **Rendering** (`nocturn`, `:205-234`):
  - the heading `Nocturnus I…III`, or `Ad Nocturnum` for the single nocturn;
  - then `antetpsalm`, the same machinery as the day hours' psalms, with 1960
    `$duplexf`, so antiphons are said whole before and after;
  - then the versicle and response. The versicle takes one alleluia in Paschaltide.

## 6. Before the lessons (`lectiones`, `specmatins.pl:659-699`)

For each nocturn:
- **The rubric** *Pater noster dicitur secreto usque ad Et ne nos indúcas in
  tentatiónem*, then the *Pater noster* with its last clause aloud (`$Pater noster Et`).
- **The absolution:** `Absolutio.` plus one of `Benedictions.txt:[Absolutiones]`,
  answered *Amen*. For the single nocturn it is chosen by `dayofweek2i` (`:497-657`).
- **Without absolution** (the Triduum, `Limit … Benedictio`): *Pater noster dicitur totum
  secreto* instead.
- **Before each lesson:** *Iube, Dómine, benedícere* (the `Jube domne` prayer), then
  `Benedictio.` plus the blessing, answered *Amen*.

**The blessings** (`get_absolutio_et_benedictiones`):
- **Nine lessons:** `[Nocturn 1]`, `[Nocturn 2]` and `[Nocturn 3]`.
  - In the third nocturn the first blessing is *Evangélica léctio* (`[Evangelica]`).
  - Christmas has its own (`[Nocturn 3 12-25]`).
  - On a saint's feast the second blessing of the third nocturn is *Cuius / Quorum /
    Cuius … ipsa festum cólimus*, chosen by `cujus_q` from the rank.
  - If lesson 9 is a Gospel, its blessing becomes `[Evangelica9]`.
- **Three lessons:** `[Nocturn 3]`, except:
  - **Vigils, Ember days, Ash Wednesday, the Lenten ferias and some octave days**
    (their lesson 1 is a homily): lesson 1 takes the *Evangelica* blessing.
  - **Sundays:** lesson 3 takes the *Evangelica9* blessing.
  - **Saints:** lesson 2 takes the *Cuius festum* blessing.
  - **Other ferias:** `[Nocturn <dayofweek2i>]`.

**The priest toggle doesn't change any of this.** *Iube, Dómine* and the blessings are
the same text with the priest on or off. B3-M2's priest-on 2044 hold-out checks it.

**The labels.** DO prints the words *Absolutio.* and *Benedictio.* before the text. They
are labels, not liturgical text. After Beta 2's phone test the app shows no
*Benedictio*/*Absolutio* labels in the office, so the engine drops them here too, as
`unitsFromLines` already does.

## 7. The lessons (`lectio`, `specmatins.pl:726-1375`)

`lectio($num)` picks the text of each lesson. For the 1960 Roman office:

1. **The 1960 diversions** (`:731-755`):
   - on a `SUNDAY`, lesson 3 is the office's lesson 7 (the Gospel and homily);
   - on a `SANCTORAL` day, lesson 3 is the office's lesson 4 (the saint's legend).
2. **The Christmas octave's first nocturn** (`Lectio1 OctNat/TempNat`, `:780-813`): from
   the Nativity or `Tempora/Nat<dd>`.
3. **`scriptura1960`** (`:831-848`): lessons 1–2 come from the occurring Scripture, with
   2 and 3 joined.
4. **The initia tables** (`:851-859`): `Tabulae/Stransfer/<letter|easter>.txt` (loaded by
   `load_stransfer`, `Directorium.pm:191-196`) moves a displaced book's opening lessons
   ("Incipit liber …").
   - It is keyed by the Sunday letter and Easter date, like the `Transfer` tables the
     engine already reads.
   - `resolveitable` and `tferifile` (`:1624-1745`) place the transferred lessons before
     or after the day's own, per the entry's `~A`, `~B` or `~R` suffix.
5. **`StJamesRule`** (`:861-870`): 1 and 6 May.
6. **The office's own `Lectio<n>`.** Otherwise the commune's, when the office is *ex
   Commune* (`:915-946`). Otherwise **the occurring Scripture** (`%scriptura`,
   `:949-976`): the temporal office of the day, which `horascommon.pl:622-659` records
   as `$scriptura` whenever a saint wins and the Tempora has its own lessons.
7. **The 1960 contraction** (`contract_scripture`, `:1797-1818`). On `SANCTORAL` and
   `SUNDAY` days (and in Our Lady's office on Saturday, C10), lesson 2 is lessons 2 and 3
   joined, with the `_` separator removed. The responsory is then the office's third
   (`contract_scripture($num, 1)`).
8. **The saint's legend on a III class feast** (`:1215-1234`): `Lectio94` if the office
   has a contracted legend, otherwise lessons 4, 5, 6… joined until the next `!`
   heading.
9. **Then:**
   - `¶` marks and a stray `&teDeum` are removed;
   - *Tu autem, Dómine, miserére nobis* / *Deo grátias* is appended (`$Tu autem`);
   - so is the responsory, unless the *Te Deum* takes its place;
   - verse numbers in Scripture lessons are printed small (`:1320-1340`);
   - the heading `Lectio <n>` is printed first.

**The lesson's opening lines.** Scripture lessons start with DO's `!` lines:
- the book's heading (*De libro Iob*, *Incipit liber Iudith*, *De Lamentatióne
  Ieremíæ Prophétæ*);
- and the reference (`Iob 31:1-6`).

Homilies start with:
- the Gospel heading (*Léctio sancti Evangélii secúndum Lucam*) and reference;
- the Gospel's opening words ending *Et réliqua*;
- then the author (*Homilía sancti Gregórii Papæ*) and the source (*Homilia 33 in
  Evangelia*).

## 8. The responsories and the Te Deum

- **Where it comes from** (`:1246-1313`): `Responsory<n>`, or `Responsory<n> 1960` when
  the office has one. It is taken from the office, then the occurring Scripture
  (`Responsory Feria`, `scriptura1960`), then the commune.
- **Its form** (DO's text): `R.` respond `*` second half / `V.` verse / `R.` the second
  half repeated.
- **Paschaltide:** `matins_lectio_responsory_alleluia` keeps exactly one alleluia on the
  respond, the verse and the repeat.
- **The Gloria** (`responsory_gloria`, `:1489-1560`):
  - The last responsory of each nocturn gets `&Gloria1` (*Glória Patri, et Fílio, et
    Spirítui Sancto*, with no *Sicut erat*) and the repeat again. So does the one before
    the *Te Deum* (`$num % 3 == 2 && tedeum_required($num + 1)`).
  - It's omitted on Advent I and Easter Sunday for responsory 1, and under `requiem
    Gloria`.
  - It's removed everywhere else (`s/.\&Gloria.*//s`).
- **The *Te Deum*** (`tedeum_required`, `:1405-1438`):
  - When: after the last lesson (9, or 3 when there is one nocturn); not in Advent or
    Lent's temporal offices, nor on vigils or ferias; yes on Sundays, saints' days,
    Paschaltide, the Christmas season, and temporal feasts above rank 5.
  - It replaces that lesson's responsory (`&teDeum`, `Psalterium/Common/Prayers`), and
    the responsory before it gets the Gloria.

## 9. Section headings and typography (as built, B3-M4)

**Sections** (`Section.Kind`, all capitals like the other hours):

| Heading | Holds |
|---|---|
| INTRODUCTIO | the Incipit (as at the other hours) |
| INVITATORIUM | Psalm 94 with its antiphon |
| HYMNUS | the hymn |
| NOCTURNUS I, II, III, or AD NOCTURNUM for the single nocturn | its psalms and versicle, the *Pater*, absolution, blessings, lessons and responsories |
| TE DEUM | the *Te Deum*, when said |
| ORATIO | the collect |
| CONCLUSIO | the conclusion |

The table of contents lists these sections. **Lessons are not sections** (decision 4):
each starts with a smaller grey italic line, *Lectio i* … *Lectio ix*, the psalm-title
style, marked keep-with-next.

**Units.** The engine reuses the existing units wherever it can; one is new.

| Element | Unit and treatment |
|---|---|
| Invitatory antiphon (whole or half) | `.antiphon`, as at the other hours; no psalm separator between its repeats |
| Invitatory psalm strophes | `.prose`, one paragraph per strophe; `(genuflectitur)` stays inline |
| Nocturn psalms, antiphons, versicle | as at the other hours |
| *Pater noster* rubrics, *Reliqua omittuntur …* | `.rubric` (red, hidden with rubrics off) |
| *Pater noster*, absolution, *Iube, Dómine*, blessing | `.versicleResponse`: the response italic and indented; no labels |
| *Lectio i* | `.psalmTitle` (grey italic, keep-with-next) |
| Lesson heading and reference | `.psalmTitle`, reference above the text |
| Lesson text | **new `.lesson`**: its verses run on as one prose paragraph (verse numbers dropped, each verse capitalised as DO sets it); one unit per `_` paragraph |
| *Tu autem* / *Deo grátias* | `.versicleResponse` |
| Responsory | the respond is a `.verse` (its `*` half-split), each `V.`/`R.` a `.versicleResponse`, the *Glória Patri* likewise. Responsory verses don't alternate italic as psalm verses do. |
| *Te Deum* | `.verse` lines with DO's half-verse breaks |

**English on:** lessons are stacked in portrait (Latin then English) and side by side in
landscape, like the chapter and collect. Responsories, antiphons and versicles are paired.

## 10. The title block's third line (as built)

DO heads each hour with `$officename[0] ~ $officename[1]` and, when there is one,
`$officename[2]` (`horascommon.pl:536-800`, cleaned up at `:1680-1736`). The app shows it
under the day's name. What DO puts there **depends on the hour**:

| Hour | 16 September 2026 |
|---|---|
| Matins | *Tempora: Feria Quarta infra Hebdomadam XVI post Octavam Pentecostes II. Septembris* |
| Lauds to None | *Commemoratio ad Laudes tantum: Ss. Euphemiæ, Luciæ et Geminiani Martyrum* |
| Vespers, Compline | (none) |

`LiturgicalCalendarEngine.headLine(for:day:month:year:)` ports the 1960 branches:
- a saint wins: the season commemorated (`Commemoratio: …`, *ad Laudes & Matutinum* on
  Rogation Monday and the Ascension vigil, *ad Laudes tantum* in the September Ember
  days), else the next saint (*ad Laudes tantum* below I class), else a feast moved away
  (`Transfer: …`), else the saint's own `[Commemoratio]`; then, at Matins or when nothing
  else is said, `Tempora: …`, with *Scriptura ut in …* at Matins when the initia table
  moves the Scripture (12 January 2030);
- the season wins: the saint (`climit1960`, *ad Laudes tantum* or *ad Missam tantum*),
  else the next saint, else `Transfer: …`;
- the clean-up: *Tempora none*, *No Sunday commemoratio*, two *Festum Domini*, the
  28 June vigil on a Sunday; then `Scriptura: …` for Our Lady on Saturday.

**Vespers and Compline show none.** DO's line there is its concurrence note, and at
Compline it sometimes leaves the morning's *Scriptura: …* (18 April 2026 shows the
Saturday's Scripture under the next day's Sunday title). This is a deliberate difference
from DO's page head, not from its office.

`dayHoursFullRangeHeadLineAudit` checks the line against every fixture's page head, Matins
to None, 2025–2040: zero differences.

## 11. Data the engine needs

Everything under `horas/Latin/{Tempora,Sancti,Commune,Psalterium}` was already bundled.
**New in Beta 3:**
- the `Tabulae/Stransfer/*.txt` initia tables, read like `Tabulae/Transfer` and kept in the
  same map under an `S:` prefix (`SanctoralCalendar.scriptureTransfer`). Under the 1960
  rubrics they hold one entry that matters, `01-12=Epi1-0a` in letter-`f` years;
- the few Monastic and Dominican files that Roman offices borrow from
  (`@SanctiM/01-06:AntMatutinumM:2` for the Baptism of the Lord, and 14 others, found by
  following references at build time). A reference to one that doesn't exist falls back
  to the Roman file, as DO's `checklatinfile` does (`@TemporaM/Pent01-3` on 6 July 2026).

## 12. Porting notes found by the audit

The audit found these, each now ported and cited in the code:
- an `@`-inclusion's `s///` applies to the included section's *raw* text, before its own
  `@` lines are resolved (the Rosary's Matins hymn drops its mid-hymn doxology this way);
  Perl escapes (`\n`) in the replacement are honoured (Pentecost Tuesday's versicle);
- the 1960 responsory (`Responsory<n> 1960`) is looked up in the winning office, not in
  the file the lesson came from (Ss. John and Paul, 26 June 2025);
- `cujus_q` reads the whole `[Rank]` line, Commune included (*ipsa* for St Anne's `ex
  C7a`; *ipse* for St Gabriel's `vide C5` despite *Virgine* in his title);
- `Special Lectio 3` is read from the Commune's rule (Mount Carmel on a Saturday);
- `Lectio1 OctNat` (29 December to 5 January), and `StJamesRule` on Ss. Philip and James
  (the occurring Scripture when it is already St James's, 11 May 2034 and 2039);
- at Matins, the office's own `[Oratio Matutinum]` (the Triduum's collect alone);
- hymn mute vowels `Patr[e]` show plain; `r.` marks a large first letter; a stray `_` at a
  verse's end is dropped; `parenthesised_text` keeps a long aside's brackets in English.
