# 1960 rubrics: how Vespers is decided

Companion to `docs/do-format.md`. That document covers the file *syntax*; this one covers
the *rubrics* — how DO decides what office is prayed, how first/second Vespers works, how
commemorations are chosen, and a proposed section/page structure for our Vespers view.

As in `do-format.md`: every claim is cited to `horascommon.pl` (2,344 lines — line numbers
below are from the pinned commit) or another named source file, and I've flagged the
handful of places where I'm reading intent from code rather than having watched it run.
This document is scoped to **secular Roman rite, 1960 rubrics, Vespers** — the engine
functions cited (`occurrence()`, `concurrence()`) handle many other rites and historical
rubric versions in the same functions; branches for those are not discussed here.

## 1. How the office of the day is decided (occurrence)

`occurrence($day, $month, $year, $version, ...)` (`horascommon.pl:19`) computes, for one
calendar day: the temporal office (`%tempora`, from `web/www/horas/Latin/Tempora/`) and
the sanctoral office (`%saint`, from `.../Sancti/`, resolved via the Kalendaria chain
described in `do-format.md`), then decides which one **wins the day** —
`$sanctoraliffice` true/false, `$winner` set to whichever file.

### The rank scale

Every office's `[Rank]` field carries a numeric precedence (`do-format.md`'s `[Rank]`
section). The scale, confirmed from `officium.pl:70`'s own comment and cross-checked
against `Psalterium/Comment.txt`'s rank-name tables:

| Numeric | Old grade | **1960 display name** |
|---|---|---|
| 0 | (none/feria) | Feria |
| 1 | Simplex | IV. classis |
| 2 | Semiduplex | III. classis |
| 3 | Duplex | III. classis |
| 4 | Duplex majus | III. classis |
| 5 | Duplex II classis | II. classis |
| 6 | Duplex I classis | I. classis |
| 7 | (above — highest) | I. classis |

The right-hand column is `Psalterium/Comment.txt`'s `[Festa] (rubrica 196)` block
(lines 58-66), which is the exact list of display strings 1960 rubrics substitutes for
the pre-1960 duplex/semiduplex nomenclature — this is the direct source for our own
title-block's "III. classis" style labels, and it's a **clean collapse**: five of the
eight numeric grades (1-4) map to only two 1960 display tiers (IV. and III. classis).
Fractional sub-grades (e.g. `1.1`, `2.99`, `4.9`) exist purely for fine-grained
precedence *comparison* between offices of the same nominal grade — they round down to
the same display name as their integer floor.

### The comparison

The core decision (`horascommon.pl:471-505`):

- If the sanctoral office has no real rank, or (`version =~ /196/`) its rank is `≤ 1.1`,
  or it's the Saturday-Our-Lady commemoration reduced to a mere commemoration: **temporal
  wins** (`$sanctoraloffice = 0`).
- Else if the sanctoral rank **numerically outranks** the temporal rank: **sanctoral
  wins** — the ordinary case.
- Else, if today is a Sunday (`$trank[0] =~ /Dominica/i`), the sanctoral office can
  *still* win even without outranking the Sunday numerically, but only in specific
  1960-rubrics cases (`horascommon.pl:486-497`, my emphasis on the exact source comments):
  - *"With the 1960 rubrics, II. cl. feasts of the Lord and all I. cl. feasts beat II. cl.
    Sundays."* — i.e. rank ≥ 6 always beats a Sunday of rank ≤ 5, and rank ≥ 5 beats it
    too specifically when the feast is a *Festum Domini* (feast of the Lord).
  - *"RG 15: As an exception to the general rule, the Immaculate Conception is preferred
    to the Second Sunday of Advent in occurrence (but not in concurrence)"* — a single
    named exception, citing the General Rubrics directly in the source comment.
- Otherwise the Sunday (or other outranking temporal office) wins.

I have **not** independently verified the *RG* (Rubricae Generales / Codex Rubricarum
1960) section numbers cited in the source comments against the actual 1960 Codex text —
they're DO's own citations, reproduced here because they're exactly the kind of precise,
checkable claim `CLAUDE.md` asks for, but "the code comment cites RG 15" and "RG 15 says
this" are two different confidence levels. Worth a direct check against the Codex before
M4 if any oracle-diff investigation ever turns on this specific rule.

## 2. Commemorations

