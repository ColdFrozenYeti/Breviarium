# Beta 2 retrospective

Beta 2 set out to add the six day hours (Lauds, Prime, Terce, Sext, None and Compline) to
Beta 1's Vespers, in both psalters and with the English, and to let the app open any of
them. It ran from B2-M0 to B2-M6 in one overnight session on the same branch. The details
are in [`PLAN.md`](PLAN.md), under "Beta 2"; this is the short version.

## Where it ended

- **Every day hour matches Divinum Officium on every day from 2025 to 2040:** content and
  coverage in Latin and English, the pairing of the two, and the day title
  (`dayHoursFullRangeAudit`). With the Pius XII psalter, the content and every psalm's
  title and verse list match too (`dayHoursFullRangeBeaAudit`).
- **Vespers stayed at zero** on all five of its full-range audits through every change to
  the code the hours share.
- **35 named edge cases**, from Christmas Eve to Holy Saturday's Compline and the Greater
  Litanies, each pass against DO's page for their date.
- **The app** opens on the hour for the time of day and switches hours from the title.
  App CI builds it, runs every UI test and captures each hour's pages.

## What went right

**The one-page debug audit.** `debugOneDayHour` prints one hour for one date together
with the same audit the full-range sweep runs, in about ten seconds. Most fixes went from
a line in the sweep's report to a clean single-date audit without waiting for another
hour-long sweep.

**Reading DO's own Perl, and running it.** When the source didn't explain a result (Our
Lady on Saturday on 11 January, St Romanus on 9 August), a copy of DO's scripts with a
few `print STDERR` lines showed exactly which office and which commemorations DO had
chosen, and the fix followed from the line that chose them.

**The plan's order.** Compline and the little hours first, then Prime and Lauds, meant the
simple hours were at zero before the hard one began, and every Lauds fix was checked
against the hours already done.

## What went wrong

- **Silent hour-long runs.** Swift Testing prints a parameterised test's report only when
  it ends, and one run compiled while a test file was being edited, so it ran an old
  binary. Build first, then run the test binary directly (`audit2.sh`), one process per
  hour group.
- **A debug script that hid output.** A `grep -v` meant to drop test chatter also dropped
  lines of the office, and looked like a crash. The script now runs the binary unfiltered.
- **SwiftPM's lock.** Two `swift test` runs on one build folder queue behind each other;
  running the test binary directly avoids it.
- **Fixture size.** 168 MB, over the plan's estimate, mostly Lauds and Prime.

## Carry into the next beta

- **The title block's commemoration line** (*Commemoratio ad Laudes tantum: …*), planned
  for B2-M4, is still not built. DO computes it in `occurrence()` (`$officename[2]`,
  `horascommon.pl:538-830`) over many branches ("Tempora:", "Scriptura ut in:",
  "Transfer:", the Vespers forms), and it needs its own audit against the header row of
  every fixture. The app already shows the line when the engine gives one.
- **XXL hyphenation** and **landscape verification** (Beta 1 carry-overs), unchanged.
- **Matins and the Martyrology**, the next hours; then the Ambrosian rite.
