# Beta 1 retrospective

Beta 1 set out to add the **Vulgate psalter** (now the default, with the Pius XII psalter
as an option) and the **parallel English** to the alpha's Roman Vespers. It ran from B1-M0
(housekeeping) to B1-M6 (release) in one pull request. The details are in
[`PLAN.md`](PLAN.md), under "Beta 1"; this is the short version.

## Where it ended

- **Both psalters match Divinum Officium on every evening from 2025 to 2040:** content,
  commemorations, and every psalm's title and verse list. The 2044 hold-out passes in both
  psalters, with English, and with the priest on and off.
- **The English matches DO's bilingual page** on every evening from 2025 to 2040, checked
  four ways: everything we render is on DO's page, nothing of DO's English or Latin is
  missing, and each Latin–English pair sits in the same DO row.
- **The day title matches DO's** on every evening from 2025 to 2040, including
  first-Vespers evenings and the monthday suffix ("… III. Augusti").
- **The app** has a live English toggle and a psalter picker. English on shows Latin and
  English side by side, flowing across book pages (slide or page curl) or in a vertical
  scroll, with prose stacked in portrait.

## What went right

**Audits in both directions.** The alpha's content audit only asked "is everything we show
in DO's page?". Beta 1 added the reverse questions, and each one found real bugs the
alpha's audits had passed:
- the psalmody audit (a verse's two halves dropped at a divided psalm);
- the English coverage audit (the Oratio preamble, the Holy Thursday opening rubric, a
  missing hymn on some Saturdays in Paschaltide);
- the title audit (every first-Vespers evening showed the wrong day's title, a bug present
  since the alpha).

**Reading the Perl before fixing.** Every engine fix cites the DO line it ports, so none
was a guess, and none broke another audit.

**Snapshots as the UI's test.** With no Mac, the first English screenshots were the first
look at the two-column layout. They showed four rendering bugs at once, each fixed and
re-checked from the next run's screenshots.

**The CI split.** The full-range audits moved to their own workflow, so the fast suite
still reports in about 5 minutes.

## What went wrong

- **Pushes cancelled CI.** Concurrency cancels a PR's older runs, and a pull request's path
  filter looks at the whole PR, not just the latest push, so even an app-only push restarted
  the 20-minute oracle audits. Several App CI runs were lost this way. Batch pushes, and
  don't push while a run whose result you need is in flight.
- **Silent tooling failures.** The Docker daemon died mid-sweep and the log only said
  "Cannot connect". A `head -40` on a test log cut off the result lines, and the run had to
  be read from CI instead. Check a long run right after starting it, and never truncate the
  lines that carry the verdict.
- **An audit gap looked like an engine bug.** DO sometimes shows a Latin collect with an
  English name spliced in; the audit's J→I pass couldn't match that mixed text, and the
  failure took a full sweep to surface.
- **One UI test failure cascaded.** A failed landscape step left the simulator rotated, and
  every later Settings tap failed. Tests now reset the orientation at launch.
- **Landscape can't be seen reliably in screenshots.** The screen capture came back in the
  portrait buffer, cropped. It is now taken from the app window.

## Carry into Beta 2

- **The title block's commemoration line** is still never shown. The visual specification
  has it for 16 September 2026 (*Commemoratio ad Laudes tantum: …*); it needs building and
  auditing like the name line. The rank line (*III. classis*) isn't audited yet either.
- **XXL hyphenation.** In the narrow two-column layout at the largest text size,
  "sæculórum" still splits letter by letter: the system hyphenator has no break point for
  it. This needs a small Latin hyphenation exception list, or narrower margins at XXL.
- **Landscape verification.** Confirm the two-column landscape layout on the phone, and in
  the window-based captures.
- **The rest of the brief:** the other seven hours, the Ambrosian rite, the Martyrology at
  Prime, and the votive offices.
