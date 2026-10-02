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
  - DO decides "feria" from the day's name *with its rank* (`$dayname[1]`,
    `horascommon.pl:675`): *Sabbato post Cineres Feria major* reads the Rule.
  - The Gospel comes from the office's `[Evangelium]`, else the Mass's (`missa/`, bundled
    for this: only the `[Evangelium…]` sections, Latin and English, about 1.3 MB), else
    the Commune's. In the Mass's context DO reads a numbered Common from the office's
    tree and any other file from the Mass's when it is there (`SetupString.pl:556-626`,
    `SectionResolver.missaLocation`).
- The office of the chapter has no *De Officio Capituli* heading: it is `(rubrica 1960)`
  in `Ordinarium/Prima.txt`, so its lines follow the *Pretiosa*, and `(nisi rubrica
  praedicatorum) &Gloria` drops the Gloria after *Réspice*. The closing blessing is
  omitted.
- Several 1960 tests are by version name (`1955|1960`), so the Dominican "1962" takes
  the older branch:
  - the bracketed fourth psalm is said with Lauds II (`psalmi.pl:276-282`);
  - Lauds II on vigils too (`horascommon.pl:1873`);
  - proper antiphons at the little hours on lower feasts with *Antiphonas horas*
    (`specials.pl:550`, `psalmi.pl:225`);
  - the chapter of ferias, *Pacem et veritátem* (`specprima.pl:64-72`), with the
    Advent ferias from 17 December at rank 4.9 (`SetupString.pl:740`).
- In Advent the little hours take `[AdvOP]` (`psalmi.pl:170`).
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

