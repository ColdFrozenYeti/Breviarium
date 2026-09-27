# The Dominican office in Divinum Officium (*Ordo Prædicatorum - 1962*)

B5-M1 of [`Beta_5_plan.md`](Beta_5_plan.md). This document covers how Divinum Officium
(DO) builds the Dominican office, read at the pinned commit (`data/SOURCE.md`) and
checked against DO's own renders where noted. Paths are relative to
`data/divinum-officium/web/`. It is the map for B5-M3 and B5-M4. Hour-by-hour detail is
added as the engine work meets each hour, as `rubrics-1960-votives.md` §7 was for
Beta 4.

## 1. What the version is

`www/Tabulae/data.txt:16`:

```
version,                  kalendar, transfer, stransfer, base,                  transferbase
Ordo Praedicatorum - 1962, OP1962,   1960,     XXXX,      Rubrics 1960 - 1960
```

- **The rubrics are 1960's.** Everything DO decides by testing `$version` for `1960`
  does *not* fire for the Dominican version, because its name contains "1962". Each such
  test has to be checked. The Martyrology is the first found (§6).
- **The calendar is a diff.** `Kalendaria/OP1962.txt` says it "only notes the
  differences to Rubrics 1960 - 1960". Each line either replaces a Roman day (`01-15=01-15OP~…`)
  or suppresses it (`01-05=XXXXX`, 45 lines). Anything it doesn't name falls through to
  the base calendar (`DivinumOfficium/Directorium.pm:213-228`, `get_from_directorium`
  with `$_data{$version}{base}`).
- **Transfers** use the 1960 Easter-based transfer tables (`transfer` = `1960`), and there
  is **no** saints' transfer table (`stransfer` = `XXXX`).

## 2. Where the texts come from

- **`TemporaOP/`, `SanctiOP/`, `CommuneOP/`** (427, 124 and 28 Latin files). The
  directory is chosen by `horascommon.pl:2165` (`subdirname`: `${subdir}OP/`). When a
  file is missing there, DO falls back to the Roman tree. That fallback is how the
  Dominican office reaches the Roman Office of the Dead: DO renders `votive=C9` under
  the Dominican version from `Commune/C9` (checked, 3 November 2026, Lauds).
- **`Regula/OrdoPraedicatorum.txt`**: the Rule of St Augustine for Prime (§4).
- **The psalter is the Roman one**, with Dominican sections chosen by name
  (`specials/psalmi.pl:169`: a section's trailing number becomes `OP`, e.g. `[AdvOP]` and
  `[Quad5 OP]` in `Psalterium/Psalmi/Psalmi minor.txt`).
- **The Pius XII psalter** is a language in DO (`Latin-Bea`), not a version, so it
  applies to the Dominican office too (`horasscripts.pl:468`, `specmatins.pl:94`).
  Decision 3: *Psalterium* stays enabled under *Dominicanus*.
