# Alpha retrospective

The alpha set out to put **Roman Vespers, 1960 rubrics**, on an iPhone: computed by the
app itself for any date, fully offline, styled after Universalis's night mode, built
with no Mac, and installed by sideloading with a free Apple ID. It ran from
M0 (repository and CI) to M6 (sideload release), across many sessions. The full blow-by-blow
is in [`PLAN.md`](PLAN.md). This document is the short version: what worked, what didn't,
and what to carry into the betas.

## Where it ended

- **The engine matches Divinum Officium on every evening from 2025 to 2040.** That covers
  every section (psalmody, chapter, hymn, versicle, Magnificat, collect, conclusion) and
  every commemoration, in both directions: nothing wrong shown, nothing missing.
- **An out-of-sample year agrees too.** All of 2044, with the priest form on and off,
  passes on the first run. The engine was never tuned against it.
- **The app** renders the office like a printed book: text flows line by line across
  pages, with a slide or page-curl turn, or a vertical scroll. Settings cover the priest
  form, rubrics, text size, and the reading modes. Measured against the reference
  screenshot, the body typography matches it to within about half a point.
- **The pipeline** works end to end without a Mac. Linux or Windows runs the engine and
  its tests; GitHub's macOS runners build the app and take its snapshots; Windows signs
  and sideloads the `.ipa`.
- **Deferred to beta:** parallel English, the other seven hours, and the Ambrosian rite.

## What went right

**Divinum Officium as an oracle, not just a text source.** Rendering DO's own Vespers
for every day of a 16-year range, and diffing the engine against it, turned "is this
rubrically correct?" into a mechanical question with a yes/no answer per date and per
section. Nearly every real bug in the project was found this way, and the mismatch
counts were a reliable progress measure. At the start of the later bug hunts the counts
per section were 51, 28, 11, 13, 11, 9 and 0 mismatched dates; at the end they were all 0.

**Never guessing a rubric.** The rule was that every fix cites the Perl line it ports
(`horascommon.pl`, `orationes.pl`, `specials.pl`) and a real fixture that proves it. It
was slower up front and much faster overall. When a fix was grounded in the real
mechanism, it often closed several unrelated-looking dates at once. For example:
- One "No Commemoratio" rule fixed 9 dates.
- The O-Antiphon date fix closed a whole cluster.
- Reading `occurrence()`'s Holy Family condition closed the last 4 dates of a cluster
  that two earlier attempts had failed on.

**Measure before and after every change, and revert on any regression.** A full sweep
against the last known baseline before every commit meant the mismatch counts only ever
went down. The discipline caught real regressions before they landed, several times:
- the leap-year Holy Name fix first broke Christ the King and Holy Family;
- the "No Commemoratio" exception clause broke three confirmed dates;
- the Lenten-Saturday fix first sent the Oratio count from 14 up to 30, which led to the
  real, missing "two concurrent Tempora" rule.

**Narrow fixes over general ones.** The two failed attempts at the Epiphany/Holy Family
cluster were broad changes to the concurrence cascade, and both regressed widely. The
fixes that landed cleanly were each scoped to one mechanism, one date shape, one
condition.

**Designing around "no Mac" from day one.** The engine was kept to pure Swift and
Foundation so it builds and tests on Linux and Windows. That meant almost all of the
real work (M0–M4, and most bug hunting) happened without a Mac or a simulator. CI
compiled the new TextKit reader on its first run.

**Adapting the plan when facts changed.** Dropping the paid Apple Developer Program early
(sideloading instead of TestFlight) was absorbed with one amendment. The pipeline was
restructured so that TestFlight can later be added as a single extra step.

**Asking at the right moments.** The user made the decisions that were genuinely theirs,
case by case: paging as a book rather than per section; the reading modes; English
deferred; the title sizes kept despite the screenshot; the UIKit exception. The rest
followed the documented rules.

## What went wrong

**Blind spots in the tests, found late.**
- **The content audit could not see omissions.** It only checked that what the engine
  showed appeared in DO's output. A commemoration the engine silently *dropped* passed.
  A reverse audit, added only in the last session, found **89 dates** of missing
  commemorations, most of them Sundays commemorated at a feast's Vespers. The lesson:
  every oracle check needs both directions from the start.
- **The app and the tests built the calendar differently.** The app forgot one of three
  calendar tables (`temporaRedirect`). On **262 dates** the phone showed Vespers other
  than what the tests had verified. Nothing caught it because the tests never went
  through the app's code path. It is now fixed with one shared factory and a regression
  test. The lesson: tests should exercise the same construction path the product uses.
- **UI tests leaked settings between runs.** A text-size choice persisted in the
  simulator and one snapshot came out at XXL, which briefly made a measurement misleading.
  Tests now pin their settings at launch.

**Estimates that were wrong.**
- **The "5 bugs left" figure was stale more than once.** A full recount in one session
  turned "4 bugs" into 11 distinct root causes. Headline numbers should be recounted
  before being trusted, not carried forward.
- **Some spec measurements didn't match the reference.** `CLAUDE.md`'s title-size ratios
  (name 1.3×, hour title 1.5×) measure much larger than the screenshot (about 1.0× and
  1.2×). `CLAUDE.md` also names a reference file, `universalis-compline-night.png`, that
  doesn't exist; the real one is `Format.png`. The user chose to keep the ratios, but the
  spec should have been measured with a tool, not by eye, from the start.

**Rendering took two tries.** The first SwiftUI renderer paginated by measured heights and
cut a hymn stanza off mid-line, so paging was dropped for a single scroll. It came back
properly only when the renderer moved to TextKit, which lets text flow across pages.
Choosing the text engine for book-style layout first would have saved a detour.

**Silent failures in the tooling.**
- Swift's `Regex` has no lookbehind, and the code's `matches` helper treated a pattern
  that failed to compile as "no match". A ported Perl rule (`(?<!De )Dominica`) did
  nothing until noticed. Helpers like that should fail loudly.
- One commit accidentally included a temporary debug test. It was removed in the next
  commit, but a pre-commit check for scratch files would have caught it.

**Cloud-session friction.** The cloud container had no Swift toolchain, and
`download.swift.org`, CPAN and Debian mirrors were blocked. Workarounds were found
(Swift from a Docker image mirror, Divinum Officium run directly with Perl after verifying
byte-identical output), and GitHub artifact downloads were unblocked by a network-setting
change. It cost time each session; `PLAN.md` now records the recipe.

## Carry into the betas

1. **Two-directional oracle checks for every new hour.** For each of Lauds, Matins and
   the rest: a content audit and an omission/commemoration audit from the first commit,
   plus a hold-out year with every option combination.
2. **Tests must go through the app's own construction path.** The `makeSanctoralCalendar()`
   pattern generalises: one factory, used by both the app and the tests.
3. **English needs its own oracle.** DO's English fixtures exist for the spot-check set.
   The beta should generate a full English range before building the parallel layout, so
   alignment (verse by verse, stanza by stanza) is tested, not eyeballed.
4. **Keep fixes narrow, keep the baseline sweep, keep reverting on regression.** It is
   what made a 16-year, zero-mismatch result possible.
5. **Measure the design, don't estimate it.** The pixel-measuring script used for M5
   should become a standing check that compares snapshots against the reference numbers
   automatically, instead of a manual step.
6. **The Ambrosian rite has no oracle.** Divinum Officium doesn't contain it, so the
   method that made the Roman office reliable doesn't transfer directly. Decide early what
   the source of truth will be: printed editions, hand-checked fixtures, or both.
