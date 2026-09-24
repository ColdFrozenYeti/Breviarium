# The day hours under the 1960 rubrics, as Divinum Officium builds them

Beta 2, B2-M1. This is how DO (pinned at `126a07f`) builds Lauds, Prime, Terce, Sext,
None and Compline for `Rubrics 1960 - 1960`, and where the engine ports each part.
Vespers is in [`rubrics-1960-vespers.md`](rubrics-1960-vespers.md). Paths are under
`web/cgi-bin/horas/` unless given in full.

## 1. How an hour is built

Every hour has a skeleton under `web/www/horas/Ordinarium/`:
- `Laudes.txt`;
- `Prima.txt`;
- `Minor.txt`, shared by Terce, Sext and None;
- `Completorium.txt`.

`specials.pl:21-412` (`specials`) walks the skeleton's `#Section` lines, filling each
from the routine below, and passes the plain lines through. Before a section is filled:

- **An office's own form of the hour.** `[Special <hour>]` in the winning office
  replaces the whole hour (`:36-37`, `loadspecial`). Under 1960 this covers the
  Triduum's Compline (`Quad6-4`, `Quad6-5`, `Quad6-6r`) and All Souls' Prime to None.
  Engine: `assembleSpecialHour`.
- **Capitulum Versum 2.** When the rule says so, the office's `[Versum 2]` replaces the
  chapter (the Easter octave's *Hæc dies*). At Compline the chapter is simply left out.
  Qualifiers: *ad Laudes tantum*, *ad Laudes et Vesperas*, *nisi ad Laudes* (`:57-81`).
  Engine: `skipsGroup`.
- **Omit.** `Omit <section>` in the rule drops the section; DO shows its heading with
  *{omittitur}* (`:83-117`). Example: the Easter octave's "Omit Hymnus Preces Suffragium
  Commemoratio".

**Which office.** Lauds to None take the day's own office (`occurrence`). Compline, like
Vespers, belongs to the office whose Vespers is said that evening (`concurrence`,
`horas.pl:…`, `$hora =~ /vespera|completorium/`). On first Vespers DO re-derives the
date-dependent globals from tomorrow (`$dayname[0]`, `$day`, `$month`); the Marian
antiphon and the seasonal keys below use that date. Engine: `CanonicalHour.followsConcurrence`,
`MacroContext.officeDay`/`officeMonth`.

**Our Lady on Saturday** (`horascommon.pl:423-442`). A Saturday whose temporal and
sanctoral offices are both below rank 1.4 is *Sanctæ Mariæ Sabbato*, rank 1.3, from
Commune `C10`:
- `C10a` in Advent;
- `C10b` from January to 1 February;
- `C10c` after Epiphany and in Lent;
- `C10Pasc` in Paschaltide.

For the day hours its Commune becomes an `ex` one (`:1757-1760`). Vespers never meets
it, because Saturday evening is Sunday's. Engine: `Occurrence.resolve`.

## 2. Terce, Sext and None

| Section | DO | Engine |
|---|---|---|
| Hymn | `hymni.pl:22-40`: always the psalter's `[Hymnus <hour>]` in `Minor Special`; Veni Creator at Terce in Pentecost week. 1960 never changes the doxology (`:44`). | `assembleMinorHymn` |
| Psalms | `psalmi.pl:29-331`, `psalmi_minor`. See the list below. | `assembleMinorPsalmodia` |
| Chapter, short responsory, versicle | `capitulis.pl:229-260` and `:161-227`. See the list below. | `assembleMinorCapitulum`, `shortResponsoryLines` |
| Preces | Omitted under 1960 by the skeleton. | — |
| Collect | `orationes.pl`, index 2 (Lauds'). A commemoration chained inside the collect's own section is cut off (`:136-145`). No commemorations at the minor hours (`$horamajor`). | `withoutAddedCommemoration` |

**Psalms** (`psalmi_minor`):
- **The day line.** `Psalmi minor.txt` `[<hour>]`, line `2 × weekday`.
- **Sunday's line.** Line 0, when the rule (or an `ex` Commune's) says "Psalmi Dominica".
  Under 1960 this doesn't apply to saints below I class, or to 2–3 January (`:110-118`).
- **The season's antiphon** (`:170-221`, `gettempora('Psalmi minor')`):
  - Advent: the week's set, or `Adv4<n>` for 17–23 December;
  - Lent, Passiontide and Paschaltide: their sets;
  - in Paschaltide one *Allelúia* antiphon serves every hour.
- **The office's own antiphon.** `[Ant <hour>]` (`:223-261`). Under 1960, I class feasts
  whose rule says "Antiphonas horas" take Lauds' antiphons: the 1st, 2nd, 3rd and 5th for
  Prime, Terce, Sext and None (`specials.pl:543-573`).
- **Easter week.** "Minores sine Antiphona" means no antiphon at all.
- **Display** (`antetpsalm`, `:661-707`). One antiphon over the three psalms: whole
  before them (`$duplexf`, always under 1960), without its asterisk after them.

**Chapter and short responsory:**
- **The chapter.** The office's `[Capitulum <hour>]`; Terce takes `[Capitulum Laudes]`.
  Otherwise the psalter's `<season> <hour>`, where the season comes from
  `gettempora('Capitulum minor')`: Adv, Quad, Quad5, Pasch, Asc, Pent, Nat, Epi, or
  Dominica/Feria. `$Deo gratias` is added (`_format_capitulum`).
- **The responsory.** The office's `[Responsory <hour>]`, or its `[Responsory Breve
  <hour>]` plus `[Versum <hour>]`. In a Commune file the versicle can come from
  `Nocturn 2 Versum`, `Nocturn 3 Versum` or `Versum 2`. Otherwise the psalter's.
- **`postprocess_short_resp`** (`horas.pl:697-726`):
  - `&Gloria` becomes `&Gloria1`, the first half-verse only;
  - in Passiontide, outside the saints' offices, DO shows *Gloria omittitur* instead;
  - in Paschaltide the responsory takes *allelúia* (`ensure_double_alleluia`,
    `ensure_single_alleluia`).

## 3. Compline

| Section | DO | Engine |
|---|---|---|
| Opening | *Iube, Dómine* and the blessing; then `#Lectio brevis`: `Minor Special` `[Lectio Completorium]` with *Tu autem* (`specials.pl:210-214`), then *Adiutórium nostrum*, *Examen conscientiæ* (a 1960 rubric), *Pater noster*, the Confiteor, *Misereátur*, *Indulgéntiam*, *Convérte nos* ✙︎, *Deus in adiutórium*. | `assembleLectioBrevis` |
| Psalms | `psalmi_minor`, `[Completorium]`: the day's line, Saturday's for the eve of Sunday, Sunday's only on I class feasts under 1960. The office's `[Ant Completorium]` wins. | `assembleMinorPsalmodia` |
| Hymn | *Te lucis* (`Minor Special`). | `assembleMinorHymn` |
| Chapter, responsory | `[Completorium]` (Ier 14:9), `[Responsory Completorium]` *In manus tuas*, `[Versum 4]` *Custódi nos*. | `assembleMinorCapitulum` |
| Nunc dimittis | `horas.pl:508-568`: canticle 233 with the office's `[Ant 4<vespera>]` (Easter week: four *Allelúia*s, closing with *Hæc dies* as its second line), else `Minor Special` `[Ant 4]` *Salva nos*. | `assembleNuncDimittis` |
| Prayer | Outside the Triduum, the skeleton's own: *Visita, quǽsumus* (`specials.pl:329-345`). | `Oratio` case |
| Final antiphon | `specials.pl:313-338`: *Alma Redemptoris* (Advent, Christmastide, to 1 February; 2 February except at Compline), *Ave Regina cælorum* (then until Holy Week), *Regina cæli* (Paschaltide), *Salve Regina* (otherwise); then `&Divinum_auxilium`. | `assembleAntiphonaFinalis` |

