# Beta 5 retrospective

Beta 5 set out to add the Dominican office, Divinum Officium's *Ordo Prædicatorum -
1962*, as a second rite behind the engine's rite interface: every hour, its Little Office
and Office of the Dead, both psalters, the English by decisions 5 and 6, and fixtures
for every day from 2025 to 2040 plus 2044. It ran from B5-M0 to B5-M6 without stopping
at the milestone gates, as agreed. The details are in [`PLAN.md`](PLAN.md), under
"Beta 5", and what DO does for the Order in [`rubrics-op1962.md`](rubrics-op1962.md);
this is the short version.

## Where it ended

- **The Dominican office matches Divinum Officium** at every hour on every day from 2025
  to 2040, in Latin and English and in the Pius XII psalter, and in all of 2044 with the
  priest on and off. Its Little Office (2026 and 2027) and Office of the Dead (2026)
  match the same ways.
- **Where DO's Dominican data is in error, the app is right instead**, and the audit
  proves it page by page: each correction is switchable, and with it off the engine
  reproduces DO's broken page exactly. Every place where the app and DO part, corrected
  or not, is a row of `rubrics-op1962.md` §8 (38 rows).
- **Where the Order's own text isn't in DO at all**, the app shows nothing in its place
  rather than a guess, and §8 marks the case as needing a source (listed below).
- **Every Roman audit is still at zero**: Vespers, the day hours and Matins over 16
  years, the Little Office, the Office of the Dead and the Martyrology.
- **The app** has *Ritus: Dominicanus* with its own *Officium* choice, the grey note
  under a borrowed Roman English text, and snapshots of every Dominican hour.

## What went right

**The rite as a path adjustment, not a second engine.** DO runs the Order through the
Roman engine, reading `…OP` files and sections where they exist. Doing the same
(`Rite.adjusted`) meant the Roman office's conditionals, psalters, English and Matins
worked for the Dominican rite from the first run, and the Roman audits never moved.

**Corrections that the audit can still see through.** Every fix of a DO data error is a
named, switchable correction. The audit runs each corrected page both ways: with the
correction off it must equal DO's page, with it on it must differ only where the
correction says. A correction can't hide an engine bug.

**Porting Perl's semantics literally.** Several residuals were Perl behaviours rather
than rubrics: a `splice` past the end selects nothing, a substitution's `J` must match
an `I`, a `1960` test on the version name doesn't fire for "1962". Copying what the Perl
does, quirks included, closed whole classes of dates at once.

## What went wrong

**DO's `/1960/` tests had to be found one by one.** The Dominican version's name
contains "1962", so every DO branch that tests the name for "1960" silently takes the
pre-1960 path for the Order. B5-M1 found the Martyrology's; the rest (Sunday
commemorations, *Festum Domini*, Ash Wednesday at second Vespers) turned up as audit
residuals over five rounds. Next time a rite or version is added, grep DO for every
version-name test first and decide each one before writing code.

**Two fixes regressed other dates, and only CI's full range showed it.** Giving first
Vespers after Ash Wednesday to tomorrow's saint gave it to St Matthias (II class), and
reading the month's Scripture in resumed Epiphany weeks gave saints Galatians. Each was
checked on the dates it fixed, not on the hour's whole range. Next time, run the
affected hour's full local audit before pushing an engine change.

**The audit's reconciliation grew large.** DO's Dominican English is in places mangled
or mistranslated (responsories run together, hymns from another feast), and the audit
learned to recognise each case. Every rule is narrow and named, but the list is long,
and a long list is where a real bug could hide. Next time, prefer correcting the data
(with the switchable correction) to teaching the audit about it.

**The local machine was the bottleneck.** Four cores ran the 16-year Dominican audits
slowly, Docker went down twice and took running audits with it, and CI's Dominican jobs
took over an hour. Next time, split the long Dominican audits on CI as the Roman ones
were split in B5-M0, and use CI rather than the container for whole-range runs.

**A push cancelled the audits it was meant to complement.** Pushing a fix for one failed
job cancelled four Dominican jobs that were nearly done, so their results came a cycle
later. That is the concurrency rule working as designed; the cost is worth knowing when
choosing when to push.

## Needs a source (from `rubrics-op1962.md` §8)

The app shows nothing, or DO's text, in these places until a Dominican breviary
supplies the Order's own text:

- the Ascension's first Vespers responsory;
- the Crown of Thorns (24 April) outside Matins;
- St Agnes (21 January), the second antiphon of the first nocturn;
- St Catherine of Siena (30 April) and St Thomas Aquinas (7 March) at Matins;
- the vocative names in the versicle before Lauds on many saints' days;
- 2 June's Paschal commemoration antiphon;
- the responsories of vigils with three lessons (23 June);
- Our Lady on Saturday with Mount Carmel commemorated, the third responsory;
- All Saints of the Order (12 November), second Vespers' psalmody;
- the Martyrology under *Dominicanus* (decision 4: the 1960 Roman one).

## Carry forward

- Before adding a rite or version, list every DO branch that tests the version's name.
- Run the affected hour's full-range audit locally before pushing an engine fix.
- Prefer a switchable data correction to an audit-side exception.
- Split any audit job over 20 minutes on CI, Dominican ones included.
