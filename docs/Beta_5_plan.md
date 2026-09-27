# Breviarium — Beta 5 Implementation Plan (draft)

**Status: a draft for your approval.** Nothing in it has started. The questions at the
end need your answers before B5-M1.

## Context

Beta 4 was released on 27 September 2026: the Roman office of the day, the Little Office
of Our Lady, the Office of the Dead and the Martyrology, all checked against Divinum
Officium (DO). Beta 5 adds the second rite, as `docs/roadmap.md` orders it:

1. **The Dominican rite**: DO's *Ordo Prædicatorum - 1962*, with its own calendar, saints
   and commons. *Ritus: Dominicanus* in Settings stops being "Coming soon".
2. **The rite plug-in** (`CLAUDE.md`, *Rite abstraction*), built for the first time, on a
   rite that DO can check, before the Ambrosian rite (Beta 6), which it can't.
3. **Faster CI** (asked 2026-09-26): a push to a pull request costs about an hour today.

## What DO does (read at the pinned commit, 27 September)

This is a first reading. B5-M1 checks it hour by hour.

- **A version on top of the 1960 rubrics.** `Tabulae/data.txt:16` defines *Ordo
  Praedicatorum - 1962* (`OP1962`) with *Rubrics 1960 - 1960* as its base. Its calendar,
  `Kalendaria/OP1962.txt`, "only notes the differences to Rubrics 1960": 145 lines of
  Dominican saints (Bl. Jordan of Saxony, St Catherine de' Ricci…) and suppressed Roman
  ones.
- **Its own texts.** `TemporaOP` (427 files), `SanctiOP` (124) and `CommuneOP` (28), found
  through `horascommon.pl:2165` (`${subdir}OP/`). `CommuneOP` has its own Little Office
  (`C12`, `C12A`, `C12N`) and Our Lady on Saturday (`C10…`), but no `C9`, so the Office
  of the Dead would come from the Roman `Commune` (to be confirmed in B5-M1).
- **The Roman psalter, with Dominican sections.** There is no Dominican psalter tree.
  `psalmi.pl:169` swaps a section's number for `OP` where one exists (`[AdvOP]`,
  `[Quad5 OP]` in `Psalmi minor.txt`). Vespers can take its psalms under one antiphon
  (`psalmi.pl:555`).
- **The Roman engine, with branches.** About 30 `Praedicatorum` conditions across
  `horas.pl`, `horascommon.pl`, `psalmi.pl`, `hymni.pl`, `capitulis.pl`, `orationes.pl`,
  `specmatins.pl`, `horasscripts.pl` and `monastic.pl`. Examples:
  - Compline's own hymn and *Nunc dimittis* antiphon (`hymni.pl:27`, `horas.pl:533`);
  - a versicle before Lauds (`horasscripts.pl:149`);
  - Prime's reading from the Rule of St Augustine or the Gospel, cut at `¶`
    (`monastic.pl:592-644`, `Regula/OrdoPraedicatorum.txt`);
  - older hymn texts (`hymni.pl:154`, the `…T` variants).
- **English is thin.** `English/TemporaOP` has 15 files (Easter and Passiontide days); there
  is none for `SanctiOP` or `CommuneOP`. Decision 4 of the roadmap covers this: DO's
  Dominican English where it exists, the Roman English for texts that match the Roman
  ones, and otherwise Latin only.

So the Dominican provider can share most of the Roman one. The plug-in has to cover
what differs: the calendar, the file trees, the psalter sections, and a known list of
hour-assembly branches.

## Architecture

- **`Rite` protocol** in the Kit: the calendar (which files, which kalendarium),
  precedence, and hour assembly. `Roman1960` wraps today's engine without changing its
  output; every Roman audit must stay at zero through the refactor. `OrdoPraedicatorum`
  reuses `Roman1960`'s parts and overrides where DO branches.
- **The data tool** bundles `TemporaOP`, `SanctiOP`, `CommuneOP`, `Regula` and the OP
  kalendarium. It reports the size: expect a few MB.
- **English matching** for the Dominican texts is done at build time. When a Dominican
  section's Latin equals a Roman section's Latin after normalisation, it takes that
  section's English; otherwise it is Latin only. The data tool reports how many sections
  it matched.
- **The app** stays free of liturgical logic. It passes the rite to the Kit, and the
  hour picker lists the rite's hours.

## Oracle fixtures

A proposal, see question 2:
- `version=Ordo Praedicatorum - 1962`, every hour, **2026–2029**, Latin and English,
  priest off. Four years cover each Easter class and weekday letter, which is where
  Beta 3's Matins found its date-specific bugs.
- A **2044 hold-out**, priest off and on.
- **Vulgate only** (question 3).
- `generate-fixture-set.sh` takes the version as an argument; sizes and hashes go in
  `data/SOURCE.md`.

## Milestones