## 4. Prime

| Section | DO | Engine |
|---|---|---|
| Hymn | *Iam lucis orto sídere* (`Prima Special`). | `assembleMinorHymn` |
| Psalms | `psalmi_minor`, `[Prima]`: see the list below. | `assembleMinorPsalmodia` |
| Chapter, responsory | `specprima.pl:55-108`: see the list below. | `assemblePrimeCapitulum` |
| Preces | The skeleton leaves only `#Preces Feriales` under 1960. Said on Wednesdays and Fridays of Advent and Lent, and on Ember days, at non-festal offices (`preces.pl:7-70`). Then *Dómine, exáudi*'s second form is a rubric (`$precesferiales`). | `assemblePrecesFeriales`, `Oratio` case |
| Prayer | The skeleton's own *Dómine Deus omnípotens*. | `Oratio` case |
| Martyrology | `specials.pl:297-302`. **Left out:** the Martyrology is a separate "hour" in a later beta (decided 2026-09-24). The *Pretiosa* DO says after it belongs to Prime and stays (not in the Office of the Dead). | `assemblePretiosa` |
| De Officio Capituli | The skeleton's own. | `De Officio Capituli` case |
| Short lesson | `specprima.pl:5-53`: `$benedictio Prima` (with *Iube, Dómine*), the season's lesson (`gettempora('Lectio brevis Prima')`, *Per Annum* by default; under 1960 never the office's own), *Tu autem*. | `assemblePrimeLectio` |