When an office doesn't win the day outright but isn't excluded either, it's carried as a
**commemoration** rather than dropped. The Kalendaria calendar entry for a date can list
multiple candidate offices separated by `~` (`do-format.md`), collected into
`@commemoentries`; `occurrence()` and `concurrence()` filter this list down by rank
thresholds that differ depending on whether the commemoration is being added to *today's*
Vespers (occurrence-side filtering, `horascommon.pl` around 1373-1394) or to the *first
Vespers of tomorrow that today's second Vespers concurs with* (concurrence-side
filtering, around 1341-1365) — these are genuinely different rank thresholds, not the
same rule applied twice, which is why `CLAUDE.md`'s visual spec explicitly distinguishes
"every commemoration the 1960 rubrics require" as its own tested concept rather than
assuming occurrence and concurrence produce the same commemoration list.

I'm not restating every numeric threshold from that block here with full confidence —
they interact with the occurrence/concurrence rank of the *winning* office in ways I'd
want to verify against rendered output rather than paraphrase from a single read-through.
What's solid: the mechanism (two separately-filtered commemoration lists, one per
direction) and where in the source it lives, both useful for M4 if a commemoration-related
oracle diff needs investigating.

## 3. First vs. second Vespers (concurrence)

`concurrence($day, $month, $year, $version, ...)` (`horascommon.pl:842`) calls
`occurrence()` twice — once for today, once (`$tomorrow = 1`) for tomorrow — and decides
whether today's office gets a **first Vespers of tomorrow's feast** instead of (or as
well as) its own second Vespers.

The 1960-specific rule, quoted directly from the source comment
(`horascommon.pl:958-966`):

> *"In 1960, II. cl. feasts have I. Vespers if and only if they're feasts of the Lord on
> a Sunday."*

implemented as: first Vespers is **suppressed** (`"No prima vespera"`) when tomorrow's
rank is below a threshold that is **5** if tomorrow is a Sunday, or tomorrow is a *Festum
Domini* and today is a Saturday; **6** otherwise. Concretely:

- Tomorrow's feast rank ≥ 6 (I. classis) → **always** gets first Vespers this evening.
- Tomorrow's feast rank = 5 (II. classis) → gets first Vespers **only if** tomorrow is
  itself a Sunday, or today is Saturday and tomorrow is a feast of the Lord.
- Anything lower → no first Vespers; today's own second Vespers (if any) stands
  unmodified by tomorrow's office (tomorrow may still get *commemorated*, per §2, without
  displacing today's Vespers outright).

Separately, ferias/vigils/octave days never get a first Vespers of their own
(`horascommon.pl:970-975`), and Vespers of Sunday itself follows the ordinary Sunday
rules rather than this feast-specific one.

