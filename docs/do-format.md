# Divinum Officium data format

What `BreviariumData` (M2) needs to parse, resolves against the pinned submodule commit
recorded in `data/SOURCE.md`. Scoped to what the **Roman Vespers, 1960 rubrics** path
actually touches — DO supports many other rites, hours, and historical rubric versions
(Tridentine, Monastic, Cistercian, Dominican...) whose code paths this document ignores.

Every claim below is cited to a source file (and approximate line number, since the
pinned commit won't move under us) so it can be checked directly rather than trusted on
my say-so. Where I'm inferring behaviour from reading rather than having watched it run
(no local Perl/Docker was available while writing this — see `docs/windows-swift-setup.md`
for the parallel local-toolchain story), I've said so explicitly rather than presenting a
guess as settled.

## How to actually invoke it (found during M0, restated here)

DO's own regression tooling (`regress/scripts/generate-diff.sh`) calls the CGI script
directly as a Perl program, not over HTTP:

```
perl web/cgi-bin/horas/officium.pl version="Rubrics 1960" command=prayVespera date=1-1-2025
```

- `version` is the exact rubrics-version string from `web/www/Tabulae/data.txt` (column
  1) — `"Rubrics 1960 - 1960"` is the full string used by the live site (per
  `docs/how-the-calendar-works.md`); `officium.pl`'s own version matching is done with
  loose regexes like `$version =~ /196/`, so either form should select the same rubrics,
  but M2/M4 tooling should use the exact string to match what the live site and
  `data.txt` actually call it.
- `command=pray<Hora>` — `officium.pl` strips the `pray` prefix and splits the remainder
  on capital-letter boundaries (`officium.pl:142-144`), so `prayVespera` → hora
  `Vespera` (note: singular, not `Vesperae` — `horas.pl:30` normalises `Vesperae` to
  `Vespera` early on, but the command itself already uses the singular).
- `date=M-D-YYYY` (not zero-padded, per the regression script's own date formatting).

This is the invocation `scripts/generate-oracle-fixtures.*` (M4) should use — no HTTP
server, no cookies, no Docker networking beyond what's needed for the Perl module
environment itself.

## Options mapping

| DO concept | Our concept |
|---|---|
| `version="Rubrics 1960 - 1960"` | Ritus = Romanus, 1960 rubrics (the only rubrics tier this project targets) |
| Priest cookie/option (`$priest` in `horas.pl`/`horascommon.pl`) | Sacerdos vel diaconus adest |
| "Pius XII Psalter" | **Confirmed** (`officium.pl:133-137`): the `$psalmvar` toggle swaps whichever of `$lang1`/`$lang2` equals `'Latin'` to `'Latin-Bea'` instead. `Latin-Bea/` contains only a `Psalterium/` subfolder (170 files) — DO's normal dash-fallback in `setupstring()` (`SetupString.pl:594-599`, stripping the part after the last `-`) means `Latin-Bea` transparently falls back to plain `Latin` for anything it doesn't have. Since `CLAUDE.md` fixes the Bea psalter permanently (it's not one of our exposed Settings toggles), `BreviariumData` should always read `Psalterium/` content from `Latin-Bea/` where a file exists there, falling back to `Latin/Psalterium/` otherwise, and read everything else from plain `Latin/`. |
| Language toggle (`$lang1`/`$lang2`, `-` two-column mode) | English translation on/off |

## Section-based file format

Every office text file (`web/www/horas/Latin/{Tempora,Sancti,Commune,Psalterium}/...txt`)
is a flat list of `[Section]` blocks, parsed by `setupstring_parse_file()`
(`DivinumOfficium/SetupString.pl:318-371`):

```
[SectionName]
line one
line two

[AnotherSection]
...
```

A section header may carry a **conditional clause** in parentheses, which gates whether
that section is used at all for the current `$version`/day/etc. (`SetupString.pl:335-348`):

```
[Festa] (rubrica 196)
...
```

replaces the file's default (unconditioned) `[Festa]` section when the condition is true
— this is the exact mechanism behind `CLAUDE.md`'s `(sed rubrica 1960)` example, and it's
also how `web/www/horas/Latin/Psalterium/Comment.txt` gives 1960 rubrics its own rank
display names (see `docs/rubrics-1960-vespers.md`).

## The conditional mini-language

Parsed by `vero()` and `parse_conditional()` (`SetupString.pl:120-303`). A conditional is
`(stopwords... clause)`, where:

- **Stopwords** (`sed`, `vero`, `atque`, `attamen`, `si`, `deinde`) set the conditional's
  *strength* and whether it implicitly deletes preceding text (`SetupString.pl:78-87`).
  `sed`/`vero` are strength 1, `atque` strength 2, `attamen` strength 3 — higher-strength
  conditionals can override/close out lower ones, which is what lets a later `(atque ...)`
  reopen text that an earlier `(sed ... omittitur)` had suppressed.
- **Scope phrases** — `dicitur`/`dicuntur` ("is/are said" — the following text applies),
  `omittitur`/`omittuntur` ("is/are omitted" — the following text is dropped), optionally
  prefixed `hic/hoc/hæc/hi versus/versuum` — control how much preceding and following
  text the conditional reaches: one line (`SCOPE_LINE`), the current paragraph up to a
  blank line (`SCOPE_CHUNK`), or everything back to the last equal-or-stronger conditional
  (`SCOPE_NEST`) (`SetupString.pl:112-162`).
- **The clause itself** is `subject predicate`, chainable with `et` (and), `nisi`
  (and-not), and `aut` (or; binds loosest — split first) (`SetupString.pl:264-303`).
  Recognised **subjects** (`SetupString.pl:18-38`): `rubrica`/`rubricis` (→ `$version`),
  `tempore` (liturgical season, via `get_tempus_id`), `missa`, `communi`, `die` (a named
  day via `get_dayname_for_condition`), `feria` (weekday number), `commune`, `votiva`,
  `officio`, `ad`, `mense`, `dioecesis`. Recognised **predicates**
  (`SetupString.pl:39-60`): `tridentina`, `monastica`, `innovata`/`innovatis`, `paschali`,
  `post septuagesimam`, `prima`/`secunda`/`tertia`, `longior`/`brevior`,
  `summorum pontificum`, `feriali`. An unrecognised predicate (e.g. `196` in
  `sed rubrica 196`) falls back to being tested as a regex against the subject's value
  — this is why `(sed rubrica 196)` and `(sed rubrica 1960)` both work: `rubrica` resolves
  to `$version`, and `196`/`1960` is just matched against it as `/196/i` / `/1960/i`.

For our purposes (1960 rubrics only, one rite, no missa), most of this space collapses:
every conditional we'll ever need to evaluate reduces to `rubrica` matched against a
fixed `$version`, or one of the day/season/feria subjects evaluated against a fixed date
— `BreviariumData` can resolve every conditional whose subject isn't day-dependent at
build time (per `CLAUDE.md`'s "conditionals that depend on the day stay in the data"
rule) and leave the rest as structured data for the Kit.

## The `@` cross-reference / inclusion directive

Matched by `$InclusionRegex` (`SetupString.pl:305-312`):

```
@[Filename][:Section][:Substitutions]
```

- `@Sancti/02-22` — no section given, so it pulls the **same section name** as the one
  containing this reference, from `Sancti/02-22.txt`.
- `@Sancti/02-22:Oratio` — pulls the `[Oratio]` section specifically.
- `@:Ant Laudes` — no filename, so it's a **self-reference**: pulls the `[Ant Laudes]`
  section from the *same file*.
- `@Commune/C3:Section:2-4` — an optional trailing `:substitutions` clause performs
  line-based editing on the included text: a bare number or range (`2-4`, `!2-4` negated)
  selects/excludes lines (1-indexed), or `s/pattern/replacement/flags` does a Perl-style
  regex substitution (`do_inclusion_substitutions`, `SetupString.pl:491-505`).

A reference appearing in the file's **preamble** (before any `[Section]` header) is a
**whole-file inclusion** — every section from the referenced file is pulled in as a
fallback default for any section this file doesn't define itself
(`SetupString.pl:657-668`).

## `$Name` and `&Name` macros

- **`$Name`** — a literal-text lookup into `Psalterium/Common/Prayers.txt`'s `[Name]`
  section, via `prayer($name, $lang)` (`LanguageTextTools.pm:153-165`). E.g. `$Per
  Dominum` expands to the standard collect-ending formula (`Prayers.txt:188-190`):
  ```
  r. Per Dóminum nostrum Jesum Christum...
  R. Amen.
  ```
- **`&Name`** — dispatches to a Perl subroutine tagged `:ScriptFunc` in
  `web/cgi-bin/horas/horasscripts.pl`, which *computes* the text rather than returning it
  verbatim — used wherever the right text depends on more than a static lookup: `&teDeum`
  runs Alleluia-insertion logic for Paschaltide; `&Gloria` omits itself during the Triduum
  or switches to the Requiem form (`horas.pl:298-310`, `adjust_refs`); `&Deus_in_adjutorium`
  picks ferial/festal/solemn tone (`horasscripts.pl:27-59`).
  **`&Dominus_vobiscum1`/`&Dominus_vobiscum2` are the priest-toggle mechanism**: when
  `$priest` is false, both resolve to `&Domine exaudi` instead
  (`horas.pl:443-452`, `get_link_name`), which in turn looks up the "Dómine, exáudi..."
  form from `Prayers.txt` rather than "Dóminus vobíscum...". This is the exact source of
  `CLAUDE.md`'s priest-toggle requirement.

## Typographic/rubric markers

Handled in `horas.pl`'s line-rendering pass (`resolve_refs`, `horas.pl:150-186`), all
purely presentational (not liturgical-structural):

- `!!!text` — small, struck-through/omitted-style title.
- `!!text` — large chapter/section title.
- `!text` — a **red rubric line** (this is what `!Isa 1:1-3` scripture citations and
  standalone rubric notes both use — DO renders the whole line in red).
- `r.X` / `v.X` (lowercase) — decorative drop-cap styling for the first letter of an
  opening line (hymn/psalm incipit typesetting), not a liturgical marker.
- `V.`/`R.`/`Ant.`/`Benedictio.`/`Absolutio.`/`Responsorium.` (uppercase, as literal text
  at the start of a line) — DO renders these prefixes in red and leaves the rest of the
  line as-is (`horas.pl:142-148`). **We deliberately diverge here**: per `CLAUDE.md`'s
  visual spec, our renderer drops these labels entirely and conveys versicle vs. response
  purely through indentation and italics — a presentation decision already settled, not
  something this document is proposing to change.

## `[Rank]` field format

`Title;;DegreeLabel;;NumericPrecedence;;CommuneReference`, e.g.
(`Sancti/01-18r.txt:4-5`):

```
[Rank]
;;Simplex;;1.1;;vide C6-1
```

The leading empty field before the first `;;` gets auto-filled from `[Officium]`'s title
if the file has one (`SetupString.pl:708-712`), which is why examples in the wild often
look like they start with an empty field. `NumericPrecedence` is the *old* (pre-1960)
nine-or-so-grade scale (Simplex, Semiduplex, Duplex, Duplex majus, Duplex II classis,
Duplex I classis, plus fractional sub-grades for fine-grained tie-breaking) — DO uses this
scale internally for every version's precedence comparisons, then maps it to
version-appropriate *display* names separately. See `docs/rubrics-1960-vespers.md` for
the 1960-specific display mapping and how the comparisons actually work.

## Calendar data files (`web/www/Tabulae/`)

- **`data.txt`** — one row per rubrics version: `version,kalendar,transfer,stransfer,base,
  transferbase`. `Rubrics 1960 - 1960` has `base = Reduced - 1955`
  (`Directorium.pm:31-42`).
- **`Kalendaria/<kalendar>.txt`** — the sanctoral calendar for one version, but
  **each file only lists its *changes* from its `base` version** — `1960.txt` is a 38-line
  diff against `Reduced - 1955`, which is itself a diff against `Divino Afflatu - 1954`,
  and so on back to `1570.txt` (223 lines), which is the actual full base calendar. A date
  entry is `MM-DD=fileref` (extra `=`-separated fields exist in some files but aren't
  parsed by `load_kalendar` — `Directorium.pm:78-92` — so they're not load-bearing;
  they read like maintainer annotations of the title/rank, redundant with what's actually
  in the referenced Sancti file). `fileref = XXXXX` means "this date has no sanctoral
  office in this version" (removes whatever the base version had). Multiple entries
  separated by `~` mean multiple candidates/commemorations for that date.
  `get_from_directorium('kalendar', $version, $key)` (`Directorium.pm:200-224`) is what
  actually walks the `base` chain to resolve a date to its final proper file, checking the
  version's own file first and falling back up the chain — `BreviariumData` needs to
  reproduce this walk (or, more likely, pre-flatten it once at build time into a single
  resolved 1960 calendar table, since we only ever need the one version).
- **`Ordinarium/Vespera.txt`** — the section skeleton for Vespers; see
  `docs/rubrics-1960-vespers.md` for its content and how it maps to our page structure.

## What M1 did *not* fully chase down

In the interest of not trying to reverse-engineer a 2,344-line precedence engine
(`horascommon.pl`) line-by-line before writing any code: the `occurrence()` and
`concurrence()` functions (also in `horascommon.pl`) contain many branches for rubric
versions and rites this project doesn't target (Tridentine, Cistercian, Monastic,
Dominican, pre-1955 Divino Afflatu...). `docs/rubrics-1960-vespers.md` extracts and cites
the 1960-specific logic in enough detail to design the engine and the oracle-testing
strategy around, but M4's oracle diffing against real DO output — not a second read-through
of this file — is the actual correctness backstop, per `CLAUDE.md`'s own testing
philosophy ("never fix a failing oracle test by editing the fixture").