**Paschal Commons**: DO takes a Common's Paschal form (`C2ap`) only when the file exists
in the rite's own folder (`horascommon.pl:1496-1499`), and `CommuneOP` has none, so the
Dominican Commons keep their ordinary form in Eastertide (29 April, St Peter Martyr's
Gospel from `C2`).

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
| 7 October (the Holy Rosary) | Prime, Gospel | "Sancti/9-12:Evangelium is missing!" in the Latin; the English has Luke 1:26-38 | `missa/Latin/Sancti/10-07.txt:37` reads `@Sancti/9-12`, a typo for `09-12`. Decided 1 October 2026: the app shows the Gospel (Luke 1:26-38); the data tool corrects the reference and the audit skips DO's broken page |
| 24 February (St Matthias), and the Apostles under `CommuneOP/C1` | Vespers, antiphon | "Commune/C1:Ant Vespera" | `[Ant Vespera 3]` is `@:Ant Laudes:1 s/$/;;109;…;138/` on a section that is only a reference (`@:Ant Vespera`). Corrected (decided 1 October 2026): the reference is resolved first, giving *Hoc est præcéptum meum* over the five psalms |
| Ascension (13 May 2026), first Vespers | Responsory after the chapter | "Tempora/Pasc5-4:Responsory Vespera 1 is missing!" | `TemporaOP/Pasc5-4` reads `@Tempora/Pasc5-4::s/\*/\n*/`, naming no section, and no Roman section fits the substitution. **The intended responsory can't be determined from DO**: the app shows none until the text is supplied from a Dominican breviary |
| 24 April (the Crown of Thorns, *Festum Domini*) | Lauds, little hours, Vespers | "Oratio missing", "Ant 2 missing" | `SanctiOP/04-24OP` has only Matins (invitatory, hymn, three lessons and responsories): no collect, Lauds antiphons, chapters or Benedictus/Magnificat antiphons. **The Order's own texts aren't in DO**: the app shows no collect and the psalter's texts until they are supplied |
| Ash Wednesday (18 February 2026) | Matins, first lesson | "Tempora/Quadp3-3:1-4 is missing!" | `TemporaOP/Quadp3-3` reads `@Tempora/Quadp3-3:1-4`, a colon short. Corrected (decided 1 October 2026): lines 1-4 of the same lesson, the Gospel's opening |
| St Agnes (21 January) | Matins, second antiphon of the first nocturn | "Sancti/01-21:Ant Vespera 3 is missing!" | `SanctiOP/01-21` reads `@Sancti/01-21:Ant Vespera 3:3 s/111/18/`; the Roman file has no `[Ant Vespera 3]`, and the Monastic one's third line is psalm 112, its second psalm 111, so which antiphon is meant is uncertain. **The app shows the psalm without that antiphon until the text is supplied** |
| Transfiguration (6 August) | Vespers antiphons | "Psalterium/Common/Prayers:Alleluia Simplex is missing!" | `SanctiOP/08-06` reads `Alleluja Simplex`, the prayer is `[Alleluia Simplex]`; the app reads it (", allelúia") |
| Lent (Compline) | Responsory | none (`capitulis.pl:171-175` asks for `Responsory CompletoriumOP`, the file's section is `Responsory Completorium OP Quad`) | The Dominican Lenten responsory *In pace in idipsum* is never shown |
| 2 February, 11 February, and every feast with the Marian Commune (`C11`) | Matins, eighth blessing | "Benedictio." with no text | The Dominican Marian set (`Psalterium/Benedictions.txt:139-149`) has no *Cuius festum* line, so `$ben[3 + cujus_q]` is empty. Corrected: the set's own *In omni tribulatióne et angústia subvéniat nobis pia Virgo María*. Two misprints in the same set are corrected too: *intercédát* and *Ad societâtem civium* |
| 21 August (St Jane Frances de Chantal) | Matins, invitatory | *In solemnitáte sancæ Ioánnæ Francíscæ* | `CommuneOP/C7a` reads *sancæ*; corrected to *sanctæ* |
| 14 September (the Exaltation of the Cross) | Matins, antiphons of Psalms 20 and 23 | An empty antiphon ("Ant. .") before Psalm 23, and the antiphon of Psalm 20 ending in a colon | `SanctiOP/09-14` reads line 3 of `[Suffragium Feriale]`, which is now the `_` after the antiphon, with `s/Ant. //` written for the antiphon line. Corrected: *Per signum Crucis de inimícis nostris líbera nos, Deus noster*, and the respond's colon becomes a full stop |
| 15 January, 9 October (a saint commemorated on a Dominican feast of three lessons) | Matins, third lesson | The commemorated saint's abridged legend (`[Lectio94]`), then his lessons 5 and 6 as well | DO joins the commemorated office's lessons 5 and 6 onto the legend (`specmatins.pl:1215-1234` reads them from the commemorated office once `%w` has been switched to it), so the story is told twice. Corrected: the legend once |
| 30 April (St Catherine of Siena) | Matins | *Ad Nocturnum* with her first antiphon alone and no psalms | `SanctiOP/04-30` has no `[Rule]` (so three lessons) and only the three antiphons of a first nocturn; the Paschal rule of one nocturn by the week (`specmatins.pl:381-389`) takes the third nocturn, which isn't in the data. **Uncertain**: the app says the nocturn the data has (her three antiphons over Psalms 8, 18 and 23) until her full Matins is supplied from a Dominican breviary |
| 7 March (St Thomas Aquinas, I class) | Matins | Three lessons from the Commune of Doctors (*Sir 14*, *24*) | `SanctiOP/03-07` has only `[Officium]` and `[Rank]`: no rule, so no nine lessons, and none of his own lessons or antiphons. **Not corrected**: the app shows what DO shows until his office is supplied |
| Two Saturdays a year (14 February and 10 October 2026) | First Vespers of Sunday, chapter | Prime's chapter, *Dóminus dírigat corda* (2 Thess 3:5) | The other Saturdays show the Sunday's *Benedíctus Deus* (2 Cor 1:3-4), as the app does on these too; the audit skips these pages |
| A Friday before a Saturday feast (13 September 2030) | Vespers, chapter and Magnificat antiphon | Saturday's *Benedíctus Deus* (2 Cor 1:3-4) and *Suscépit Deus Israël* | The same `(feria 7)` header as the row above, fixed when DO first reads `Major Special` for tomorrow. The app says Friday's; the audit skips the page |
| Ash Wednesday before St Thomas Aquinas (6 March 2030) | Vespers | First Vespers of St Thomas, Ash Wednesday commemorated | Not an error: `horascommon.pl:887-891` lowers Ash Wednesday to 2.99 at second Vespers for every version but 1955 and 1960, the Order's "1962" among them. The app does the same |
| Easter Saturday (11 April 2026) | Vespers and Compline | Low Sunday's first Vespers | Right, though by accident: DO can't read `TemporaOP/Pasc0-6`'s rank (0). The app gives the same by the Roman file's "No secunda Vespera" |
| Many Dominican saints' days | Lauds, the versicle before Lauds | *Ora pro nobis, beáte N.* (about 400 days in 2025-2040), or a name in the wrong case (*beáte Gregórii*, *beáte Bonaventúram*), or the commemorated saint's name (*beáte Pauli* on Bl. Francis de Capillas's day) | The Dominican files have no `[Name]`, or no vocative (`Ant=`) one. The app keeps the Common's "N." as a printed Common does, and never uses the commemorated saint's name; **the vocatives need a source** |
| First Vespers of Passion Sunday (21 March 2026) | Vespers, hymn | *O Crux, ave… In hac triúmphi glória* | The Holy Cross's form: DO reads the season from the Saturday. The app says *Hoc Passiónis témpore*; the audit skips the page |
| 2 to 5 January | Vespers, hymn | *Christe Redémptor ómnium*, the Roman Christmas hymn | DO reaches the Roman `Sancti/12-25` through `TemporaOP/Nat02`…`Nat05`'s `vide Sancti/01-01`; every other Dominican Vespers from 24 December to 1 January says *Veni, redémptor géntium*, as the app does on these days. The audit skips the page |
| 5 and 6 January | Vespers of the Epiphany, psalm antiphon | the words *Sancti/01-06:Ant Laudes* | `SanctiOP/01-06`'s `[Ant Vespera]` takes line 1 of the Roman `[Ant Vespera]`, which is itself a reference (`@:Ant Laudes`) that DO prints instead of following. The app follows it: *Ante lucíferum génitus*, the first antiphon of Lauds, over the five psalms. The audit skips the page |
| Saturdays in January, Our Lady on Saturday | Lauds, Benedictus antiphon | an empty antiphon ("Ant. ‡") | `CommuneOP/C10b`'s `[Ant 2]` takes line 2 of `Sancti/12-25`'s `[Ant Laudes]`, a one-line reference (`@:Ant Laudes_`). The app follows the reference: *Génuit puérpera*, the second antiphon of Christmas Lauds. The audit skips the page |
| Holy Thursday, Good Friday, Holy Saturday | Lauds, fifth antiphon | "portávit. ." (a stray `_`) | `TemporaOP/Quad6-4/5/6`'s `[Ant Laudes]` turns every newline into `_`, including the last; the app removes it (`SectionResolver.doTextCorrections`). The audit skips the page; the Order's *Preces* after the Benedictus, which the app now says, were checked against DO line by line |
| 2 June (Paschaltide) | Lauds, commemoration of Ss. Marcellinus, Peter and Erasmus | an empty antiphon (", allelúia.") | The Paschal Commune DO reads (`Commune/C3p`, through `CommuneOP/C3p`) has no `[Ant 2]`. The app says *In cæléstibus regnis Sanctórum habitátio est, allelúia…*, from the Common; **which antiphon the Order's breviary gives here needs a source** |
| 17 September | Lauds, order of the commemorations | St Lambert (Simplex) before the Stigmata of St Francis (Duplex) | In Latin `getcommemoratio` leaves `%c` holding the commemorated office's Common, so `orationes.pl:480-492` orders the two by their Commons' ranks. The app says the Stigmata first, as their own ranks require. The audit skips the page |
| Saints without a `[Name]` whose day has a commemoration (Bl. Jane of Aza, 8 August 2025) | Matins, invitatory | the commemorated saints' names (*sancæ Cyríaci, Largi et Smarágdi*) | The Common's "N." is filled from the first commemorated office instead of the saint of the day. The app keeps "N.", as in the Lauds versicle above; the audit compares the uncorrected text |
| Vigils with three lessons (St John Baptist, 23 June) | Matins, responsories | none: three lessons and the conclusion | The rule says *Responsory Feria*, and the Order's feria (`TemporaOP/Pent02-1`, borrowing `Tempora/Pent02-1`) has only the 1960 Roman responsories, which DO doesn't read for the Order. The app follows DO; **which responsories the Order's breviary gives at a vigil needs a source** |
| Third Sunday of Lent | Lauds, Benedictus antiphon, English | "When had cast out the devil" | `TemporaOP/Quad3-0`'s `s/ Je.us//` drops *Iesus* from the Order's Latin and DO runs it on the Roman English too. Corrected for the English only (`SectionResolver.doEnglishTextCorrections`): "When Jesus had cast out the devil", with the note of decision 6 |
| 4 August | Lauds, Benedictus antiphon | "pr'aemium" | DO's `<sp>'ae</sp>` markup for *prǽmium*; corrected |
| Saturdays before a Sunday that is commemorated | Vespers, the Sunday's versicle | *Dirigátur* on a few Saturdays (St Joachim, the Rosary, St Thomas), *Vespertína orátio* on most | Saturday Vespers are the Sunday's first Vespers, whose versicle is *Vespertína orátio*; which one DO shows depends on when it first reads `Major Special` (its `(feria 7)` header is fixed at that moment). The app always says *Vespertína orátio*; the audit skips the *Dirigátur* pages |
| Paschaltide (Lauds), 21 January and virgins (Terce) | English | the English of *Aurora cælum purpurat* beside the Order's *Sermóne blando*; mangled English lines of the virgins' short responsory | The app shows the Latin alone (decision 5: no English that translates this Latin); the audit leaves these English texts out of the comparison |
| 12 November (All Saints of the Order, `ex Sancti/11-01`) | Second Vespers, psalmody | One antiphon, *Iustórum autem ánimæ* (the Common of Martyrs' first Lauds antiphon, `CommuneOP/C3a`), over Psalms 109, 112, 115, 125, 139 | Not All Saints' Vespers, which the office is taken from. The app says All Saints' five antiphons (*Vidi turbam magnam*…); **the fifth psalm (113 or All Saints' 115) is uncertain**. The audit skips the page |
| 30 August (St Rose of Lima, Third Order) | Every hour | The feria, or Our Lady on Saturday | `SanctiOP/08-30` (with her own hymns and invitatory) takes its `[Rank]` from `@Sancti/08-30`, and DO loses it (no rank), so the temporal office wins. The app says her office; the audit skips the date |
| 1 November | Compline, title | The weekday's title (*Dominica XXIII Post Pentecosten*, *Feria Secunda…*) | DO applies to the Dominican version the pre-1960 rule that All Souls supersedes All Saints at Compline (`horascommon.pl:333-337`), which empties the title. The app names All Saints; the hour is the same |
| A Dominican Simplex saint on a weekday (Bl. Jane of Aza, Friday 8 August 2025) | Vespers and Compline | The feria's | Right (a Simplex ends after None, `horascommon.pl:338`); the app does the same |