**Practical consequence for the app** (this is the part `CLAUDE.md` calls out directly —
"Selecting a date and opening Vespers gives what is prayed on that evening, including
first Vespers of the next day where the 1960 rubrics require it"): when the user picks a
date and opens Vespers, the engine must run `concurrence()` for *that* date (not just
`occurrence()`), and if tomorrow's feast clears the threshold above, render *tomorrow's*
office (first Vespers) rather than today's own second Vespers — including tomorrow's
title block, matching DO's own behaviour for this case, which `CLAUDE.md` also asks us to
match exactly.

## 4. Priest toggle

Confirmed and cited fully in `do-format.md`: `&Dominus_vobiscum1`/`&Dominus_vobiscum2`
resolve to the "Dóminus vobíscum / R. Et cum spíritu tuo" form when `$priest` is true, and
to "Dómine, exáudi oratiónem meam / R. Et clamor meus ad te véniat" when false
(`horas.pl:443-452`). This is a presentation-layer swap, not an occurrence/concurrence
concern — it doesn't change what office is prayed, only how the versicle before the
collect is worded.

## 5. Proposed section headings and page grouping for Vespers

Sourced directly from `web/www/horas/Ordinarium/Vespera.txt` — the skeleton DO itself
renders Vespers from, reproduced and annotated below (see `do-format.md` for what `#`,
`$`, `&`, and the `(...)` conditionals mean):

```
#Incipit
  $rubrica Secreto / $Pater noster / $Ave Maria          <- (sed rubrica 196 ... omittuntur)
  $rubrica Clara voce
  &Deus_in_adjutorium
  &Alleluia

#Psalmi

#Capitulum Hymnus Versus

#Canticum: Magnificat

#Preces Feriales                                          <- conditional on day/season, not blanket-omitted for 1960

#Oratio

#Suffragium                                                <- (sed rubrica 196 ... omittitur): NOT used under 1960 rubrics

#Conclusio
  &Dominus_vobiscum / &Benedicamus_Domino
  $Fidelium animae
  $rubrica Pater post V / $Pater noster                    <- (sed rubrica 196 ... omittitur)
```

Two things worth calling out because they refine what `CLAUDE.md`'s own example section
list (INTRODUCTIO, HYMNUS, PSALMODIA, CAPITULUM, CANTICUM, ORATIO, CONCLUSIO — taken from
the *Compline* screenshot, `design/reference/Format.png`) might otherwise suggest:

1. **The silent Pater/Ave opening and the closing silent Pater are both omitted under
   1960 rubrics** (`(sed rubrica 196 ... omittuntur/omittitur)`, confirming what
   `Format.png`'s own INTRODUCTIO section already shows for Compline — straight to *Deus
   in adiutórium*). The `#Suffragium` (daily suffrage of the saints) is dropped
   outright for 1960, so it isn't one of our sections at all.
2. **Hymnus comes *after* Capitulum at Vespers**, grouped with Versus
   (`#Capitulum Hymnus Versus`) — unlike Compline, where the hymn (*Te lucis ante
   terminum*) opens the hour right after the Introductio. `CLAUDE.md`'s example heading
   *set* (the all-caps names) still applies; the *order* it's given in was a Compline
   example and shouldn't be read as prescribing Vespers' order too.

**Proposed heading-to-Ordinarium mapping** (for your review, per `CLAUDE.md`'s
requirement that this be approved before engine code):

| Our heading | Ordinarium source | Content |
|---|---|---|
| INTRODUCTIO | `#Incipit` | *Deus in adiutórium* + *Glória Patri* + *Allelúia* (or *Laus tibi* in Lent) |
| PSALMODIA | `#Psalmi` | 5 psalms with antiphons, Bea psalter text, doxology |
| CAPITULUM | (first part of) `#Capitulum Hymnus Versus` | Little chapter |
| HYMNUS | (second part of) `#Capitulum Hymnus Versus` | Office hymn |
| VERSUS | (third part of) `#Capitulum Hymnus Versus` | Short versicle/response |
| CANTICUM | `#Canticum: Magnificat` | Magnificat antiphon + canticle + doxology |
| ORATIO | `#Oratio` | Collect of the day, **plus every occurring/commemorated
  office's own collect** (from the §2 commemoration lists — these aren't in the
  `#Suffragium` slot, since that's specifically the fixed daily suffrage of all saints,
  which 1960 drops; per-day commemorations are a separate mechanism) |
| CONCLUSIO | `#Conclusio` | *Dóminus vobíscum*/*Dómine exáudi* (priest toggle), *Benedicámus Dómino*, *Fidélium ánimæ* |

I split `#Capitulum Hymnus Versus` into three of our headings rather than keeping it as
one, since `CLAUDE.md`'s heading set already lists CAPITULUM/HYMNUS as separate
all-caps headings and the visual spec's body typography (§ "Antiphons, hymn stanzas,
chapter, and collect follow the same typographic system") treats them as distinct content
types even if grouped on one page. **Page grouping** (M5's concern, but worth settling
alongside the headings since `CLAUDE.md` asks for both together): given the "one page per
section group" rule and that Compline's example ran to 10 pages for a comparable but
shorter hour, my proposal is one page per row of the table above (7 pages), except
PSALMODIA, which — being five psalms — may need to span multiple pages itself depending
on rendered length at a given text size; that's better decided empirically in M5 once
real rendered text exists, not guessed here.

## 6. Does `regress/` give M3 a cheaper calendar oracle?

Checked during M1 per the open question in `docs/PLAN.md`: **no.** `regress/tests/*.testspec`
only lists *date ranges* worth exercising (e.g. "Circumcision to St Hilary"); DO's own
regression tooling (`regress/scripts/generate-diff.sh`) diffs full rendered output between
two git refs of DO itself, to catch regressions in DO's own code — it doesn't ship any
independent precomputed date→office mapping we could check M3's calendar engine against
more cheaply than the full oracle-fixture approach already planned in `docs/PLAN.md`.

## Open items for you

1. ~~The "Pius XII Psalter" option mapping is my working theory, not yet confirmed...~~
   **Resolved (2026-09-16):** confirmed via `officium.pl:133-137` — see `do-format.md`'s
   options table.
2. The RG (General Rubrics) section numbers cited in §1 are DO's own source comments,
   not independently checked against the 1960 Codex Rubricarum text.
3. The exact commemoration rank thresholds in §2 are described at the mechanism level,
   not restated as precise numeric rules — I'd rather that gap show up now than present
   false confidence.
4. §5's heading/page-grouping proposal needs your sign-off before M4/M5 build against it,
   per `CLAUDE.md`.
