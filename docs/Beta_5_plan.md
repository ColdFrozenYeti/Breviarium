# Breviarium — Beta 5 Implementation Plan (draft)

**Status: approved on 27 September 2026**, with the answers in *Decisions* at the end.
B5-M0 (CI) is under way.

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

As decided (2 and 3 below):
- `version=Ordo Praedicatorum - 1962`, every hour, **every day 2025–2040**, Latin and
  English, priest off, as for the Roman office.
- A **2044 hold-out**, priest off and on.
- The **Pius XII psalter** too, if DO renders it under `OP1962`.
- The **Little Office** (`CommuneOP/C12`) and, if DO has one for the rite, the **Office
  of the Dead**, as Beta 4's sets: two years and one year, and the hold-out.
- The Dominican audits run in Oracle audits jobs split by years from the start, so each
  stays under 20 minutes.
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

## Decisions (answered 2026-09-27, plan approved)

1. **The Dominican Little Office and Office of the Dead come in Beta 5.** *Dominicanus*
   gets an *Officium* setting like *Romanus*. The Office of the Dead is included if DO
   has it for the rite: B5-M1 checks whether DO renders `votive=C9` under `OP1962`.
2. **The fixtures cover every day from 2025 to 2040**, as for the Roman office ("the
   length is necessary for all the bugs to be ironed out"), plus the 2044 hold-out.
3. **The Pius XII psalter** is offered under *Dominicanus* if DO has it for the rite.
   If it doesn't, the *Psalterium* setting is fixed to the Vulgate under *Dominicanus*,
   in Settings itself.
4. **The Martyrology:** the Dominican Martyrology where it differs from the Roman one,
   otherwise the Roman one. DO has no Dominican Martyrology. Its Dominican Prime reads
   its older, pre-1960 Roman text (`specprima.pl:145-149` picks `Martyrologium1960` only
   when the version name contains "1960"). That text differs from the 1960 one on 71
   days, mostly octaves the 1960 reform abolished. The user chose "whatever the
   Dominican rite follows". The 1962 Dominican office follows the 1960 rubrics, so the
   app shows the **1960 Roman Martyrology** under *Dominicanus*, and the audit records
   those 71 days as a known DO divergence. This is a judgement call, to revisit if a
   source for the Order's own Martyrology (with its Dominican additions) is found.
5. **English:** DO's Dominican English where it exists. Where a Dominican text matches
   a Roman one exactly, the Roman English. Where it differs a little (a saint's name in a
   collect), the Roman English with a disclaimer. Where there is no Roman counterpart,
   Latin only.
6. **The disclaimer** (answered 2026-09-27): a small line in the chrome grey
   (`#B2B2B2`) under that English text: *Roman text; the Dominican Latin differs.* It is
   the one exception to "no explanatory text in the office".