### B5-M0 — CI and housekeeping
Answers "why have the CIs become so long" (26 September). The three changes proposed
then:
- **Per-push change detection.** The workflows already have `paths:` filters, but on a
  pull request GitHub applies them to the whole pull request's diff against `main`, so
  once a pull request touches the Kit, every later push reran everything, a docs-only
  push included. Each workflow now starts with a small `changes` job
  (`scripts/ci-needs-run.sh`). It compares the head with the last commit on the branch
  that passed that workflow, and skips the heavy jobs when nothing they check has
  changed. It compares with the last *passing* commit, not the previous push, so a
  cancelled run is never skipped over.
- **Split the day-hours audit** into four jobs by year range, as Matins was. The longest
  audit job goes from about 60 minutes to about 15–20.
- **Parallel UI tests.** Split `BreviariumUITests` into five classes (launch and
  navigation, the Vespers matrix, the day hours, Matins, the votive offices) over a
  shared `BreviariumUITestCase`, and run them on three cloned simulators. App CI should
  go from about 42 minutes to about 20–25.
- **The target:** a full round under 30 minutes. The baseline times go in `PLAN.md`,
  before and after.
- Also: clean the local scratch builds and old fixture extracts at the start (Beta 4's
  disk filled up).

### B5-M1 — Understand the Dominican office (document, no code)
`docs/rubrics-op1962.md`: each hour as DO builds it for `OP1962`, with every
`Praedicatorum` branch listed, cited to the pinned commit, and what it changes. It also
covers:
- how the OP kalendarium overlays the 1960 one;
- how the `…OP` psalter sections are picked;
- which Roman texts the Dominican ones match.

### B5-M2 — Fixtures
The sets above, and `OracleFixture` reading a version.

### B5-M3 — The rite plug-in
`Rite`, with `Roman1960` behind it. This is a refactor only: every Roman audit (Vespers,
the day hours, Matins, the Little Office, the Office of the Dead, the Martyrology) stays
at zero, and no Dominican code is added yet.

### B5-M4 — The Dominican office in the engine
- The calendar first: the title block for every date, against the fixtures' first row,
  as Beta 3's head-line audit did.
- Then hour by hour: Vespers, Compline, Lauds, the little hours, Prime (with the Rule),
  Matins, each to zero in Latin, the English that exists, and the 2044 hold-out.
- Named edge cases: Dominican feasts (St Dominic; St Thomas Aquinas; St Catherine of
  Siena; Bl. Jordan of Saxony…), a Dominican saint displacing a Roman one, and the days
  where the OP calendar differs in rank. B5-M1 picks the dates from `OP1962.txt`.

### B5-M5 — The app
- *Ritus: Dominicanus* becomes selectable, and the hour picker and settings follow the
  rite (question 1 for its *Officium* choice).
- Snapshots: page 1 of every hour on a Dominican feast and on a ferial day, and a page
  with Latin only where no English exists.

### B5-M6 — Release
As Beta 4: release notes in the app and `docs/releases/beta-5.md`, the README and
roadmap, the install checklist, a retrospective, a PR and an IPA. It is merged and
published after you've tried it on the phone.

**Exit:** every Roman audit still at zero, the Dominican ones at zero, CI green, and a full
CI round under 30 minutes.

## How Claude works on this beta

As in Beta 4, with the Beta 4 retrospective's carry-forward:
- Once approved, the milestones run without waiting at each gate. The run stops only
  for an unresolved rubric, a suspected DO error, or a capability a free Apple ID can't
  sign.
- A plan's "must equal" claims are checked against DO before they're written.
- Any new hour shape is dumped as the app will lay it out (units, not just text) before
  its audit.
- Docs pushes are held while a pull request's checks run.

## Questions for you

1. **The Dominican Little Office and Office of the Dead.** DO has a Dominican Little
   Office (`CommuneOP/C12`); for the Dead it seems to fall back to the Roman one. Should *Dominicanus* get an *Officium* setting in Beta 5, like *Romanus*, or
   should Beta 5 have the Dominican office of the day only, with the votives later?
   *Suggested:* the office of the day only. The votives would come as a small follow-up
   once the rite is at zero.
2. **Fixture years.** 2026–2029 plus the 2044 hold-out, or the full 2025–2040 as for the
   Roman office? *Suggested:* four years plus 2044. The full range quadruples the
   fixtures and the audit time for little extra coverage, since the Roman engine
   underneath is already checked over 16 years.
3. **The psalter.** Should *Psalterium: Pii XII* apply to the Dominican office? DO allows
   it for any version, but I haven't checked what the Dominican books of 1962 used.
   *Suggested:* the Vulgate only for Dominicanus at first, with the psalter setting
   disabled under that rite, unless you know the Pius XII psalter was used.
4. **The Martyrology under Dominicanus.** B5-M1 will find what DO reads at Dominican
   Prime. If it has Dominican entries, they're shown. If it reads the Roman
   Martyrology, should the app show that, or leave the Martyrology out under
   Dominicanus?
5. **English that only partly matches.** Where a Dominican text differs from the Roman
   one by a few words (a saint's name in a collect), should it get the Roman English with
   the name changed, or be Latin only? *Suggested:* Latin only. The roadmap's decision 4
   allows the Roman English only where the texts match exactly.