**Psalms** (`psalmi_minor`, `[Prima]`):
- the bracketed psalm is dropped under 1960;
- 117 gives way to 53 with Lauds II, or by the rule "Prima=53";
- on I class feasts with Sunday psalms the first psalm is 53 (`:252-305`);
- the *Quicumque* is said under 1960 only on Trinity Sunday (`:309-323`).

**Chapter and responsory** (`specprima.pl:55-108`):
- under 1960 always `[Dominica]` (1 Tim 1:17);
- the responsory *Christe, Fili Dei vivi*, its versicle changing with the season
  (`get_prima_responsory`, `:110-136`: 9–15 December, not the 12th, takes Advent's);
- then `[Versum]`.

## 5. Lauds

| Section | DO | Engine |
|---|---|---|
| Psalms | `psalmi.pl:333-659`, `psalmi_major`: see the list below. | `assembleLaudsPsalmodia` |
| Chapter, hymn, versicle | `capitulum_major`, `hymnusmajor`, `getantvers('Versum', 2)`: see the list below. | `assembleLaudsCapitulumHymnusVersus` |
| Benedictus | Canticle 231 with `getantvers('Ant', 2)`; 21 and 23 December have their own (`horas.pl:472-502`). | `assembleBenedictus` |
| Preces | As at Prime, from `Major Special` `[Preces feriales Laudes]`. | `assemblePrecesFeriales` |
| Collect, commemorations | Index 2; the day's own runners-up as commemorations (`@commemoentries`). This is why the title block shows *Commemoratio ad Laudes tantum*. | `Commemorations.laudsCommemorations` |
| Suffrage | `checksuffragium` (`specials.pl:699-766`): not under the 1960 rubrics' ranks and seasons. | — |

**Psalms** (`psalmi_major`):
- **Lauds I or II.** `$laudes` (`horascommon.pl:1862-1878`): II on the penitential days of
  the temporal cycle (Advent ferias, Septuagesima to Holy Week, Ember days outside
  Paschaltide, not Our Lady's offices), or by the rule "Laudes 2". Then `Psalmi major`
  `[Day<n> Laudes<1|2>]`.
- **The office's antiphons.** Its own `[Ant Laudes]`, or an `ex` Commune's. With
  "Psalmi Dominica" they go with Sunday's psalms, `[Day0 Laudes1]`.
- **17–23 December.** `[Day<n> Laudes3]`.
- **Paschaltide without proper antiphons.** A single *Allelúia* antiphon over all five.
- **Display.** Within a psalm group only the last psalm has the Gloria.
- **Canticles** are titled from their file's "(title * source)" line
  (`horasscripts.pl:565-580`).

**Chapter, hymn and versicle:**
- **Chapter** (`capitulum_major`): the office's `[Capitulum Laudes]`, else the psalter's
  `<season> Laudes`.
- **Hymn** (`hymnusmajor`): the office's `[Hymnus Laudes]`, else the psalter's `Hymnus
  <Day<n>|season> Laudes`; Sunday takes the *hiemalis* hymn after Epiphany, in
  Septuagesima, and in October and November.
- **Versicle** (`getantvers('Versum', 2)`): the office's `[Versum 2]`, else the psalter's.

## 6. Section headings

DO's own group names, in Latin (`CLAUDE.md`'s fixed elements):
- INTRODUCTIO, PSALMODIA, CAPITULUM, HYMNUS, VERSUS, CANTICUM, PRECES FERIALES, ORATIO and
  CONCLUSIO, as at Vespers;
- LECTIO BREVIS (Compline and Prime), ANTIPHONA FINALIS (Compline) and DE OFFICIO
  CAPITULI (Prime, beginning with the *Pretiosa*).

At Prime, Terce, Sext and None, CAPITULUM covers the chapter, the short responsory and
its versicle together, as DO's "Capitulum Responsorium Versus" does.