- **Conditionals in the texts.** About 180 conditions in 70 files name the rite:
  - `(rubrica praedicatorum)` (33), `(sed rubrica praedicatorum)` (26),
    `(nisi rubrica praedicatorum)` (19);
  - `(sed rubrica cisterciensis aut rubrica praedicatorum)` (18);
  - `(rubrica Ordo Praedicatorum)` (14), and others.

  They are spread over `Tempora` (29 files), `Sancti` (29), `Psalterium`, `Commune`
  and `Ordinarium`. Our engine keeps conditionals raw in the bundle and evaluates them
  at run time (`ConditionalEvaluator`, a port of `SetupString.pl`'s `vero`), with
  `rubrica X` a match against the version string. So they need no new code, only the
  Dominican version string in `ConditionalContext`.

## 3. English

- `English/TemporaOP` has 15 files (Easter week, Passiontide), and there is none for
  `SanctiOP` or `CommuneOP`. Where DO has no Dominican English file, it falls back to the
  Roman English file of the same name. DO's English column is therefore sometimes the
  Roman English for a different Latin text. The English audit compares with what DO
  shows.
- **DO's Dominican data has gaps.** Checked on St Catherine de' Ricci (13 February 2026,
  Lauds): the collect is the common's, with the name left as the placeholder "N." and
  *Virgo et Martyr* for a saint who wasn't a martyr. The English column is the Roman
  common's English, "N." included. Matching DO exactly means matching such gaps. Each
  one found is listed in §8 for the user to decide, as `CLAUDE.md` requires for a
  suspected DO error; none is "fixed" in a fixture.
- Decisions 5 and 6 decide what the app shows:
  - DO's Dominican English where it exists;
  - the Roman English where the Dominican Latin matches the Roman exactly;
  - the Roman English with the grey note *Roman text; the Dominican Latin differs.*
    where it differs a little;
  - Latin only where there is no Roman counterpart.

  The data tool computes the match at build time and reports the counts.

## 4. The code branches, by hour

These are the `Praedicatorum` tests in `cgi-bin/horas/`, 37 in all. "OP" means the
Dominican version.

**Every hour**
- `horas.pl:43`: no chant (irrelevant to us).
- `specials.pl:529`: the older hymn texts. When a section `Hymnus…M` exists, OP takes
  it, as the Monastic and 1570 versions do (`hymni.pl:154` likewise takes the `…T`
  variant).
- `horascommon.pl:2312`: the major hours' hymn is `Day0`'s on every weekday, except
  Saturday Vespers.
- `specials/orationes.pl:162-167`: *Dominus vobiscum* and the collect's preamble. It
  applies on days below III class and vigils, except Christmas Eve, Eastertide and 2–5
  January. OP adds no litany at the major hours.
- `horasscripts.pl:170`: *Benedicámus Dómino* takes the double *allelúia* all Eastertide
  on days above III class and on Our Lady on Saturday (`C10`), not only in the Easter
  octave.

**Matins** (`specmatins.pl`)
- `:55`: the Eastertide weekday invitatory and antiphons follow the Monastic branch.
- `:101-109`: on Sundays the invitatory is said without its second half (as the
  Roman `Invit2`), unless the rule says `Invit5`. There is no Passiontide invitatory
  change.
- `:182-189`: every weekday takes the Sunday Matins hymn (`Day0 Hymnus`), with no
  winter/summer switch.
- `:381-388`: the weekday nocturn takes three psalms of the week's five, by week of
  the season ("rubrics at page 455 1962 Breviary").
- `:669`: no *Absolutio* before the lessons.
- `:1250-1258`: a responsory after the last lesson even when the *Te Deum* follows, and
  no contraction of Scripture lessons.
- `:1504`: no responsory before the last lesson when the *Te Deum* follows.
- `:1591`: no Easter-Sunday psalms on the Sundays after Easter.
- `monastic.pl:170`: the Eastertide Matins antiphons, from the Tempora only.

**Lauds**
- `horasscripts.pl:149`: a versicle before Lauds (`versiculum_ante_laudes`, the
  office's `[Versum]`).
- `horas.pl:481`: Advent's special Lauds antiphons are for 21 December only, not also
  for 23 December.
- `specials.pl:268`: in the Triduum, the office's *Preces ad Laudes*.

**Prime**
- `monastic.pl:592-644`: after the chapter, *Iube, domne* and then one of two readings:
  - on feasts, the Gospel of the day, cut at the `¶` mark, with the heading reduced to
    its last words (*secúndum Ioánnem*);
  - on ferias, vigils and octaves, the day's passage from the Rule of St Augustine,
    with its blessing.

  *Tu autem* and *Finita lectione* follow.
- The Martyrology (§6).

**The little hours**
- `specials/capitulis.pl:171`: in Lent, the chapters and responsories are `…OP`
  sections (weeks 3 and 4 share one).

**Vespers**
- `specials/capitulis.pl:31`: at first Vespers, a responsory after the chapter
  (`monastic_major_responsory`).
- `specials/psalmi.pl:555`: psalms "under one antiphon" when the office gives only one.

**Compline**
- `horas.pl:533-540`: the *Nunc dimittis* antiphon is seasonal (`gettempora`), and in
  Lent's third week it is doubled.
- `specials/hymni.pl:27`: the versicle follows the hymn, not the chapter
  (`capitulis.pl:185` doesn't add it there).
- `specials.pl:73`: at Easter, a versicle in place of the chapter.
- `specials.pl:316`: the final antiphon is always the *Salve Regina*, under the heading
  *Antiphonæ finales*.

**The Little Office** (`horascommon.pl:1781-1783`)
- OP has no `C12Q` (no Lenten form).
- The Annunciation doesn't take the Advent form.
- `CommuneOP` has its own `C12`, `C12A` and `C12N`.

## 5. The Office of the Dead

There is no `CommuneOP/C9`. DO renders the Office of the Dead under the Dominican version
from the Roman `Commune/C9` (§2). Its three hours are the Roman ones, with any
`(rubrica praedicatorum)` lines in `C9` itself taking effect. Beta 5 offers it under
*Dominicanus* (decision 1) and checks it against DO like the Roman one.

## 6. The Martyrology

- DO has no Dominican Martyrology. `specials/specprima.pl:145-149` picks the directory
  by version name: `Martyrologium1960` only when the version contains "1960". For the
  Dominican version it uses the older `Martyrologium/`.
- The two differ on **71 of 366 days**, mostly the octaves the 1960 reform abolished.
  For example, 1 January still announces the Octave of the Nativity with the
  Circumcision.
- Neither has entries of the Order's own, beyond what the Roman text says of Dominican
  saints (St Dominic, 4 August).
- Decision 4: the app shows the **1960 Roman Martyrology** under *Dominicanus*, since
  the 1962 Dominican office follows the 1960 rubrics. The audit records the 71 days as a
  known DO divergence. This is a judgement call, to revisit if a source for the Order's
  own Martyrology is found.

## 7. What this means for the engine (B5-M3, B5-M4)

- **Most of it is data, not code.**
  - The calendar overlay (§1) is new code in the calendar reader, which today builds
    only the Roman chain (`CalendarChainReader.chainOldestFirst`).
  - The `OP` directories need adding to the bundle (`BreviariumDataCore`'s folder
    lists) with the Roman fallback.
  - The text conditionals need only the version string (§2).
- **The code branches (§4) are about 30 small overrides**, each tied to a line above.
  `OrdoPraedicatorum` is the Roman provider with these overrides, not a second engine.
- **Every test of `$version =~ /1960/` in our port** must be checked for its Dominican
  answer. Some are wanted (`Rubrics 1960` behaviour the Dominican office shares). Some
  are not (the Martyrology directory). B5-M3 lists each one, with the answer from DO.

## 8. Suspected DO gaps (for the user)

| Date | Hour | What DO shows | Why it looks wrong |
|---|---|---|---|
| 13 February (St Catherine de' Ricci) | Lauds, collect | The common *Indulgéntiam… beáta N. Virgo et Martyr*, English likewise | The name is the placeholder "N.", and she was not a martyr |
