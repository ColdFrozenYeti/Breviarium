# Beta 3 retrospective

Beta 3 set out to add Matins, the new icon and the title block's third line, and to hand
over a pull request and an IPA to try on the phone before anything is merged. It ran
from B3-M0 to B3-M5 in one overnight session on the same branch, with a break when the
usage limit was hit and the container was restarted. The details are in
[`PLAN.md`](PLAN.md), under "Beta 3"; this is the short version.

## Where it ended

- **Matins matches Divinum Officium on every day from 2025 to 2040**, in Latin and
  English, and with the Pius XII psalter (the results are in the morning report and on
  the pull request's Oracle audits run).
- **The title block's third line** (commemoration, *Tempora*, *Scriptura*, *Transfer*)
  matches DO's page head for every hour from Matins to None on every day: a new,
  two-minute audit.
- **25 Matins edge cases** joined the named list, from Christmas to Tenebræ and Mount
  Carmel on a Saturday; all 70 pass.
- **The app** has Matins first in the picker and opens on it after midnight; lessons read
  as prose.

## What went right

**Auditing one year first.** 2026 alone took about five minutes. Driving it to zero
before running the other fifteen years meant the full run found only six new dates, each
a rule 2026 never exercised (the octave Sunday, 12 January in a letter-`f` year, Mount
Carmel on a Saturday).

**Porting the resolver's order, not patching the symptom.** The Rosary's hymn, the
Pentecost versicle and the Baptism of the Lord's antiphons each looked like a Matins bug.
All three were the shared text resolver doing something in a different order from DO
(substitutions before nested references; Perl escapes; files from other rites). Fixing
the resolver fixed them everywhere.

**A fast audit for a small thing.** The head line needed no hour assembly, so its audit
reads only each fixture's first row and runs all six hours over 16 years in about 80
seconds. It went from a first draft to zero in three rounds.

## What went wrong

- **A stale binary.** One audit run printed a compile error at its top and then ran the
  previous build, so the report looked like a regression. The scripts now show build
  errors first; read them before the report.
- **Rebuilding under a running audit.** Rebuilding the shared scratch path while the
  parallel year runs were still starting meant later years ran newer code than earlier
  ones. A second scratch path (`/tmp/b4`) for one-off checks avoids it; the final
  results come from one clean run.
- **The first 1960-responsory rule was wrong.** Taking `Responsory<n> 1960` from the
  lesson's source fixed 2026 and broke Ss. John and Paul in 2025. DO takes it from the
  winning office; reading `%w`'s provenance in the Perl first would have saved a round.
- **The container restarted** during the usage-limit pause. Nothing was lost, because
  work had been committed and pushed at each step, but Docker had to be started again.

## Carry forward

- Commit and push after every green step, not only at milestones.
- For a new rule, find where DO's hash (`%w`, `%winner`, `%commune`) was filled before
  porting where it's read.
- Beta 4 (the Little Office, the Office of the Dead, the Martyrology) reuses Matins'
  lessons and responsories; the `.lesson` unit and the nocturn sections are ready for it.
