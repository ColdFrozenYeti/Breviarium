# Beta 4 retrospective

Beta 4 set out to add the Little Office of Our Lady, the Office of the Dead, the
Martyrology, the liturgical colour in the calendar, and inline directions as rubrics, and
to hand over a pull request and an IPA to try on the phone before anything is merged. It
ran from B4-M0 to B4-M6 in one session, without stopping at the milestone gates, as
agreed. The details are in [`PLAN.md`](PLAN.md), under "Beta 4"; this is the short
version.

## Where it ended

- **The Little Office matches Divinum Officium** at every hour on every day of 2026 and
  2027, in Latin, English and the Pius XII psalter, and in all of 2044 with the priest on
  and off.
- **The Office of the Dead matches DO** at Matins, Lauds and Vespers on every day of
  2026, the same ways.
- **The Martyrology matches DO** on every Prime page from 2025 to 2040 and in 2044.
- **Every Beta 3 audit is still at zero** (Vespers, the day hours, Matins over 16 years).
- **The app** has the office setting, the Martyrology hour and the colour calendar, with
  snapshots of each.

## What went right

**Votives as a different winner, not a second engine.** DO swaps a Commune in after
occurrence; doing exactly that meant everything already built (conditionals, psalters,
English, Matins) worked for both offices from the first run. What remained were
differences in *which* global DO reads, each one small and citable.

**One question for every audit line: what does DO read here?** Most of the remaining
differences came from the same place: DO excludes votives from some season checks
(`alleluia_required`) but not others (`$dayname[0]`). Tracing each line to the variable
DO reads, rather than to the symptom, fixed classes of dates at a time.

**The Martyrology was right almost first time.** Porting `_luna_table` literally,
arithmetic quirks included, gave the moon's age for 17 years with no tuning; the only
miss was Christmas's inline direction.

## What went wrong

**The plan assumed something DO doesn't do.** "The Office of the Dead on All Souls must
equal the day's office" was written before reading the fixtures; DO gives the votive
its own lessons. The test now checks each against DO. Next time, check a plan's claimed
equivalences against the oracle while writing the plan.

**The disk filled up mid-regression.** Old scratch builds and extracted fixtures from
earlier betas used the whole allowance, and the local regression died silently. The
same audits ran on CI, so nothing was lost but time. Next time, clean scratch builds
at the start of a beta and extract fixtures inside the scratchpad only.

**The first snapshots found two layout bugs the audits can't see.** The special hours'
hymn came out one line per paragraph and their antiphons as verses; the text was right,
so the oracle passed. Next time, render a new kind of hour in the debug dump as the app
will lay it out (units, not just text) before the audit, not after.

**A docs push cancelled a CI run.** On a pull request, every push re-runs every workflow,
so pushing docs mid-run cost an App CI cycle. Next time, batch docs commits until the
checks on the code commit have finished.

## Carry forward

- Clean up scratch builds and old fixture extracts at the start of each beta.
- Write a plan's "must equal" claims only after checking them against DO.
- Look at the unit kinds for any new hour shape, not only its text.
- Hold docs pushes while a pull request's checks are running.
