# Breviarium — Alpha Implementation Plan

## Context

Breviarium is a personal, offline iPhone app that computes and displays the traditional
(1960 rubrics, Pius XII psalter) Divine Office, styled after the Universalis app's night
mode. The alpha scope is Roman Vespers only. The defining constraint is that development
happens entirely without a Mac: `BreviariumKit` (the engine) must build and test on this
Windows machine with the open-source Swift toolchain, while the app itself is built on
GitHub Actions macOS runners as an **unsigned** device build and reaches the user's
iPhone by **sideloading with a free Apple ID, from Windows** — there is no paid Apple
Developer Program membership and no TestFlight (see the 2026-09-16 amendment below).
Every milestone below is sequenced so that the no-Mac pipeline is proven first, before
any liturgical logic is built on top of it.

This plan was produced after reading `CLAUDE.md` in full and inspecting the three images
actually present in the repository (`Design/Reference/Format.png`,
`Design/Reference/Calendar.png`, `Design/Reference/Hours Picker.png` — see the note on
naming below).

### Amendment — 2026-09-16: sideloading instead of TestFlight

The original plan (and M0 as actually built) used a paid Apple Developer Program
membership: App Store Connect, an API key, `fastlane match` for certificates, and
TestFlight for delivery. The user has decided against joining the paid program. The app
now reaches the iPhone by **sideloading with a free Apple ID**, entirely from Windows.
Concretely, this changes:

- **CI no longer signs anything.** `app-ci.yml`'s simulator build and UI test lane is
  unchanged. What was `testflight.yml` is now an IPA-build workflow that produces an
  **unsigned** device build (`CODE_SIGNING_ALLOWED=NO`), packages it as a plain `.ipa`,
  and uploads it as a GitHub Actions workflow artifact — nothing more. `bootstrap-signing.yml`
  is removed entirely, along with `App/fastlane/*`, since there are no certificates or
  provisioning profiles for CI to manage.
- **Signing happens on Windows**, in a sideloading tool, using the free Apple ID —
  `docs/install-on-iphone.md` covers which tool, setup, first install, and the mandatory
  7-day re-sign routine free-tier signatures carry. `docs/apple-developer-setup.md` (the
  paid-account browser checklist) is removed.
- **The bundle identifier (`com.epavone.breviarium`) is now a hard constant** — every
  re-sign must reuse the same App ID, both because that's how re-signing an existing
  install works at all and because the free tier caps new App ID registration at roughly
  ten per rolling week.
- **The app may never need a capability a free Apple ID can't sign** — no iCloud, push,
  App Groups, widgets/extensions, or associated domains — which was already outside the
  alpha's scope but is now a hard constraint on all future milestones too, not just a
  scoping choice. See `CLAUDE.md`'s Non-negotiables.
- **The pipeline is deliberately structured so that adding TestFlight later** — if the
  Apple Developer Program is ever joined — **is additive**: a new signing step slotting in
  where the unsigned build currently gets zipped into an `.ipa`, not a restructuring of
  `app-ci.yml` or the IPA-build workflow.

Sections below are updated in place to describe the current (sideloading) approach as
the plan going forward; this amendment records why it changed.

### Note on the design references

`CLAUDE.md` refers to a screenshot called `design/reference/universalis-compline-night.png`.
That exact file isn't in the repo; instead there are three images, lowercase-mismatched
from the path `CLAUDE.md` uses (`Design/Reference/` vs. `design/reference/`):

- **`Format.png`** — Universalis's *Ad Completorium* (Compline) page 1, night mode, for a
  ferial day (Wed 16 Sep 2026, "Feria IV hebdomadæ XXIV per annum", no commemoration).
  This is the page that `CLAUDE.md`'s "Page structure, top to bottom" section (items 1–10)
  describes measurement-by-measurement. It matches that text closely: nav title, red
  italic date line, day title, red TOC icon, hour title, section separator, bold caps
  section heading ("INTRODUCTIO"), asterisk-split psalm verses, italic indented response,
  footer. Two things in it are explicitly *not* wanted per `CLAUDE.md`: the music-note
  icon next to the hour title, and the round red play/audio button bottom-left — both are
  already called out as omitted in our spec, so there's no conflict, just confirmation.
- **`Calendar.png`** — Universalis's date/calendar picker (month list with colour dots,
  "Go to Date…" / "Go to Today", a Jan–Dec jump list on the right). This is the reference
  for requirement 2 (date navigation / calendar picker).
- **`Hours Picker.png`** — Universalis's list of offices for the day (Mass items, all
  eight hours, Lectio Divina, Angelus, Rosarium — most of which are out of scope for us).
  This is the reference for the table-of-contents button's destination, and for the "hours
  are visible but disabled" requirement.

None of the three is literally a distinct "today home screen" showing date + title + a
row of hour buttons. Having looked at all three, my reading is that Universalis doesn't
have one either: the app opens directly into an hour's page 1 (which already carries the
date line, day title block, and TOC button per `Format.png`), and reaching another hour
goes through the TOC/hours list (`Hours Picker.png`).

**Confirmed:** the app opens on the **last hour consulted**, with the date always
refreshed to today (i.e. re-launching on a new day shows today's edition of whichever hour
was last open, not a stale date). This means `BreviariumKit`/app state persists a single
local preference — last-viewed `HourKind` — with no other synced or tracked state. Since
the alpha only enables `.vesperae`, in practice the app always opens on Vespers for now,
but the persisted-hour mechanism is built generically so it needs no rework when Compline,
Lauds, etc. are added later. Reaching another (disabled) hour still goes through the
TOC/hours list.

There's no Universalis reference for the **Settings** screen, and it's confirmed that
pixel fidelity there doesn't matter. I'll build it as a plain grouped `List`/`Form` in the
same night-mode palette (black background, white text, red accent for the section-list
icon colour) using `CLAUDE.md`'s text description directly.

I'm also proposing to rename `Design/Reference/` → `design/reference/` in M0, purely so
the path is stable across Windows/macOS (case-preserving, case-insensitive) and the Linux
CI runners (case-sensitive) without relying on git's own case-insensitivity quirks.

---

## Architecture

### Repository layout

```
Breviarium/
  CLAUDE.md, README.md
  docs/
    PLAN.md                       (this plan, saved on approval)
    do-format.md                  (M1)
    rubrics-1960-vespers.md       (M1)
  design/reference/                (renamed from Design/Reference)
  data/
    divinum-officium/              (git submodule, pinned commit)
    SOURCE.md                      (pinned commit hash + license note)
    oracle-fixtures/               (compressed golden output, M4)
  Packages/BreviariumKit/          (Swift package — the only thing that must build on Linux/Windows)
    Package.swift
    Sources/BreviariumKit/         (calendar, rite protocol, office model, orthography, text loader)
    Sources/BreviariumData/        (build-time CLI: DO parser → bundled data file)
    Tests/BreviariumKitTests/      (unit tests: computus, precedence, orthography, date line, named edge cases)
    Tests/BreviariumDataTests/     (DO syntax parser tests)
    Tests/OracleTests/             (diffs engine output against data/oracle-fixtures)
  App/
    project.yml                    (XcodeGen spec; .xcodeproj is generated on CI, not committed)
    Breviarium/                    (SwiftUI sources, depends on BreviariumKit via local SPM path)
    BreviariumUITests/             (XCUITest snapshot tests)
  scripts/
    test-kit.sh / test-kit.ps1     (local: swift build && swift test, Linux/Windows)
    get-ipa.ps1                    (downloads the latest unsigned .ipa artifact via gh CLI)
    docker/                        (docker-compose for DO, pinned to the submodule commit)
    generate-oracle-fixtures.*     (drives the Docker DO instance, writes data/oracle-fixtures)
  .github/workflows/
    kit-ci.yml                     (ubuntu-latest: swift build/test for Kit, Data, Oracle)
    app-ci.yml                     (macos-26: xcodegen generate, build, UI snapshot tests, upload PNG artifacts)
    build-ipa.yml                  (macos-26, manual workflow_dispatch: unsigned device build, packaged as .ipa, uploaded as an artifact)
```

### `BreviariumKit` (pure Swift, Foundation only, Linux+Windows buildable)

- **Rite abstraction.** A `LiturgicalRite` protocol owns three responsibilities behind one
  interface: (1) `liturgicalDay(for:options:) -> LiturgicalDay` — rank, occurring feast(s),
  commemorations, title-block strings, for any date; (2) `supportedHours: Set<HourKind>`
  so the UI can grey out what a rite doesn't implement yet; (3)
  `assembleHour(_:on:options:) -> Hour?` — the fully resolved, structured, formatting-free
  content. `HourKind` enumerates all eight canonical hours now, even though only
  `.vesperae` is implemented. `Roman1960Rite` is the concrete alpha implementation.
  `AmbrosianRite` is **not** built in the alpha, but the protocol is exercised by a second,
  trivial conformer in tests (e.g. a fixed-text stub) to prove the seam holds before real
  Ambrosian sources exist — this satisfies "design for them; do not build them" cheaply.
- **Office model.** `Hour` → ordered `[Section]` (e.g. Introductio, Psalmodia, Capitulum…)
  → ordered `[Unit]` (a versicle/response pair, a psalm verse, a stanza, a rubric, a
  heading). Every leaf of verse-structured content is Latin/English as a pair (English
  optional), tagged with enough structure (verse number, half-verse, stanza number) to
  drive the parallel-column alignment rules in `CLAUDE.md`. No colours, fonts, or spacing
  live in this model — that's entirely SwiftUI's job in `App/`, per the "no liturgical
  logic in the app target" rule.
- **Orthography.** A single `latinize(_:)`-style pass (J→I, applied only to fields tagged
  `.latin`) used by `BreviariumData` at build time, unit-tested directly against DO source
  fragments.
- **Data loading.** Reads the bundled file `BreviariumData` produced (below) and exposes
  typed lookups to the rite implementation.

### `BreviariumData` (build-time CLI, same package)

**Amendment — 2026-09-16, after M1's close reading of `SetupString.pl`:** the original
description below (`BreviariumData` "resolves every static conditional... follows
`@Commune/...` cross-references") doesn't hold up. DO's own `setupstring()` interleaves
section-conditional evaluation and `@`-reference resolution in a single pass, evaluated
against the *complete* current context (rubrics version, but also the specific day,
season, hora, commune-in-use, etc.) — there's no clean seam where "build-time-only"
conditionals can be evaluated in isolation, because even a file's basic set of available
`[Section]`s depends on `vero($condition)` calls that need day-dependent subjects
(`tempore`, `die`, `feria`, `commune`, `votiva`, `officio`) that literally don't have
values yet at build time. Trying to do partial resolution at build time and full
resolution at runtime would mean **two separate ports of the same algorithm**, which is
both harder to build correctly and a correctness risk in itself (two implementations
silently drifting apart). Corrected division of labour:

- **`BreviariumData` does not evaluate conditionals or resolve `@`/`$`/`&` at all.** Its
  job is bundling and the parts that genuinely are static: it walks the pinned DO
  checkout's Vespers-relevant corpus (`Tempora`, `Sancti`, `Commune`, `Psalterium`,
  `Latin-Bea/Psalterium`, per `do-format.md`'s psalter-mapping finding), splits each file
  into its raw `[SectionName] (raw-condition-string)` blocks — the *first* phase of DO's
  own `setupstring_parse_file`, but stopping short of calling `vero()` on the extracted
  condition strings, so every conditioned variant of a section is preserved rather than
  just the one that happened to match some assumed context — applies J→I to Latin text,
  and flattens the `Kalendaria` version-inheritance chain (`do-format.md`) into a single
  1960 calendar table. Genuinely context-free data.
- **`BreviariumKit` ships the full resolution engine** — `vero()`, the
  `process_conditional_lines()` stack machine, `@` inclusion, `$` prayer-macro expansion,
  and `&` script-macro identification — operating against the bundled raw sections at
  *render* time, once a specific day's full context is known. This is one port of DO's
  algorithm, used everywhere, not two. It's exercised for real starting in M4 (Vespers
  assembly), but written and unit-tested against `do-format.md`'s concrete examples in M2
  since it's genuinely part of "the data pipeline" in spirit even if it doesn't run at
  build time.

Parses the pinned Divinum Officium checkout, applies J→I to Latin fields, flattens the
Kalendaria inheritance chain, and emits one bundled data file containing:

1. The sanctoral calendar table (from `Tabulae/Kalendaria/1960.txt`, flattened against
   its `base` chain): date → feast(s) → rank → commune reference. This is genuine *data*.
2. The raw, section-split (but conditional-unevaluated) text corpus (temporal and
   sanctoral propers, commune texts, the Bea psalter, fixed ordinary text) in Latin and
   English, keyed by DO's own section identifiers.
3. **Every conditional, `@`/`$`/`&` reference, and day-dependent decision** is left in the
   bundled text verbatim, for `BreviariumKit`'s resolution engine to evaluate at render
   time — never resolved as code inside the data tool. This preserves "the app computes
   the office itself" even more literally than originally planned.

**Format:** gzip-compressed JSON as the shipped bundle, decoded once at app launch with
`JSONDecoder` and cached in memory for the session. JSON is chosen because
`BreviariumData` must run correctly under the *open-source* Swift toolchain on Windows —
`JSONEncoder`/`JSONDecoder` are the one encoding pair with fully reliable parity there,
unlike `PropertyListEncoder`, whose Linux/Windows behaviour is less consistent. The
Vespers-relevant corpus (one hour, one rite) is small — low single-digit MB uncompressed
even across a full year of propers — so a whole-file decode at launch should be fast
enough; M2 measures this and only reaches for a byte-offset index or a custom binary
layout if the measured numbers say so. Report both the compressed and decompressed size
at the end of M2.

### Data pipeline lineage

Divinum Officium (submodule, pinned commit, hash recorded in `data/SOURCE.md`) →
`BreviariumData` (parses, resolves, normalises) → bundled `.json.gz` shipped inside the
app bundle → `BreviariumKit` at runtime (loads once, resolves the remaining day-dependent
conditionals, assembles the `Hour`) → SwiftUI (renders to the visual spec, zero liturgical
decisions).

---

## Milestones

### M0 — Repository, local tooling, and CI

Goal: prove the entire no-Mac pipeline end-to-end with placeholder content, before any
liturgical code exists.

1. **Repo skeleton.** Create the layout above; rename `Design/Reference` →
   `design/reference`; add `.gitignore` for build artefacts.
2. **`BreviariumKit` skeleton.** `Package.swift` with the `BreviariumKit` library and
   `BreviariumData` executable targets, one placeholder type each, and one passing Swift
   Testing test. Confirm `swift build && swift test` succeeds on this machine with the
   installed open-source toolchain.
3. **Divinum Officium submodule + Docker.** Add the submodule pinned to a specific commit,
   write `data/SOURCE.md`. Write a `docker-compose.yml` that runs DO's own web stack
   (Plack/Starman, per its own setup) locally against that pinned commit, verified by
   fetching one known Vespers page over `curl` from the container.
4. **Local test script.** `scripts/test-kit.sh` / `.ps1` wrapping `swift build && swift
   test` with clear pass/fail output.
5. **`kit-ci.yml`** (ubuntu-latest): runs the same script on every push/PR. This is the
   cheap, fast, primary CI signal.
6. **Xcode project generation.** Add `App/project.yml` (XcodeGen) describing a single
   `Breviarium` app target (SwiftUI, iOS 26.5 deployment target) plus a
   `BreviariumUITests` target, with a local SPM package dependency on `BreviariumKit`.
   Recommend **XcodeGen** over Tuist: it's a single static binary installable via
   Homebrew on the runner, does one job (YAML → `.xcodeproj`), and needs no project
   graph/caching layer we don't otherwise need for a one-target app. The generated
   `.xcodeproj` is **not committed** — `app-ci.yml` runs `xcodegen generate` before every
   build, which sidesteps hand-editing a `.pbxproj` blind.
7. **`app-ci.yml`** (macos-26 runner — confirmed available and current, with Xcode
   26.0.1–26.6 preinstalled, more than covering the iOS 26.5 SDK; see sources below):
   generate the project and `xcodebuild build`/`test` a placeholder app (one screen,
   black background, "Breviarium" text) on the simulator only — no signing, no device
   build. The device build lives in `build-ipa.yml` (below), kept separate so ordinary
   pushes stay on the cheap simulator-only lane.
8. **`build-ipa.yml`** (macos-26, manual `workflow_dispatch` trigger so a fresh `.ipa` is
   a click away): generates the Xcode project, builds the placeholder app for a real
   device with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO` against the
   `generic/platform=iOS` destination (an unsigned arm64 build needs no signing identity
   at all), packages the resulting `.app` as a proper `.ipa`
   (`Payload/Breviarium.app`, zipped), and uploads it as a workflow artifact.
9. **`scripts/get-ipa.ps1`**: downloads the latest successful `.ipa` artifact from
   `build-ipa.yml` via the `gh` CLI into a fixed local folder and prints the path — the
   bridge between "CI made a build" and "sideload it from Windows."
10. **`docs/install-on-iphone.md`** (browser/desktop checklist for you): which sideloading
    tool to use on Windows with a free Apple ID (see below), one-time setup, first
    install, the mandatory 7-day re-sign routine, what expiry looks like, and the free
    tier's app-count and App-ID-per-week limits.
11. **Exit criterion:** the placeholder app is installed on your iPhone by sideloading the
    `build-ipa.yml` artifact, proving repo → Linux Kit CI → macOS app CI → unsigned
    `.ipa` → Windows sideloading tool → iPhone, before any liturgical logic depends on the
    pipeline working.

**M0 done (2026-09-16).** Kit CI, App CI, and Build IPA all verified green on GitHub
Actions; `get-ipa.ps1` fetches a real `.ipa` with the correct `Payload/Breviarium.app`
structure; sideloaded via AltStore/AltServer onto the actual iPhone, confirmed showing
"Breviarium" / "Kit data format v1" as built. Two real bugs surfaced and were fixed along
the way rather than staying theoretical: `setup-swift@v2` didn't know about Swift 6.3.x
(needed `@v3`), and `install-on-iphone.md`'s first draft described an AltServer tray-icon
interaction that doesn't exist (corrected to the AltStore-app `My Apps` → `+` → iCloud
Drive path after hitting that wall for real and re-researching it).

### M1 — Understand Divinum Officium

No code. Two review documents, read closely from the submodule pin (`web/www/horas/Latin*`,
`web/cgi-bin/horas/officium.pl`, `horas.pl`, `web/www/Tabulae/`, `docs/`, `regress/`):

- **`docs/do-format.md`** — every syntax feature the Vespers path touches: `[Section]`
  headers, `(sed rubrica 1960)`-style conditionals, `@Commune/C3:Section`
  cross-references, `$`/`&` macros, `v.`/`V.`/`R.`/`!` markers, and how the "Rubrics 1960
  - 1960" + "Pius XII Psalter" + "Priest" version string maps to our options.
- **`docs/rubrics-1960-vespers.md`** — how the office of the day is decided; occurrence vs.
  concurrence; first vs. second Vespers; which commemorations apply and when they're
  suppressed; and a **concrete proposal** for the section-heading set and the page
  grouping for Vespers (building on the Compline example already visible in `Format.png` —
  INTRODUCTIO / HYMNUS / PSALMODIA / CAPITULUM / CANTICUM / ORATIO / CONCLUSIO-shaped, but
  worked out precisely for Vespers's five psalms, capitulum, hymn, versicle, Magnificat,
  commemorations, and conclusio).
- I should also note here whether `regress/` already contains a reusable date→office
  mapping that would let M3's calendar engine be checked more cheaply than scraping full
  rendered Vespers pages — worth establishing during M1, since it changes M3's cost.

**Both documents are reviewed and approved by you before any engine code is written.**

**M1 drafted (2026-09-16), awaiting your review.** `docs/do-format.md` and
`docs/rubrics-1960-vespers.md` are written, cited to specific files/line numbers in the
pinned submodule commit rather than paraphrased from memory. Confirmed `regress/` doesn't
give M3 a cheaper calendar oracle (§6 of the rubrics doc) — it only lists date ranges
worth exercising, not a precomputed date→office mapping. Both docs end with an explicit
"open items" list of what's confirmed by reading the source vs. still a working theory
(notably: the Pius XII Psalter option's exact mapping, and the RG section numbers DO's
own comments cite) — flagged rather than presented as more settled than it is. M2 doesn't
start until you've reviewed both.
### M2 — Data pipeline

Build `BreviariumData` per the corrected "Data pipeline" section above: raw section
splitting (no conditional evaluation), J→I orthography, Kalendaria chain flattening,
bundle emission. Build `BreviariumKit`'s resolution engine (`vero()`, the conditional
stack machine, `@`/`$` resolution, `&` macro identification) alongside it, unit-tested
against `do-format.md`'s concrete examples even though it isn't exercised end-to-end
until M4. Report bundle size (compressed and decompressed) and cold-load time on a
representative device class.

**Done (2026-09-16).** Built and verified green on Kit CI (44 passing tests, including
hand-traced real fragments from `Tempora/Adv1-0.txt` checked against both a 1960 and a
Tridentine context before being written as tests, and a real bug Kit CI caught in
`KalendariaResolver` against the actual `Kalendaria/1960.txt` — a stray comment line that
happened to contain `=`):

- `LatinOrthography` (J→I, skipping `@`/`$`/`&` reference lines)
- `ConditionalContext`/`ConditionalGrammar`/`ConditionalEvaluator` (`vero()` and
  `parse_conditional`, including a faithful port of a real Perl-grammar quirk: `negation`
  persists past a later `et` once `nisi` has appeared, since Perl only resets it per `aut`
  branch)
- `ConditionalLineProcessor` (the `process_conditional_lines` stack machine)
- `RawSectionParser` (section-splitting, preserving every conditioned variant unevaluated)
- `SectionResolver`/`OfficeCorpus`/`LayeredOfficeCorpus` (the render-time entry point:
  picks the winning header variant, runs the line processor, follows `@` inclusions —
  including `do_inclusion_substitutions`'s line-range and `s///` selectors — and `$`
  prayer macros recursively; `&` script macros are deliberately left unresolved, for M4)
- `OfficeCorpusWalker`/`CalendarChainReader`/`BreviariumDataPipeline` (the actual CLI
  pipeline: walks `Tempora`/`Sancti`/`Commune`/`Psalterium` for Latin and `Psalterium`
  for Latin-Bea, flattens the `Kalendaria` chain, emits a `DataBundle`)

**Run for real against the pinned DO checkout** (`kit-ci.yml`, which now checks out the
submodule and runs `BreviariumData` after the unit tests, uploading the bundle as an
artifact):

| | |
|---|---|
| Latin files | 1,759 |
| Latin-Bea files | 170 |
| Calendar entries | 304 |
| Uncompressed JSON size | 6,026,844 bytes (6.03 MB) |
| `JSONDecoder` round-trip | 0.094s (CI runner CPU, not an iOS device — a rough proxy, not a real cold-load number) |

No compression was applied — plain JSON, per the "measure first" reasoning already in
this section. 6 MB uncompressed is comfortably within what "a whole-file decode at
launch should be fast enough" anticipated; revisit only if a real on-device measurement
(M5+) says otherwise.

**Explicitly deferred, not silently dropped:** the English corpus (only Latin +
Latin-Bea were walked this pass) and the language-fallback wiring for it; `&` macro
*expansion* (the identification/pass-through is done, but computing what `&Gloria` etc.
actually render as is M4's office-assembly job); a first local `swift build`/`swift test`
run — the Windows SDK blocker is resolved (confirmed: `C:\Program Files (x86)\Windows
Kits\10` now exists) and the user has a working local build of their own (real `.exe`
artifacts on disk), but this session's own tool environment still couldn't reproduce it,
so every check above ran on Kit CI (Linux) only.

### M3 — Calendar engine

Computus, temporal cycle, sanctoral lookup, precedence, rank, and title-block generation
for any date. Checked against the DO oracle (see Testing strategy) for 2025–2040, plus
every named edge case in `CLAUDE.md`'s testing section.

**Liturgical colour.** Confirmed: the date picker should carry a colour dot per day, like
`Calendar.png`, but using the **1960/pre-conciliar colour rules**, not the Novus Ordo
scheme shown in that screenshot (white, red, green, violet, rose on Gaudete/Laetare,
black for Requiem Masses/Good Friday-type days — determined by rank, season, and
commemoration type). M1's rubrics document should establish whether Divinum Officium
exposes this colour directly for "Rubrics 1960" pages or whether it must be derived from
rank/season/feast-type by our own rule table; M3 implements whichever it turns out to be,
with its own unit tests, and the colour becomes part of `LiturgicalDay` so the date picker
is just reading engine output, not deciding colours itself.

**Largely done (2026-09-16), verified on Kit CI (104 passing tests).** Built directly
from `Date.pm` and `Main.pm`, both read closely rather than reconstructed from scratch:

- `Computus` — Easter, leap years, day-of-year/day-of-week, first Sunday of Advent, the
  `get_sday` leap-day trick, an `addDays` helper. Tested against well-known anchor dates
  (1900/2000/2024/2025/2038) plus structural properties (Easter always a Sunday, always
  22 Mar–25 Apr) checked across 2000–2100.
- `TemporalCycle` — `weekName()`, the `getweek()` port giving every date its
  `"Adv1"`/`"Quad3"`/`"Pasc0"`/`"Pent16"`-style season+week label. Verified against facts
  cross-checked in M1's own reading of `horascommon.pl` (Ash Wednesday = Quadp3
  Wednesday, Pentecost's vigil = Pasc6 Saturday), not just re-derived from the same port
  being tested.
- `LiturgicalColor`/`LiturgicalColorClassifier` — a genuine find: `Main.pm` already has a
  `liturgical_color()` function (M1 had flagged this as unconfirmed). Its internal token
  names are confusingly inverted (`'black'` means white vestments; `'grey'` means real
  black) — remapped to real colour names here. Every case from DO's own
  `t/DivinumOfficium/{LiturgicalColor,Main}.t` — 45+ real titles and regex-mechanics
  probes — ported as Swift tests, DO's own pre-validated oracle for this function rather
  than an independently reconstructed rule table.
- `OfficeRank`/`RankDisplayName1960` — parses `[Rank]`; the 8-entry 1960 display-name
  table from `docs/rubrics-1960-vespers.md` §1.
- `SanctoralCalendar` — date-keyed lookup over the flattened Kalendaria table.
- `Occurrence` — the **1960-specific core** of `occurrence()`'s rank-comparison decision
  (`docs/rubrics-1960-vespers.md` §1): temporal vs. sanctoral, the Sunday-exception branch
  for I./II. classis feasts of the Lord, the RG 15 Immaculate Conception exception.
- `LiturgicalDay`/`TitleBlock`/`LiturgicalCalendarEngine` — ties it together: which office
  wins, its rank/colour/title-block text.

Two real test-authoring bugs (not production bugs) surfaced and got fixed by actually
running this on Kit CI rather than trusting hand-derived expectations: a calendar-key
mismatch in one `Occurrence` fixture, and a `[Rank]` field with the title text in the
wrong slot. A third near-miss was caught and fixed *before* committing: hand-verifying
16 September 2026's actual temporal path (`"Pent16-3"`) against the real computus, rather
than trusting a first guess (`"Pent15-3"`, which was wrong).

**Explicitly not yet covered, flagged rather than assumed handled:**

- Permanent/annual temporal transfers (a fixed feast displaced by Holy Week — the
  Annunciation/St Joseph transfer cases `CLAUDE.md` names), Ember days.
- Concurrence — which office's Vespers is actually prayed when today's second Vespers
  meets tomorrow's first (`docs/rubrics-1960-vespers.md` §3). `Occurrence` only decides
  the *day's* office, not this Vespers-specific question yet.
- Commemorations — `TitleBlock.commemorationLine` exists but is always `nil`; the
  commemoration list itself isn't built.
- Full validation against the DO oracle for 2025–2040 and `CLAUDE.md`'s named edge cases
  — genuinely can't happen until M4 generates the oracle fixtures (no Docker/DO instance
  available in this session to generate fresh data against).
- `monthday()` (`Date.pm`) — a secondary Aug–Dec ferial-numbering scheme used for some
  proper texts, not the primary day-name/occurrence logic — not ported this pass.

These are the natural shape of M4 (Vespers assembly, which needs concurrence and
commemorations regardless) and the oracle-generation step already planned there, not
scope quietly dropped.

### M4 — Vespers assembly

The full hour as the structured, formatting-free `Hour`/`Section`/`Unit` model, including
every commemoration the 1960 rubrics require, *Dominus vobiscum* vs. *Domine, exaudi*
per the priest toggle, and Latin/English pairing. Diffed against the DO oracle — see the
reduced fixture scope below. Done only when the diff is empty or every remaining
difference is written up for you with the Codex Rubricarum 1960 citation and DO's output
side by side, per `CLAUDE.md`'s rule against silently editing fixtures.

**In progress (2026-09-16).** `Concurrence` is done and verified: the first-vs-second-
Vespers decision `docs/rubrics-1960-vespers.md` §3 documents, including two further
version-independent exclusions (an explicit `"No prima vespera"` `[Rule]` flag, and the
Feria/Sabbato/Vigilia/Quatuor title exclusion with its override exceptions) found in the
same `horascommon.pl` condition during M1.

`Commemorations` is also done and verified (121 passing tests total): the four
commemoration-filtering cases `docs/rubrics-1960-vespers.md` §2 documents from a full
re-read of `concurrence()`'s closing blocks, filtered to the 1960-only branches. Building
it surfaced and fixed a real, previously-undocumented-in-code gap: `[Rank]`'s title field
needs auto-filling from `[Officium]`'s resolved text at load time (`SectionResolver.
resolveRank`) — without it, every title-based rubric check (`Occurrence`'s RG15
exception, `Concurrence`'s Feria/Sabbato/Vigilia exclusion) was reading an
almost-always-empty field against real DO data.

**Docker blocker resolved (2026-09-16).** You installed WSL2 and Docker Desktop
yourself (the two genuinely-needs-a-human-at-the-keyboard steps this session flagged and
documented in `docs/windows-swift-setup.md`). The oracle-fixture sweep now runs:
`scripts/oracle-date-list.pl` builds the job manifest (main sweep + a spot check weighted
toward `CLAUDE.md`'s named edge cases), `scripts/docker/oracle-worker.sh` renders each
one inside the pinned DO container, and `scripts/generate-oracle-fixtures.sh` packs the
result into `data/oracle-fixtures/`. First full run: 6,228 renders, zero empty/failed
outputs, ~11.5 MB compressed — see `data/SOURCE.md` for the exact parameter mapping this
surfaced (including a real DO quirk: requesting `lang2=Latin` doesn't collapse to a
single column when `lang1=Latin-Bea`, silently rendering the Latin content twice, until
both are requested as `Latin-Bea` explicitly).

**Local Swift build fully working (2026-09-16).** `.\scripts\test-kit.ps1` now builds
and tests cleanly on Windows, not just CI — see `docs/windows-swift-setup.md`'s Status
section for the three real fixes it took to get there (an elevated Windows SDK install,
a missing `vswhere.exe` PATH entry, and — the actual last blocker — `SDKROOT` needing to
be set explicitly rather than trusted to auto-detect). This closes the local dev loop:
changes can be verified in seconds without waiting on a CI round-trip.

**The `&` script macro evaluator is done and tested** (`ScriptMacros.swift`): a
non-GABC port of the five macros Vespers reaches (`Deus_in_adjutorium`, `Alleluia` vs.
Lenten/Septuagesima `Laus tibi`, `Dominus_vobiscum`'s priest toggle, `Benedicamus_Domino`'s
Paschal-octave "alleluia, alleluia", `Gloria`'s Triduum silence and Requiem form), wired
into `SectionResolver` so `&Name` lines resolve like `@`/`$` already did.

Building and testing it locally surfaced **a real cross-platform bug**: Swift's
`Character` (grapheme cluster) view treats `"\r\n"` as a single `Character`, so every
`text.split(separator: "\n")` in `RawSectionParser`, `LatinOrthography.normalize`, and
`KalendariaResolver` silently found zero line boundaries against a Windows (CRLF)
checkout — collapsing whole files into one "line" and producing garbage or empty
output. Invisible on Linux CI (LF checkouts), but a real local-Windows-testing hazard;
fixed at all three sites with a regression test each. Also fixed: `Ordinarium/` sits
directly under `web/www/horas`, not inside `Latin/` — the data pipeline was walking the
wrong path for it entirely, silently finding nothing.

Running the resolved `Ordinarium/Vespera.txt` (not hand-traced — actually run, now that
local build works) against a real 1960 Vespers context confirmed `docs/rubrics-1960-
vespers.md` §5's proposed section table exactly, and settled where each section's
content actually comes from — added as a new "Content assembly" subsection there.
Headline finding: `#Psalmi` needs real assembly (weekday psalm-number schema -> each
psalm's own verse-text file -> office/Commune antiphon -> `&Gloria` doxology), not a
single section lookup, while `#Incipit`/`#Conclusio` were already fully solved by the
macro evaluator above.

**`HourAssembler` is built and produces a real, correct-looking Vespers (2026-09-17.)**
`Hour`/`Section`/`Unit` (`Hour.swift`) is the formatting-free model `CLAUDE.md` calls
for; `HourAssembler.swift` walks the resolved skeleton, assembles `#Psalmi` and
`#Canticum: Magnificat` properly (proper `[Ant Vespera]`/`[Ant Vespera 3]` antiphon +
psalm number, falling back to the weekday schedule, each psalm's real verse text from
`Psalterium/Psalmorum/`, `&Gloria` doxology), and resolves `#Oratio`/`#Capitulum Hymnus
Versus` with a Commune fallback when the office itself doesn't define a section.
`#Preces Feriales` is now resolved too (`preces()`'s gating, see below) — see
`HourAssembler`'s own doc comment for the full, current scope-limit list.

Verified two ways: 8 synthetic unit tests, and a new permanent integration test
(`VespersIntegrationTests.swift`) that assembles a real Vespers against the actual
pinned DO checkout for 16 September 2026 (`CLAUDE.md`'s own worked example) and asserts
concrete expected content. That integration test is what actually mattered here: it
surfaced three real bugs no synthetic fixture had reason to expose, since a fixture's
author naturally writes the query and the corresponding data consistently —

1. `OfficeRank.init?(rankFieldValue:)` rejected a `[Rank]` field's numeric part when it
   carried a trailing newline (the real file's own trailing blank line surviving
   `ConditionalLineProcessor`'s join) — `Double(_:)` has no tolerance for that.
2. `ScriptMacros` queried `Prayers.txt`'s `[Deus in adjutorium]` header by its literal
   (pre-normalisation) `j`-spelling — but `LatinOrthography.normalize` runs over the
   *whole* raw file text before `RawSectionParser` ever splits it into sections, so a
   header naming a real Latin word (unlike a `@`/`$`/`&` reference identifier, which is
   exempted) is stored J-to-I-normalised like any other prose in the file.
3. A `$Name.` macro line's sentence-final period (real example: `Commune/C3.txt`'s
   `[Oratio]` ends with the literal line `$Per Dominum.`) wasn't handled — `Prayers.txt`'s
   own header is `[Per Dominum]`, no period, so the literal lookup silently found
   nothing.

None of these were exotic — all three are exactly the kind of thing that only surfaces
by running the real pipeline end to end, which is the whole reason this integration
test is being kept permanently rather than treated as a one-off diagnostic.

**The oracle diff exists and runs green (2026-09-17).** `Tests/OracleTests` builds the
real bundle once per run, assembles Vespers for a handful of real dates, and checks
every `Unit`'s text is actually findable in the matching `data/oracle-fixtures/` entry
(applying `LatinOrthography` to the fixture at compare time, per `data/SOURCE.md`) —
a containment check per text piece rather than a byte-exact diff, since matching DO's
own page chrome (heading text, "Top"/"Next" nav, page numbers) isn't a Kit concern and
isn't modelled. 4 tests pass, each scoped to the sections confirmed correct for that
specific date; three real, date-specific antiphon/collect-selection gaps surfaced along
the way and are excluded from comparison scope (not silently passed) rather than
guessed at further:

1. **A Commune's `[Ant Vespera]`/`[Ant Vespera 3]` can carry antiphons with no
   `;;psalmNumber` suffix at all** (real example: `Commune/C3.txt`, the Common of
   Several Martyrs) — meaning "alternate antiphons for the ferial psalms of the day,"
   not "these come with their own proper psalms." `assemblePsalmodia`/
   `assembleMagnificat` now fall through to the weekday schedule (or `[Ant 3]`, for the
   Magnificat) whenever the numbered form parses to zero pairs, matching this confirmed
   case — fixed, not just flagged.
2. **Two further antiphon-source rules remain unhandled**, both confirmed against real
   fixtures: a later weekday reusing an octave's shared temporal file (`Tempora/Nat1-0`
   covers every day of the Octave, not just its first) incorrectly keeps that file's own
   proper antiphons instead of falling back to the plain weekday's; Paschaltide replaces
   every psalm antiphon with a plain "Allelúia," which this pass doesn't produce.
3. **`#Oratio`'s collect can need a name substituted into a literal `"N."`/`"N. et N."`
   placeholder** — DO's `replaceNdot()` (`specials.pl`) pulls the name from the
   winning office's own `[Name]` section. Separately, a Commune can define numbered
   sub-variants (`[Oratio 3]` alongside plain `[Oratio]`, confirmed real example: two
   martyrs specifically get `[Oratio 3]`) selected by a rule not yet identified.

Also fixed while building this: `HourAssembler.unitsFromResolvedText` now produces one
`.prose` unit per source line (not one joined block) — DO's own rendering puts its `℣.`/
`℟.` glyph directly between a collect's body and its `$Per Dominum` ending with no
separating punctuation, so a single joined string was never actually contiguous in the
fixture, only the per-line pieces are.

**Name substitution is now implemented (2026-09-17).** `HourAssembler.substituteName`
ports `replaceNdot()`'s plain case (no `"Oratio="`/`"Ant="`/`"Invit="` grammatical-case
tagging — confirmed real, but only ever seen on a `[Name]`'s `"Postcommunio="` tag for a
Mass proper, never for anything the Office side reads). Confirmed clean against a real
date the numbered-sub-common gap above doesn't touch: `Sancti/02-05` (S. Agatha) falls
back to `Commune/C6`'s plain `[Oratio]`, `"...beátæ N. Vírginis..."` → `"...beátæ
Agathæ Vírginis..."`, matching the real fixture exactly (new test:
`agathaMatchesTheRealOracleIncludingTheNameSubstitutedCollect`; `.oratio` is in full
comparison scope there and passes cleanly). The 16 September / 19 January cases still
exclude `.oratio`, since they specifically hit the still-unresolved numbered-sub-common
question, not the substitution mechanism itself.

Also corrected while investigating the numbered-sub-common question: `[Ant Vespera 3]`
was never a real Magnificat-antiphon fallback source to begin with — it's more likely
tied to `Concurrence`'s "a capitulo" concurrence branch (`docs/rubrics-1960-vespers.md`
§2b), a different scenario entirely. It happened to never matter in practice because
`assembleMagnificat` already tries `[Ant 3]` first and that's always resolved the real
cases so far, but the doc comment no longer claims a confidence in `[Ant Vespera 3]`
that was never actually earned.

**A second, more general psalmody rule is also confirmed and implemented
(2026-09-17).** The 16 September fix (fall through to the ferial weekday schedule when
`[Ant Vespera]` has no `;;number`) turned out to be only half the story — the same
Agatha fixture that validated name substitution also exposed it: S. Agatha's own psalms
(via `Commune/C6`) are the classic Sunday set (109-112) with a proper fifth, *not* the
ferial Thursday psalms, even though `Commune/C6`'s `[Ant Vespera]` is *also*
unnumbered. The actual signal is the `[Rule]` field's `"Psalm5 Vespera3=NNN"` entry
(today's own second Vespers) or `"Psalm5 Vespera="` (presumably first Vespers, not
independently confirmed) — present on both `Sancti/02-05` and `Commune/C6`, absent on
`Commune/C3` (the genuinely-ferial 16 September case). Confirmed exactly against the
real fixture: psalms 109, 110, 111, 112, **147** (the `"Vespera3="` value, not the
`"Vespera="` one, which also exists on the same `[Rule]` but points to a different,
unused psalm). `assemblePsalmodia`/`festalFifthPsalmNumber` now check this before
falling through to the ferial schedule; new unit test
`festalUnnumberedAntiphonsPairWithTheSundayPsalmsAndARuleGivenFifth` locks in the
synthetic mechanics, and `agathaMatchesTheRealOracleIncludingTheNameSubstitutedCollect`
confirms it against real data (its only remaining excluded section is `.psalmodia`
itself, and only because Psalm 111's own verse-splitting hits the already-documented
Bea/Vulgate half-verse-numbering gap `Psalm.swift` flags — not because the psalm/
antiphon *selection* is wrong).

**`#Preces Feriales` is now implemented (2026-09-17).** The apparent self-reference
that stalled the previous session — `getpreces()` reading `Psalterium/Special/Major
Special.txt`'s `[Preces feriales Vespera]`, whose own body includes the line `$Preces
feriales Vespera` — turned out not to be recursion at all. `webdia.pl`'s `expand()`
strips a **sigil**, not just a name, off every macro line: plain `$Name` dispatches to
`prayer()` (`Psalterium/Common/Prayers.txt`), but `$rubrica Name` dispatches to
`rubric()` (`Psalterium/Common/Rubricae.txt`, looked up by the bare name) and `$Preces
Name` dispatches to `prex()` (`Psalterium/Special/Preces.txt`, looked up **with** the
"Preces " prefix retained). The wrapper's middle line is a `$Preces `-sigil reference
into a completely different file/hash than the wrapper section itself lives in — no
loop. Ported as `SectionResolver.sigilPaths`, a small table the resolver checks before
falling back to plain `$Name`/`Prayers.txt` handling; two new `SectionResolverTests`
cases lock in each sigil's dispatch and prefix-retention behaviour directly.

`shouldShowPrecesFeriales`/`isEmberDay` port `preces()`'s 1960/Vespers-reachable
condition (`specials/preces.pl:7-71`): omit if a *Sancti* office wins, the winning
office's own `[Rule]` says "Omit ... Preces", or it's `Pasc6`/`Pasc7`; otherwise show
only when the winning rank's title doesn't genuinely say "duplex" (see below), it isn't
Sunday or Saturday, and the day qualifies seasonally (`[Rule]` says "Preces", or the
week is Advent/Lent, or it's an Ember day) — further restricted under 1960 to
Wednesdays, Fridays, and Ember days specifically even within a qualifying season.
`assemblePrecesFeriales` then resolves the wrapper section through the same
`SectionResolver` every other section uses and splits it into `Unit`s, treating the
`/:...:/ ` marker on the Pope/Bishop versicle as a `.rubric` — this time confirmed
against `horas.pl:190` itself (`$line =~ s{/:(.*?):/}{setfont($smallfont, $1)}eg`,
DO's own small-font footnote rendering), correcting an earlier session's claim that no
Perl code handled it (that pass hadn't actually searched `horas.pl`). Confirmed real
Pope/Bishop `"N."` is left literal even in DO's own actual output, so there's no
dynamic "reigning Pope" data source to worry about.

The first real-fixture pass against 18 February 2026 (Ash Wednesday) caught a genuine
bug before it shipped: the rank guard was first written as a `numericPrecedence`
cutoff (`$duplex <= 2` naively read as "low-numbered ranks only"), but `preces()`'s own
`$duplex` is actually derived from the rank **title text**
(`horascommon.pl:1818`: `$vrank[1] !~ /duplex/i ? 1 : $vrank[1] =~ /semiduplex/i ? 2 :
3`), not from `numericPrecedence` at all. Ash Wednesday's real `[Rank]`
(`Tempora/Quadp3-3.txt`) is `;;Feria privilegiata;;7` — a *privileged* feria
deliberately given a high numeric precedence so it resists being superseded in
`Occurrence`, which the numeric-cutoff version wrongly read as "too festal, omit."
Switched to checking whether the title contains "duplex" and not "semiduplex" (Feria
and Feria privilegiata never do, so both pass); the real oracle test
(`ashWednesdayShowsTheRealPrecesFerialesText`) failed against the bug and passes
against the fix. New synthetic tests in `HourAssemblerTests.swift` cover the
Sancti-wins exclusion, the day-of-week restriction (Thursday in Lent, seasonally
qualified but not Wed/Fri/Ember), and the season gate itself (an ordinary Wednesday
after Epiphany, correctly day-of-week-eligible but not seasonally qualified).

A second real-data pass caught two more content bugs in the same section, both on the
Pope/Bishop versicles specifically. First, `Preces.txt`'s own source splits each
versicle across two physical lines with a trailing `~` (`"Orémus pro beatíssimo Papa
nostro~"` / `"r. N."`) — DO's own line-continuation convention (`horas.pl:117`,
`$merge_with_next = ($line =~ s/~$//)`, confirmed by `horas.pl:195-200`'s merge-and-
finalise logic), where the lowercase `r.` marks a drop-cap-style first letter for the
merged fragment, not a real response. Left unhandled, this produced a dangling `~` and
a stray unmerged `"N."` fragment instead of one clean versicle. Second, the footnote
line's own trailing space (`"...præteritur.:/ "`, confirmed in the real file) meant
`hasSuffix(":/")` never matched, so the marker was never stripped. Both fixed in
`unitsFromPrecesLines` (merge-then-trim before the marker checks, not after); the real
oracle test's exact-text assertions now pass, and a new synthetic case in
`HourAssemblerTests.swift` locks in the merge behaviour directly.

**The octave-reuse antiphon bug is now fixed (2026-09-17) — and turned out to be an
occurrence bug, not just an antiphon one.** The earlier framing ("`Tempora/Nat1-0`
covers every day of the Octave, not just its first") was itself wrong: `Nat1-0.txt`
("Dominica Infra Octavam Nativitatis") is correctly scoped to just the one Sunday that
falls within 26-31 December — the real gap was that `Occurrence.temporalPath` never
produced that path at all, always falling through to the plain day-numbered file
(`Nat26`...`Nat31`) regardless of weekday. DO reaches `Nat1-0` through a "dominical
letter" indirection — seven `Tabulae/Transfer/{a..g}.txt` tables, one per possible
Sunday-year, each redirecting exactly one of those six December dates to `Nat1-0` for
1960 rubrics. Computing the weekday directly gets the same result without porting the
letter machinery: `temporalPath` now special-cases 26-31 December, redirecting
whichever day is actually a Sunday that year. Confirmed against the real oracle
fixture for 2025-12-28 (that year's Sunday): the rendered antiphon is exactly
`Sancti/12-25`'s own `[Ant Vespera 3]`, reached only through `Nat1-0`'s cross-reference
— and this is a genuine *occurrence* fix, not just antiphon selection: Holy Innocents
(`Sancti/12-28`) and the Sunday are exactly tied at rank 5.4 under 1960 rubrics, so
before this fix, the wrong (day-numbered, low ferial-rank) file would have made Holy
Innocents win outright instead of a real tie resolved in the Sunday's favour. Six
synthetic tests cover every redirected date plus the non-Sunday/25 December
non-redirect cases; **not covered**: `horascommon.pl:457`'s further rule that the
*displaced* day-numbered office still competes as a commemoration candidate — out of
scope for the same reason Commemorations generally are (not yet folded into
`HourAssembler`).

**The Paschaltide Allelúia antiphon rule is now fixed too (2026-09-17), scoped to the
case it's confirmed correct for.** `psalmi.pl:627-644` replaces every psalm antiphon
with `alleluia_ant()`'s "Allelúia, * allelúia, allelúia." during Paschaltide, gated by
several conditions; the one ported is `!exists($winner{"Ant $hora"})`'s primary
clause — no office or Commune `[Ant Vespera]` exists at all, i.e. exactly
`assemblePsalmodia`'s own "fell through to the weekday schedule" branch, which also
makes the further `$communetype !~ /ex/i` gate vacuously true (nothing was found to be
"ex" or "vide" about). Confirmed against the real oracle fixture for 20 April 2026 (a
plain ferial Monday within Paschaltide, IV. classis, no Sancti office): every one of
the five psalms is bracketed by the Allelúia antiphon. **Not covered**: the other
OR-branch, `$commune =~ /C10/` — a Sunday within Paschaltide using the Common-of-
Sundays gets replaced even when that commune *does* supply generic antiphons (so
`pairs` wouldn't be empty and this pass's check wouldn't fire); no real fixture for
that exact case has been checked yet.

**The numbered-sub-common selection rule is now resolved (2026-09-17) — including a
regression caught and fixed before it shipped.** `[Oratio 3]`/`[Ant 3]`/`[Ant Vespera
3]`/`[Versum 3]` alongside the unsuffixed forms (real example: `Commune/C3.txt`) turned
out to be `orationes.pl`/`psalmi.pl`'s own first/second-Vespers index (`$vespera == 1`
or `3`), not a count of named saints — both `[Oratio]` and `[Oratio 3]` there carry the
same "N. et N." for two martyrs. The file layout confirms this structurally too:
`[Ant Vespera]`/`[Oratio]` sit at the top of `Commune/C1.txt`/`C3.txt` (said the evening
*before*), while the `3`-suffixed forms sit at the very end, after None — the office's
own chronological position for its second Vespers, the common "today's own Vespers"
case (`!macroContext.isFirstVespers`).

A first implementation applied this index uniformly — `Oratio $ind`/`Ant $ind`/`Ant
Vespera $ind`, each falling back to the Commune when the office itself lacked the
section — and broke the very fixture it was meant to fix: Ss. Cornelii et Cypriani (16
September 2026, `Sancti/09-16`, rank `"vide C3"`) got `Commune/C3.txt`'s own `[Ant
Vespera 3]` ("Isti sunt Sancti...", psalms 109-112+115) instead of its real Vespers
psalmody, which the fixture shows is plain ferial ("Beáti omnes * qui timent
Dóminum", psalm 127 — the ordinary Wednesday antiphon, untouched by `Commune/C3` at
all). Tracing `psalmi.pl:446-461` explained why: `exists($w{'Ant Vespera 3'})` checks
only the *office's own* hash, never the Commune directly; the one call that *does*
reach the Commune, `getproprium('Ant Vespera 3', ...)`, is gated to `$communetype =~
/ex/` — and this office's reference is `"vide"`, not `"ex"`. `orationes.pl`'s Oratio
fallback has no such gate (`if (!$w) { ...; $w = $c{"Oratio $i"}; }`, unconditional),
which is exactly why the *same* office's real collect genuinely *is* `Commune/C3.txt`'s
own `[Oratio 3]` (confirmed against the same fixture, name-substituted to "...Cornélii
et Cypriáni solémnia cólimus..."), and why `assembleMagnificat`'s `[Ant $ind]` lookup
(also confirmed real on the same office: "Gaudent in cælis...") follows the
unconditional rule too — Oratio and Magnificat-antiphon Commune fallback are
unconditional; **psalm**-antiphon Commune fallback for the `3`-index is gated to `"ex"`
references only. `assemblePsalmodia` now enforces that gate (`communeReferenceIsEx`,
checked before letting the second-Vespers `3`-index reach the Commune at all); the
`"vide"` case is confirmed against the real fixture above, the `"ex"` case is traced
from source but not yet independently confirmed against a real `"ex CN"` fixture.
Four new synthetic tests lock in all four combinations (Oratio: office-neither →
Commune's indexed wins over its plain one; psalm antiphon: `"vide"` never reaches the
Commune's indexed form, falls through to ferial; `"ex"` does reach it). Also corrected:
the earlier "antecapitulum"/concurrence guess for what `[Ant Vespera 3]` might be for
was itself never confirmed and is superseded by this — `HourAssembler`'s own top-level
doc comment and `assemblePsalmodia`'s have the full citations.

**Not yet built:** the Paschaltide Sunday/C10 nuance above; the
displaced-office-as-commemoration-candidate nuance above; and the `"ex"`-gated psalm-
antiphon Commune fallback's own independent real-fixture confirmation.

**Latin/English pairing has started (2026-09-17) — the data source question resolved
itself, and the "whole unit" content (Introductio, Conclusio, Oratio) is wired and
confirmed real; psalm/canticle verses are a separate, harder problem not yet started.**

*Data source*: `CLAUDE.md` calls for Douay-Rheims for Scripture and DO's own English
for everything else — turns out DO's own bundled `web/www/horas/English/` tree already
*is* Douay-Rheims wording throughout (confirmed by direct comparison: Ps. 109 "The
Lord said to my Lord: Sit thou at my right hand..." and the Magnificat "My soul doth
magnify the Lord..." both match DRB verbatim). One source, not two to reconcile — see
`DataBundle.english`'s doc comment. `BreviariumDataPipeline` now walks `English/` the
same way as `Latin/` (no J-to-I normalisation — `CLAUDE.md`: "Never touch English"),
merging in the shared `Ordinarium/` skeleton same as Latin does; `DataBundle.
makeEnglishCorpus()` has no Bea-equivalent overlay (confirmed: no `English-Bea`
directory exists). Bundle size with English included: 11.81 MB uncompressed JSON
(1313 English files vs. 1765 Latin) — still well within a mobile budget, no
compression need indicated yet.

*Model*: `Unit`'s cases each gained an optional English counterpart (`english:
String? = nil` etc.) rather than a parallel structure, so every existing construction
site kept compiling unchanged; only the handful of `switch`/`if case` pattern matches
needed updating for the new arity. `nil` means no English available for that unit yet.

*Wired*: `HourAssembler` takes an optional `englishCorpus:` and, when supplied, builds
a second `SectionResolver` against it with the same `macroContext`. Since `Ordinarium/
Vespera` is language-neutral shared scaffolding, resolving it again through the
English resolver walks the identical `#Name`-grouped structure with English text
wherever a `&`/`$` macro bottoms out — so Introductio/Conclusio pair positionally,
line-for-line, confirmed correct against the real bilingual fixture for 16 September
2026 (`data/oracle-fixtures/raw/spot-check/`, which exists in `_bilingual_` variants
for many named dates — no Docker/live DO needed to verify this). The Oratio case
required a second real-data-driven fix: an office/Commune's *exact* winning `(path,
section)` for Latin — e.g. `Commune/C3.txt`'s `[Oratio 3]` — is now tracked
(`resolvedLocation`) and English is queried at that *same* location, returning `nil`
rather than substituting a different, wrong section when English lacks that exact one.
This was caught for a concrete reason, not by inspection: `Commune/C3.txt`'s English
tree has no `[Oratio 3]` at all (only the plain `[Oratio]`), and a first attempt at an
independent English fallback chain rendered that mismatched plain collect's English
translation next to Latin's real `[Oratio 3]` text — DO's own real behaviour when a
language lacks a specific section is to leave that piece in Latin entirely, confirmed
by the same bilingual fixture (the English "column" for that date's collect is
untranslated Latin text, with only the name and the `$Per Dominum` ending — which
*does* exist in English's `Prayers.txt` — appearing in English).

**Known simplification, not a bug**: that same fixture shows DO mixing languages
*within* one collect at line granularity (Latin body, English ending) — this pass
gates a whole collect's English on one exact-location match, so a case like this one
gets Latin-only for the *entire* collect (including the otherwise-translatable ending)
rather than DO's finer per-line mix. Flagged rather than chased further this pass.

**Not yet started**: psalm and canticle **verse**-level English (the antiphons
themselves align "by whole unit" and could be wired the same way as Oratio once
picked up again — the open problem is specifically the verses). DO's Pius XII (Bea)
Latin psalter divides some psalms differently from the plain Vulgate/Douay-Rheims
numbering English uses — confirmed real and bigger than a mere half-verse offset:
Bea's own `Latin-Bea/Psalterium/Psalmorum/Psalm114.txt` is headed "pars prima" and
covers only 9 verses, corresponding to what the Vulgate/Douay-Rheims numbering splits
into two separate psalms, 114 and 115. Aligning Bea-Latin against Douay-Rheims-English
verse-for-verse needs a real per-psalm boundary mapping, not a formula — this is
`Psalm.swift`'s own already-flagged deferred scope limit, now with English content
available to actually solve it against, not yet attempted.

**Capitulum/Hymnus/Versus and the Psalmodia/Magnificat antiphons are now wired too
(2026-09-17), each confirmed against the real bilingual fixture for 16 September
2026** — and this pass caught two more real, previously-uncaught bugs along the way,
neither about English specifically:

1. **`[Versum $ind]` was never indexed at all** — `assembleCapitulumHymnusVersus`
   hardcoded `"Versum 1"` unconditionally. Confirmed real: the actual versicle for 16
   September ("Exsultábunt Sancti in glória...") is `Commune/C3.txt`'s `[Versum 2]`,
   reached via `[Versum 3]`'s own `@:Versum 2` cross-reference for second Vespers —
   `[Versum 1]`'s "Lætámini in Dómino..." (what the code always returned) was simply
   wrong for every second-Vespers date, undetected because no oracle test had `.versus`
   in scope until this pass added it. **Not simplified to always querying `"Versum
   2"` directly**, even though that's what several Communes' own `[Versum 3]` aliases
   to (`C1.txt`/`C1p.txt`/`C2.txt`/`C4.txt`/`C5.txt` all do) — real office files don't
   follow that pattern universally (some alias `[Versum 3]` to `[Versum 1]` instead,
   some give it a genuinely distinct versicle), so `"Versum $ind"` by name, following
   whatever the winning file's own cross-reference says, is what's actually correct.
2. **`[Hymnus Vespera]`'s raw text carries two conventions cited nowhere in DO's own
   Perl** (an exhaustive search of `horas.pl`/`specials/hymni.pl` found neither) but
   confirmed absent from the real rendered fixture: a leading `{:H-Name:}` GABC
   chant-tune identifier (stripped outright — `CLAUDE.md`'s "no chant" scope covers
   this squarely) and stanza-break `_`-only lines (replaced with a blank line, not left
   as a literal underscore). `cleanHymnText` fixes both; this was a **Latin-only**
   rendering bug this whole session simply hadn't exercised until `.hymnus` finally
   entered an oracle test's scope.

**Also confirmed a genuine, narrow DO English-tree gap, left as `nil` rather than
guessed at**: `Commune/C3.txt`'s English side has no `[Versum 3]` header at all — only
`[Versum 1]`/`[Versum 2]` directly — even though the real bilingual fixture's page
*does* show a translated versicle there. `resolvedLocation`'s "same exact section, or
nil" rule (already established for Oratio) correctly declines to guess a substitute
here; the fixture's actual language-fallback mechanism for a missing cross-referenced
section wasn't found in Perl either, and chasing it further was judged not worth
blocking this slice — flagged, not silently assumed solved.

**Psalm/canticle verse-level English is now wired too (2026-09-17), scoped
conservatively — and this pass uncovered and fixed a real, previously-undetectable
content-loss bug affecting Latin alone, not just English.**

*The alignment approach*: `pairedVerses` pairs Latin and English verses only when
their reference sequences match **exactly** — same count, same reference string
(`"114:3a"` etc., letter suffix and all) at every position. Confirmed necessary, not
merely cautious: Bea's own `Latin-Bea/Psalterium/Psalmorum/Psalm114.txt`/`Psalm115.txt`
divide the underlying material at a genuinely different point than English's
same-named files — English embeds inline `"(4a) ..."`-style annotations marking a
sub-clause as truly belonging to a different verse, and elsewhere splits mid-line at
DO's own flex-mark convention (`†`/`‡`) rather than at `"*"`. DO's own real rendering
strips these annotations and the `a`/`b` suffix for *display* (confirmed against the
real fixture for 19 January 2026 — no `"(15)"` survives, and `"115:16a"`/`"115:16b"`
both render as plain `"115:16"`) but doesn't attempt to *realign* the two languages'
divisions at all — reconstructing a true per-half-verse alignment across that
divergence would need to parse those annotations and `†`/`‡` as structural split
points too (`Psalm.swift`'s own doc comment already deliberately scopes `†`/`‡` out
for the Latin-only case) — a real, harder follow-up, not attempted now. Falling back
to Latin-only when sequences don't match exactly is deliberate: no English for a
handful of psalms beats a confidently-wrong pairing. The Gloria doxology always pairs
positionally (fixed 2-line structure, no verse-numbering risk).

*A real, wider-reaching bug found along the way*: verifying this against the real
bilingual fixture for 16 September 2026 surfaced that the Magnificat's own opening
verse, `"1:46"`, was missing **entirely** from the assembled output — not mismatched
(which the existing `.contains()`-based oracle methodology can catch), but silently
absent (which it structurally cannot, since it only flags wrong content, never missing
content). The cause: `Psalm232.txt`'s own leading title-comment line,
`"(Canticum B. Mariæ Virginis * Luc. 1:46-55)"`, was being resolved through the
*general* `SectionResolver.resolve()` path — which runs `ConditionalLineProcessor`
over every section's body. That processor misparses the parenthetical as a
`(condition)` clause; its "condition" text (`"Canticum B. Mariæ Virginis * Luc.
1:46-55"`) doesn't match any real subject/predicate, evaluates false, and the
grammar's default forward scope for an unrecognised clause (`.line`) silently
swallows the very next line — the psalm's own first verse. Tracing DO's own
`horasscripts.pl:552` showed this was never DO's real behaviour at all: psalm/canticle
files are read with a plain `do_read`, **bypassing** `setupstring_parse_file`/
`process_conditional_lines` entirely, because verse text is static and never
genuinely conditional — DO's own title-line handling (`horasscripts.pl:565-584`)
`shift()`s it off as separate display metadata, never running it through conditional
resolution in the first place. `SectionResolver.resolvePsalmText` now does the Swift
equivalent (reads the winning `[Name] (condition)` variant's raw body directly,
skipping `ConditionalLineProcessor`), and `psalmUnits`/`magnificatVerses` (Latin *and*
English) now use it instead of the general `resolve()`. `Psalm.parseVerses`'s own
existing "skip a leading `(...)` title line" logic (checking each line's reference
starts with a digit) already correctly handles the now-unmangled raw input — no
change needed there. This is a **Latin-only correctness fix**, not an English-pairing
one: every psalm/canticle with a leading parenthetical title (confirmed common in the
Bea overlay, and by extension in the Magnificat) was losing its first verse *before*
this session ever touched English, silently, for as long as `HourAssembler` has
existed — no earlier test could have caught it structurally.

**Not yet attempted**: the harder Bea/Vulgate boundary-mapping problem itself (getting
partial alignment for psalms like 114/115 rather than falling back to Latin-only
entirely) remains open, but is no longer blocking — the conservative fallback in place
is safe, tested, and confirmed correct for every case checked so far. With this,
M4's Latin/English pairing covers every section CLAUDE.md's spec calls for at some
level of fidelity (full alignment for whole-unit content and cleanly-dividing
psalms/canticles, safe Latin-only fallback for the rest).

**Alpha-readiness correctness pass (2026-09-19).** Closed the gaps flagged when M5's
snapshot-matrix pass was first checked against CLAUDE.md's own named edge cases: the
Annunciation transferred in 2027/2029/2035 and St Joseph in 2035 were previously
unimplemented (`Occurrence.swift`'s own doc comment had flagged the permanent-transfer
mechanism as unported), and three smaller nuances flagged along the way during M4 itself.

*The annual transfer mechanism* (`TransferResolver`, `TransferTableReader`,
`DataBundle.transferTable`) ports `Tabulae/Transfer/*.txt` generally — both the 35
numeric Easter-date files and the 7 dominical-letter files — rather than hand-coding just
the two named feasts, since the mechanism itself doesn't distinguish why a date is
listed. `SanctoralCalendar.candidates(...)` merges the two per `Directorium.pm`'s own
letter-then-numeric push order and swaps in the transferred office on its target date,
replacing (not merging with) the normal Kalendaria answer — `Occurrence`, `Concurrence`,
and `Commemorations` all pick this up automatically with no changes of their own, since
they already consume `candidates(...)` as their one source of sanctoral truth. Verified
against the real oracle fixtures for all 4 named target dates, all 4 corresponding
natural (impeded) dates, and — as a bonus, since the same mechanism covers it — Christ
the King's "last Sunday of October" positioning (`docs/PLAN.md`'s own earlier Nat1-0 fix
was the same idea, ported by hand for December; this generalises it).

*A real, independent bug this surfaced*: `Occurrence.decideSanctoralWins` let any
I. classis feast beat any Sunday on rank grounds alone, missing `horascommon.pl:492`'s
own `$trank[2] <= 5` guard — the rubric is "beats **II. cl.** Sundays," not *any* Sunday.
Real data confirms why this matters: `Tempora/Epi2-0` (an ordinary Sunday) is rank 5, but
`Adv1-0`/`Quad6-0`/`Pasc0-0` (Advent, Palm, Easter Sunday) are deliberately elevated to
6.9/6.91/7 specifically so a plain I. classis feast does *not* automatically win there.
Caught by the real Palm Sunday 2029 and Easter Sunday 2035 fixtures, not by the
pre-existing synthetic unit tests, which happened to pair a real high rank with the wrong
path/date and so never actually exercised this comparison for real.

*A second, related gap*: `Concurrence`'s plain rank-threshold check for "does tomorrow's
office pre-empt today's" didn't compare tomorrow's rank against *today's own* — missing
`horascommon.pl:1241-1242`'s "in concurrence of days of equal rank, the preceding takes
precedence." Real case: the Annunciation and St Joseph, both transferred onto consecutive
days in 2035, both I. classis. Fixed in `Concurrence` (today wins on a tie), and
`Commemorations` now adds the one confirmed *guaranteed* single commemoration this
produces (`horascommon.pl:1244-1249`'s own `$commemoratio = $cwinner`, separate from and
not subject to the ordinary ranklimit-filtered runner-up mechanism) — confirmed against
the real 2 April 2035 fixture ("Commemoratio: S. Joseph...").

*Three smaller HourAssembler nuances*, each investigated rather than left flagged:
- The Paschaltide `$commune =~ /C10/` Alleluia-antiphon branch (`psalmi.pl:629`) is now
  implemented for faithfulness to the real condition, but a full search of every real
  `Sancti/*.txt` referencing Commune C10 found none whose date can ever fall within
  Paschaltide — likely unreachable for this project's Universal Calendar scope, not
  confirmed against a real fixture the way the sibling branch already was.
- The "displaced day-numbered office as a commemoration candidate" rule
  (`horascommon.pl:457`, `$day > 28`) was investigated and confirmed **inert** for every
  real Vespers 2025-2040 renders: 29 December's St Thomas of Canterbury is rank 1.1
  (already excluded outright); 30 December has no Sancti file at all; 31 December's own
  second Vespers is superseded by 1 January's first Vespers before this could matter
  (confirmed against the real 2028 and 2034 fixtures). Closed as investigated, not
  silently dropped a second time.
- The "ex"-gated Commune psalm-antiphon fallback (traced from source, never confirmed
  against a real fixture) is now confirmed: 22 February 2025, *In Cathedra S. Petri
  Apostoli* (`Sancti/02-22`, `;;Duplex majus;;4;;ex C4`, no `[Ant Vespera]` of its own)
  renders `Commune/C4.txt`'s own plain antiphon ("Ecce sacérdos magnus...") for real.

All 225 Kit tests pass (`swift test`), including the full 2025-2040 oracle sweep.

**Live-device correctness pass (2026-09-19).** After the first real sideload, you reported
three concrete bugs from actual on-device use: a wrongly-shown commemoration on an evening
whose Vespers was really pre-empted by the next day's Sunday; missing Capitulum/Hymnus/
Versus on many days; and a missing Magnificat antiphon on a first-Vespers-of-Sunday date.
Investigated each against real oracle fixtures rather than guessed at.

*The wrongly-shown commemoration*: `Commemorations.resolve`'s §2b branch (tomorrow's first
Vespers pre-empts today's) was treating today's own occurrence winner as an unconditional
commemoration candidate whenever tomorrow pre-empted — but the real rule only does that
when tomorrow won by outright numeric rank superiority. When tomorrow instead won via the
Sunday/Festum-Domini-specific threshold (`horascommon.pl:1166-1176`'s own
`$cwrank[0] =~ /Dominica/i || $cwinner{Rule} =~ /Festum Domini/i` cascade), today's own
winner isn't a candidate at all. Confirmed against three real fixtures: St Januarius
(19 September 2026, Duplex, rank 3) and Advent Ember Saturday (20 December 2025, rank 4.9
— well above the old ranklimit of 2) both show no commemoration when an ordinary Sunday's
first Vespers pre-empts them; SS. Petri et Pauli (29 June, I. classis, titled neither
Dominica nor Festum Domini) pre-empting an *ordinary* Sunday the evening before *does*
commemorate that Sunday directly. Fixed by gating the displaced-office candidate on
whether tomorrow's winning office is itself titled "Dominica" or Rule-tagged "Festum
Domini." New oracle tests for all three dates (`ConcurrenceCommemorationOracleTests.swift`).

*Missing Capitulum/Hymnus/Versus*: traced to DO's third fallback tier,
`Psalterium/Special/Major Special.txt` (`capitulis.pl`'s `capitulum_major`,
`specials/hymni.pl`'s `hymnusmajor`, `specials.pl`'s `getantvers`/`getfrompsalterium`) —
ordinary "time after Pentecost" temporal files define no `Capitulum Laudes`/`Hymnus
Vespera`/`Versum N` of their own and have no Commune reference either, so `HourAssembler`
was silently omitting these sections for every such date. Implemented the fallback, keyed
by today's real day of the week (never tomorrow's, even for a first-Vespers date —
`horascommon.pl`'s `$dayofweek` is never swapped for this) — confirmed against the real
19 September 2026 fixture. This also surfaced that the Capitulum key-priority should try
`"Capitulum Laudes"` before `"Capitulum Vespera"` (109 real files use the former, only 7
narrow Dec-25/C12-votive files use the latter), which in turn found `Commune/C3.txt`'s own
`[Capitulum Laudes]` for the first time for 16 September 2026 — exposing that raw resolved
Capitulum text was never cleaned the way DO's own `_format_capitulum` cleans it (stripping
the `!` citation marker and `v.` drop-cap marker, turning the closing `R.` into the real
`℟.` glyph). Fixed with `HourAssembler.formatCapitulum`; both regressed 16 September 2026
tests pass again, and the new Major Special fallback test
(`MajorSpecialFallbackOracleTests.swift`) passes for 19 September 2026.

*The missing Magnificat antiphon* was fixed in a follow-up pass the same day, once traced
properly — the first investigation's guess (`getseant()`/`Tabulae/Stransfer`) turned out to
be wrong: that mechanism only fires when the winning office matches `Tempora/Quadp[12]`
(a narrow Lent/Passiontide branch), never for an ordinary "time after Pentecost"/"after
Epiphany" Sunday. The real mechanism is `officestring()`'s own "monthday" merge
(`SetupString.pl:717-780`): for any `Tempora/Pent*`/`Tempora/Epi*` file (except `Pent01`-
`Pent05`), DO transparently merges in that calendar week's Matins-lesson file (e.g.
`Tempora/093-0.txt`, "Dominica III. Septembris" — the historic monthly course of
Scripture, keyed by month and week-of-month, wholly independent of the Pentecost-count
numbering) *before* the office's own content is used at all. That merged-in file is where
the first-Vespers Magnificat antiphon actually lives when the Pentecost-numbered file
itself has none. Ported as `Computus.monthday` (`Date.pm:178-233`) plus
`HourAssembler.monthdayLocation`, confirmed against the real 19-20 September 2026 fixture
("Ne reminiscáris, Dómine..." — `Tempora/093-0`'s own `[Ant 1]`). For dates before July,
where the monthday merge doesn't apply at all (`Date.pm:180`), DO's own next tier is the
already-implemented `Psalterium/Special/Major Special.txt` fallback — extended to cover
`Ant` sections too and confirmed against 17-18 January 2026 ("Suscépit Deus Israël...").

That extension surfaced a genuine, previously-latent parser bug, not a Magnificat-specific
one: `RawSectionParser.qualifySelfReferences` only qualified a same-file `@:Name`
reference when it was the *first character* of the raw source line — which silently
failed for the common `(condition) @:Name` shape (a `(feria N)`-conditioned line with the
inclusion on the same line, real example: Major Special's own `[Feria Ant 3]`, six lines
each shaped exactly like this), since the leading condition clause is only stripped later,
at resolve time, by `ConditionalLineProcessor` — long after the parse-time qualification
step had already looked at the line, seen a `(` instead of an `@`, and skipped it. The
result: the literal text `"@:Feria2 Ant 3"` rendered verbatim instead of being followed.
Fixed by stripping a leading `(condition)` clause (via `ConditionalGrammar.matchLeadingClause`,
already used elsewhere for exactly this grammar) before checking for `@`, confirmed via a
regression this exact gap broke (`plainFeriaMatchesTheRealOracleFor19January2026`) once
this session's own `majorSpecialAntLocation` became the first caller to actually reach a
multi-branch conditional `@:` reference like this.

All Kit tests pass (`swift test`), including the full 2025-2040 oracle sweep and the new
oracle-fixture-backed tests above.

**Full-range content audit (2026-09-19).** Prompted by "how do we make sure we haven't
missed anything across the next twenty-odd years" — the existing full sweep
(`vespersAssemblesWithoutPlaceholderTextAcrossTheFullOracleRange`) only caught a resolver
failing outright, never a section resolving to *nothing at all* silently (the exact shape
of the Magnificat/Capitulum bugs above) or content that's present but *wrong*. Added
`vespersFullRangeContentAudit`: the same exact-text fixture diff the named single-date
tests use, every section kind, run across the entire already-fetched 2025-2040 range
(~5,844 days), plus a structural check that every section Vespers should always have is
actually present and non-empty. Not part of the default fast loop — a deliberately-run
investigative tool, its findings triaged one at a time, never by editing a fixture.

Two real, high-volume bugs found and fixed on the first run:

- **~895 of 5,844 days (15%) had no Oratio at all.** An ordinary feria whose `[Rule]`
  names `"Oratio Dominica"` (real example: `Tempora/Epi4-1`) has no collect of its own —
  the real Oratio comes from *that same week's own Sunday* file (`orationes.pl:55-61`).
  Ported as `HourAssembler.oratioDominicaOffice`. Dropped the count to 52 remaining days
  (Holy Saturday and All Souls' Day among them — a different, narrower gap, not yet
  investigated).
- **Thousands of days had wrong Hymnus/Capitulum/Versus/Oratio content.** The Commune
  fallback only ever followed *one* `"vide"`/`"ex"` hop; DO's own `getproprium` daisy-chains
  up to 5 (`specials.pl:474-508`). Real example: `Tempora/Nat02`'s (2 January) hymn chain
  is `Tempora/Nat02` → `Sancti/01-01` → `Sancti/12-25` — three hops, and the single-hop
  version stopped after one, silently rendering nothing (or, after this session's other
  fixes made `resolvedLocation` reachable more often, something wrong salvaged from a
  half-followed chain). Fixed by making `resolvedLocation` itself daisy-chain, capped at 5
  hops like the real Perl.

**Continued the same day ("we have got to fix this"), with Docker running the pinned DO
checkout locally as ground truth** (`docker compose -f scripts/docker/docker-compose.yml
up --build -d`, then invoking `officium.pl` directly inside the container exactly as
`data/SOURCE.md` documents, and in one case patching a temporary `warn` into a copy of
`capitulis.pl` inside the running container to print `$winner`/`%winner` directly — never
committed, the container was torn down afterward). Found and fixed four more real bugs
this way, each confirmed against a real fixture or the running engine directly, not
guessed:

- **A January-specific temporal transfer this project's transfer-table support hadn't
  covered.** `SanctoralCalendar.transferredCandidates` already handled `Tabulae/
  Transfer/*.txt` entries whose *source* is a Sancti reference; it explicitly skipped
  entries whose source is a `Tempora/...` path (`TransferResolver`'s own documented
  scope limit). Real example, found by patching `capitulis.pl` to print `$winner`
  directly: `Tabulae/Transfer/e.txt`'s own `01-05=Tempora/Nat2-0` (2025's own dominical
  letter) means 5 January 2025's real winning temporal file is `Tempora/Nat2-0.txt` (a
  "Holy Name of Jesus"-season Sunday file), not the plain day-numbered `Tempora/Nat05`
  this project's own week-name arithmetic would otherwise compute — and, since 4
  January's own second Vespers is outranked by that Sunday's first Vespers, the same
  wrong path was silently feeding into *its* Vespers too. Added
  `SanctoralCalendar.transferredTemporalPath` (the analogous lookup for a `Tempora/`-
  sourced entry) and a calendar-aware `Occurrence.temporalPath(day:month:year:calendar:)`
  overload, wired into every real call site (`Occurrence.resolve`,
  `Commemorations.runnersUp`, `ConditionalContextBuilder.build`).
- **The psalm-antiphon Commune fallback was missing a guard `psalmi.pl:450` actually
  has.** The `Ant Vespera 3` lookup's own Commune extension is gated not just on an
  `"ex"`-type commune reference, but on the office's own file having *neither* the
  numbered form *nor the plain* `[Ant Vespera]` — `elsif (!exists($w{'Ant Vespera'}) &&
  ...)`. Missing that second half let an office with its own real plain `[Ant Vespera]`
  (but no numbered `3` form) wrongly reach into an `"ex"`-type Commune that separately
  happens to define *its own* `[Ant Vespera 3]`, instead of using the office's own plain
  antiphons. Real, confirmed example: 1 January (`Sancti/01-01`, `"ex Sancti/12-25"`)
  has its own plain `[Ant Vespera]` ("O admirábile commércium..."), but `Sancti/12-25`
  (Christmas) also happens to define its own `[Ant Vespera 3]` ("Tecum princípium...",
  Psalm 109's ordinary Sunday antiphon) — this project's engine was wrongly reaching the
  latter. Fixed by adding the missing guard to `assemblePsalmodia`.
- **A hymn stanza can carry its own leading `* ` marker**, confirmed real via the 5
  January 2026 fixture (the closing "Iesu, tibi sit glória..." doxology of the Epiphany
  hymn, `Sancti/01-06.txt`'s own `[Hymnus Vespera]`) — not referenced anywhere in DO's
  own Perl (the same "found by comparing real fixtures, not cited" situation as the
  `v. ` drop-cap marker already handled), stripped the same way.
- **`hymnusmajor`'s own `checkmtv()` (`specials/hymni.pl:67-72`, `specials.pl:532-539`)**:
  "after 'Cum Nostra Hac Aetate'" — Pope John XXIII's 1960 motu proprio reforming the
  rubrics — "the verse has always changed" for the Confessor commons specifically
  (`$winner{Rule} =~ /C[45]/`). 1960 swaps in a revised classical-meter hymn text, stored
  under a separate `"Hymnus1 …"` key this project had never looked up at all — real
  example, `Commune/C4.txt`'s own `[Hymnus1 Vespera]`, confirmed against the real 14
  January 2025 fixture (S. Hilary): "méruit beátas Scándere sedes" (traditional) becomes
  "méruit suprémos Laudis honóres" (revised) under 1960 specifically.

Combined effect on the same 2025-2040 sweep: Oratio-entirely-missing 895→52 days;
Hymnus 3,983→1,906 days — the single biggest mover, roughly halved by the last two fixes
above. **Psalmodia (~3,560) barely moved** — spot-checking it turned up the *already-
known, already-deferred* Bea/Vulgate half-verse boundary-mapping gap (M4's own "Not yet
attempted" note, above) dominating that count, not a new bug; not re-opened here.
**Oratio-content (~1,993)/Versus (~1,855)/Capitulum (~1,176)/Canticum (~789) remain
largely unmoved** — spot-checking one more (30 January 2025, S. Martina Virgin *and
Martyr*: this project renders the Common-of-Virgins hymn "Iesu, coróna Vírginum," but the
real fixture's hymn, "Tu natale solum protege...", matches neither that Common nor its
Virgin-Martyr counterpart directly — likely her own proper text, not yet traced) confirms
this is still the same class of gap as before: individual, date/office-specific
selection branches (`gettempora()`'s remaining real branches, proper-vs-Commune
disambiguation for offices with more than one plausible source) that need tracing one at
a time, the same way each of the last four fixes was — a long tail, not a handful of
remaining root causes. Reported to you rather than continuing to guess at it blind.

**Continued the same day, prompted by "is it necessary to conduct every case on its own?
I do not want this to be hard-coded, but generated in the app."** Confirmed: none of the
fixes above or below hard-code a date — each ports a real, general rule from DO's own
source, verified against a real fixture, that then applies to every date that rule
governs. Kept pulling the same thread and found three more general mechanisms, one of
them (the Major Special mirrored-index retry landing here too) already itself a
generalisation:

- **`majorSpecialLocation` only ever used the ordinary "time after Pentecost" naming.**
  `gettempora()`'s *first* computation (`horascommon.pl:2291-2299`) picks a season
  prefix — Advent, Lent (`Quad`), Passiontide (`Quad5`), Ascension week (`Asc`),
  Paschaltide (`Pasch`), the week after Pentecost (`Pent`) — *before* ever falling back
  to the day-of-week naming this project's own fallback already had; that ordinary-time
  naming only actually applies outside every one of those seasons. Confirmed real for 10
  March 2025 (Monday, First Week of Lent): the real Capitulum/Hymnus/Versus are Major
  Special's own `[Quad Vespera]`/`[Hymnus Quad Vespera]`/`[Quad Versum 3]`, not the
  ordinary `[Feria Vespera]` this project's engine fell to before. Added
  `majorSpecialSeasonPrefix`, ported from the same `gettempora()` block already partly
  ported for the ordinary-time case.
- **`communeFallbackPath` assumed every bare (no `/`) commune reference meant
  `"Commune/…"`.** DO's own `extract_common()` (`horascommon.pl:1475-1519`) only does
  that for a reference actually shaped like a Commune *code*
  (`^C[0-9]+[a-z]*-*[123]*$`, e.g. `"C4a"`, `"C6-1"`) — its real catch-all branch
  defaults anything else to `"Tempora/…"` instead. This surfaced as a real regression
  from the season-prefix fix just above: once ordinary Pentecost-octave ferias (`Tempora/
  Pasc7-1` through `-6`) stopped silently absorbing generic ordinary-time content, their
  own real chain — `[Rank]`'s `"ex Pasc7-0"`, Pentecost Sunday's own file — turned out to
  resolve to the nonexistent `"Commune/Pasc7-0"` under the old assumption, losing the
  whole chain. Confirmed real for 9 June 2025 (Monday within the Octave of Pentecost):
  the real Capitulum/Versus are Pentecost Sunday's own "Act. 2:1-2..."/"Loquebántur
  váriis linguis...", reached only once the reference defaults to `Tempora/` correctly.
- **The psalm-verse dagger rule (`getantcross()`) was only half-ported.** When a
  psalm's antiphon quotes its own first verse verbatim (common — e.g. Psalm 132's "Ecce
  quam bonum..."), DO marks the boundary with a `‡` dagger rather than the verse's own
  ordinary mid-verse `*` split. This project's engine already added the dagger to verse
  2 (`getantcross()`'s own boundary point, `horas.pl:238-278`) but never removed verse
  1's own natural split, which never matches DO's real text there (shown as one plain,
  unsplit line). `oracleComparisonTexts`'s own `.verse` case already anticipated this
  exact shape (`guard !second.isEmpty else { return [first] }`) without it ever being
  produced. Confirmed real for 2 January 2025: "132:1 Ecce quam bonum et quam iucúndum,
  habitáre fratres in unum:" has no `*` anywhere in it. Added `removingSplit
  (fromFirstVerseOf:)`. This alone dropped the Psalmodia mismatch count from ~3,560 to
  ~3,044 — the single highest-leverage fix of this batch, since a psalm quoted verbatim
  as its own antiphon is a very common pattern, not a rare one.

Combined effect on the same sweep: Hymnus 1,906→1,015; Versus 1,855→647; Capitulum
1,176→499; Psalmodia 3,560→3,044; the Oratio/Hymnus/Capitulum/Versus "entirely absent"
counts introduced transiently by the season-prefix fix (then fixed by the commune-
fallback correction) settled back down to roughly where they started (Oratio 52,
Hymnus 14, Capitulum/Versus 0). **Still open, the same "long tail" as above**:
Psalmodia (~3,044, only the *already-known* Bea/Vulgate gap confirmed so far, not
re-investigated further this pass), Oratio-content (~1,444), Hymnus (~1,015,
S. Martina's own proper text among them), Canticum (~789), Capitulum (~499), Versus
(~647). Also noted but not fixed: a `(rubric text)`-as-parenthetical convention leaking
into rendered hymn *content* rather than being treated as a rubric, confirmed on 6 real
files (`"Prima stropha hymni sequentis dicitur flexibus genibus"`-style prefatory notes,
e.g. before *Veni Creator Spiritus*) — narrow (6 files), not chased this pass.

**Continued the same day again, prompted by "please continue with the psalmody, it
doesn't make much sense to me that it's that off for so many."** Right instinct — two
more general fixes nearly halved the Psalmodia count:

- **The `†` "flexa" mid-verse mark, unlike `‡`, is unconditionally deleted, not kept.**
  Some Bea-psalter verses carry a literal `†` directly in their own source text (8 real
  files, 14 occurrences) — `horasscripts.pl`'s own `s/†\s*//g if $noflexa;` (the
  unconditional half of the same "Breviarium Romanum style" rule that governs the `‡`
  dagger already handled contextually). This project's own `Psalm.swift` doc comment
  had explicitly scoped `†` out as "kept as literal text" — that scope note was simply
  wrong once actually checked against a real fixture. Confirmed real for 4 January
  2025: `Psalm110.txt`'s own "110:9 Redemptiónem misit pópulo suo, † státuit..." renders
  in the real fixture as "...pópulo suo, státuit..." with no `†` anywhere. Added to
  `LatinOrthography.normalize`, alongside the `eumdem`→`eundem` fix.
- **The festal fifth-psalm rule (`festalFifthPsalmNumber`) only ever checked the
  winning office's own `[Rule]`.** `psalmi.pl:577-580`'s own condition is `$rule =~
  /Psalm5.../ || ($commune{Rule} =~ /Psalm5.../ && $c eq 4)` — the Commune's own tag is
  consulted separately, precisely when the *antiphons themselves* came from that
  Commune (unnumbered, no `;;psalmNumber` tags), not merged with or gated by whether
  the office happens to have *any* `[Rule]` section at all. This project's earlier,
  single all-or-nothing office-then-Commune fallback meant an office with its own real
  `[Rule]` (just missing a `Psalm5` tag) never even looked at the Commune's — confirmed
  real for 13 January 2025 (`Sancti/01-13`, "Commemoratio Baptismatis Domini", `"ex
  Sancti/01-06"` — Epiphany): `Sancti/01-13`'s own `[Rule]` has no `Psalm5` tag, its
  antiphons come from Epiphany's own `[Ant Laudes]`, and Epiphany's own `[Rule]` has
  `"Psalm5 Vespera3=113"` — the real fixture's own fifth psalm is exactly Psalm 113,
  not the plain ferial Psalm 114 this project's engine fell back to (a *completely
  different* psalm, not a formatting difference — the kind of bug the audit's own
  substring-diff comparison catches but a quick eyeball check of "roughly the right
  shape" would have missed).

Combined effect on the same sweep: Psalmodia 3,044→1,550 — nearly halved, confirming
your own instinct that "off for so many" days pointed at a real, fixable, general cause
rather than the Bea/Vulgate gap alone. Still open: the same real Bea/Vulgate half-verse
boundary gap (M4's own note, above) now a larger share of what's left proportionally;
Oratio-content/Hymnus/Canticum/Capitulum/Versus counts unchanged by this specific pass
(they weren't the target), still the long tail documented above.

**Continued the same day again**, still chasing Psalmodia:

- **A raw `‡` in a verse's own source text is the other half of the same
  `Discussion #4504` rule as `†`.** `horasscripts.pl`'s own `s/‡\s+(.*?)\*\s*/* $1/g if
  $noflexa;` (Breviarium Romanum style): the dagger *moves* to become the verse's own
  `*` half-split point, consuming whatever ordinary `*` came later in the same verse.
  Confirmed real for 18 January 2026: `Psalm144.txt`'s own "144:19 Voluntátem
  timéntium se fáciet, ‡ et clamórem eórum áudiet, * et salvábit eos." renders as
  "...fáciet, * et clamórem eórum áudiet, et salvábit eos." — the `*` has moved to
  where the `‡` was. Added to `LatinOrthography.normalize`.
- **Self-caught regression in the same fix**: the new substitution was unscoped at
  first, and — since `OracleTests`'s own `mismatches()` reuses `LatinOrthography.
  normalize` on the *real fixture* too (`data/SOURCE.md`'s documented design) — it
  wrongly rewrote `HourAssembler`'s own *inserted* `‡` (the antiphon-quotes-a-verse
  rule, e.g. real fixture text `"132:2 ‡ Sicut óleum..."`) into a `*`, corrupting a
  comparison that was otherwise correct. Never surfaced by the user — caught by
  re-running the audit after the fix, per this project's own "always re-verify, never
  assume" discipline, and finding a *new* mismatch pattern appear where none existed
  before. Fixed by scoping the substitution to a `‡` immediately preceded by
  `,`/`;`/`:` — a genuine raw source dagger is always mid-sentence, preceded by
  punctuation; `HourAssembler`'s own inserted dagger is always preceded by a bare verse
  number, never punctuation. Regression test added
  (`daggerAfterAVerseNumberIsLeftAloneNotConvertedLikeARawFlexaMark`).

Combined effect on the same sweep: Psalmodia 1,550→989. The scope fix turned out to be
the larger contributor of the two — unsurprising in hindsight, since the corrupted,
unscoped version was quietly breaking *every* fixture comparison for a day whose
antiphon-dagger rule had already fired correctly, not just the narrow raw-`‡` case the
fix was originally written for.

**Continued the same day again, with explicit approval ("yes please, and let's continue
with this pace!") to generalise the dagger rule properly**, rather than accumulate more
special cases:

- **The psalm-verse dagger rule was still only the whole-verse special case.**
  `getantcross()` (`horas.pl:238-278`) is actually a general word-by-word matcher: it
  walks the antiphon's own words against the psalm verse's own words in lockstep
  (skipping either side's punctuation-only tokens via `depunct()`), and marks wherever
  the antiphon's words stop matching — not only when they run out exactly at the
  verse's own end. `horasscripts.pl:619-621` (the sole call site) is what unifies the
  two shapes: if the result ends with the dagger (nothing left of verse 1 to append —
  the whole-verse case), the dagger moves to the very start of verse 2 instead, and
  verse 1 loses its own split entirely; otherwise the dagger simply lands wherever the
  match stopped, right after any punctuation immediately following it (most often the
  verse's own natural `*`). Confirmed against two real fixtures with the manual trace
  before writing any code: 2 January 2025 (Psalm 132, whole match, as before) and
  19 January 2025 (Psalm 109, antiphon "Dixit Dóminus * Dómino meo: Sede a dextris
  meis." quotes only the verse's opening words — real fixture shows "109:1 Dixit
  Dóminus Dómino meo: «Sede a dextris meis, * ‡ donec ponam..." with the dagger
  landing right after the verse's own mid-verse `*`, not at the end). The antiphon's
  own display text gets a trailing `‡` whenever the match succeeds at all, confirmed
  empirically true for both fixtures, not only the whole-match case.
  Replaced the narrow `antiphonMatchesWholeVerse`/`removingSplit`/`addingLeadingDagger`
  special case with a general, token-indexed port (`daggerTokens`, `sourceTokens`,
  `displayHalves`, `applyingAntiphonDagger`) mirroring `getantcross()`'s own `pind`/
  `aind` loop exactly, including its asymmetry between a verse token skipped *during*
  matching (dropped, never reappears) and one skipped *after* the match ends (kept,
  appended literally before the dagger) — the distinction that makes the whole-match
  and partial-match cases render differently. Both real fixtures re-verified via a
  temporary diagnostic before writing permanent tests
  (`psalmVerseOneGetsAMidVerseDaggerWhenTheAntiphonQuotesOnlyItsOpeningWords` added
  alongside the existing whole-match test).

Combined effect on the same sweep: Psalmodia 989→475 — again nearly halved, confirming
the generalisation's premise: an antiphon partially quoting its own psalm's opening
words is at least as common a pattern as quoting the whole first verse. Full Kit test
suite and all 40 named-case oracle tests still pass. Still open: the same long tail as
above (Oratio-content ~1,444, Hymnus ~1,015, Canticum ~789, Versus ~647, Capitulum
~499), plus whatever remains of Psalmodia's ~475 — now plausibly dominated by the real
Bea/Vulgate half-verse boundary gap rather than a missed general rule, though not
re-confirmed by a fresh trace this pass.

**New session, prompted by "Let's clear up the psalmody before anything else!"** —
continued chasing the remaining ~475 Psalmodia mismatches rather than accepting them as
the Bea/Vulgate gap:

- **A literal or parenthesized "Allelúia" in antiphon source text is season-dependent,
  not fixed.** Some Commune/Sancti antiphon files carry this annotation either bare
  (Commune C4's own "Sacerdótes Dei... Allelúia.") or parenthesized (the Annunciation's
  own proper "Missus est... (Allelúia.)"). Ports `process_inline_alleluias`/
  `suppress_alleluia` (`LanguageTextTools.pm:39-73`, called for every displayed text
  block from `webdia.pl:681-685`): outside Paschaltide, a parenthesized occurrence is
  removed entirely (parens and all); inside Paschaltide it's kept but unbracketed
  instead. Separately, from Septuagesima through Lent (`suppress_alleluia`'s own gate,
  matching this project's own `Quadp1-3`/`Quad1-6` `weekName` naming), *any* occurrence
  — parenthesized or bare — is removed outright, along with an immediately preceding
  comma or period. First Vespers of Septuagesima Sunday itself is exempted
  (`Septuagesima_vesp()`, `horas.pl:214-221`): the last office where Alleluia is still
  said, even though the office being prayed already reads `weekName == "Quadp1"`.
  Confirmed against two real fixtures found via a fresh audit sweep: 22 February 2025
  (Sexagesima week, "In Cathedra S. Petri" using Commune C4 — the real fixture shows
  "...hymnum dícite Deo." with no "Allelúia" anywhere) and 24 March 2025 (Lent, the
  Annunciation's own proper antiphon — "...desponsátam Ioseph." with no "(Allelúia.)"
  either). Added `applyingSeasonalAlleluia`, applied to every Psalmodia antiphon (Latin
  and English) and the Magnificat's own antiphon — the two places this project's engine
  currently surfaces raw antiphon text.

Combined effect on the same sweep: Psalmodia 475→436; Canticum also dropped 789→737 as
a direct side effect (the Magnificat antiphon shares the exact same seasonal-Alleluia
exposure, several Marian and Confessor Commune antiphons carrying the same annotation).
Full Kit test suite and all 42 named-case oracle tests (two new:
`bareAlleluiaIsSuppressedDuringSexagesimaWeek`,
`parenthesizedAlleluiaIsRemovedEntirelyDuringLent`) still pass. **Not yet applied**:
Versus, which the same sweep shows carrying the identical, still-unfixed pattern
("2025-03-24: Ave, María, grátia plena. (Allelúia.)" — a versicle/response pair, not an
antiphon) — `process_inline_alleluias`/`suppress_alleluia` are DO's own general,
whole-page mechanism, so Versus (and likely some of Hymnus/Capitulum/Oratio too) plausibly
need the same treatment; out of scope for this pass, which stayed deliberately scoped to
Psalmodia per the user's own instruction. Psalmodia's remaining ~436 includes at least
one confirmed structural (not textual) gap unrelated to this fix: 19 April 2025 is Holy
Saturday, a Triduum-rubric special case this project's alpha doesn't yet model (Oratio is
also entirely absent that same day) — not chased further this pass.

**Continued the same session**, still chasing Psalmodia:

- **An antiphon with no `;;N` tag of its own was only ever paired with the default
  109-113 Sunday psalm set when a `Psalm5` override *also* existed.** `psalmi.pl:
  606-609` always does this pairing for an unnumbered antiphon, positionally against
  `@p` (the office's own default five-psalm set) — the `Psalm5` rule only ever
  overrides the *fifth* slot specifically, it was never a precondition for the pairing
  itself. This project's earlier code required `festalFifthPsalmNumber` to succeed
  before attempting the zip at all, so an ordinary Sunday or feast `[Ant Vespera]` with
  five plain, unnumbered antiphons and *no* `Psalm5` tag anywhere fell through to the
  generic ferial weekday schedule instead, losing its own proper antiphons entirely and
  substituting the wrong psalms *and* the wrong antiphons both. Confirmed real for two
  different real fixtures reached two different ways: 30 November 2025, First Sunday of
  Advent (`Tempora/Adv1-0`'s own direct `[Ant Vespera]`, resolved via its own `@:Ant
  Laudes` same-file cross-reference — already handled correctly by the existing
  inclusion resolver) and 21 April 2025, Easter Monday (`Tempora/Pasc0-1`'s own `[Rank]`
  is `ex Pasc0-0` — Easter Sunday's own file used as a Commune-like fallback via
  `communeFallbackPath`, not a genuine Commune code — whose own antiphons are the same
  unnumbered shape). Fixed by defaulting the fifth psalm to `"113"` (the ordinary
  Sunday/feast default) whenever `festalFifthPsalmNumber` finds no override, and
  attempting the positional zip whenever exactly five unnumbered antiphon lines are
  found, with or without a `Psalm5` tag.

Combined effect on the same sweep: Psalmodia 436→295 — this single fix also silently
resolved the whole Easter Octave's own wrong "Allelúia, * allelúia, allelúia." ferial
Paschaltide replacement (Easter week has its own proper, day-by-day antiphons that
simply weren't being found before, not the ferial-Paschaltide fallback this project's
engine was substituting instead) and the weekly Advent-Sunday pattern, both visible in
the same sweep's own "before" examples. Full Kit test suite and all 42 named-case
oracle tests, plus two new
(`firstSundayOfAdventPairsItsOwnUnnumberedAntiphonsWithTheDefaultSundaySet`,
`easterMondayInheritsEasterSundaysOwnUnnumberedAntiphonsViaTheExFallback`), still pass.
Psalmodia's remaining ~295 is now dominated by: the Holy Saturday/Triduum structural gap
noted above (out of this alpha's current scope); a handful of proper-feast antiphon sets
this pass didn't individually trace (Corpus Christi's own octave, Pentecost, a few
Marian feasts — visible in the sweep's own remaining examples, each a small, specific
day-count rather than a systemic pattern); and, presumably, a growing proportional share
of the original Bea/Vulgate half-verse boundary gap, not re-confirmed by a fresh trace
this pass. Combined, this session's whole Psalmodia investigation: **3,560→295, a 91.7%
reduction** across five general fixes, none of them a per-date hardcode.

**New session, prompted by "all vespers are within scope of the alpha and fix the
bea/vulgate issue. Then get on the oratio!"** — Holy Saturday's own Vespers (19 April
2025) had been carved out of scope as a "Triduum structural gap" above; tracing it
properly surfaced a previously entirely-missing, general mechanism affecting far more
than just the Triduum:

- **`Tabulae/Tempora/Generale.txt`'s own version-gated whole-week redirect table was
  never ported at all.** `Directorium.pm`'s own `load_tempora()`: the day's winning
  temporal file path (`horascommon.pl`'s own `$tday`, this project's
  `Occurrence.temporalPath`) is looked up in this table *after* being computed, and
  substituted wholesale under the 1960 rubrics — e.g. `Tempora/Quad6-6=Tempora/
  Quad6-6r;;1960 Newcal`. The redirect target is a thin override file that
  chain-extends the base file via its own leading `@Tempora/Quad6-6` line (already
  correctly handled by this project's existing inclusion resolver) for everything it
  doesn't itself redefine. Applies to *every hour of the day*, not just Vespers.
  Twenty-five real 1960-tagged entries exist across the whole liturgical year — Palm
  Sunday, Holy Thursday, Good Friday, Holy Saturday, several Sundays and ferias in
  Eastertide, Ascension, Trinity Sunday, and two more Sundays after Pentecost — none of
  which this project's engine had ever been reaching, at any hour, for any section.
  Added `TemporaRedirectResolver` (parses the table, filtered to `Tempora/`-to-`Tempora/`
  entries tagged `"1960"`, mirroring `TransferResolver`'s own established pattern),
  bundled it in `DataBundle`/`BreviariumDataPipeline` alongside the existing transfer
  table, and applied it in `Occurrence.temporalPath` right after the ordinary
  week-numbered (or date-transferred) path is computed. Confirmed real for 19 April 2025
  (Holy Saturday): the real fixture's own Vespers (`Oratio {ex Proprio de Tempore}`,
  "Concéde, quǽsumus, omnípotens Deus...") comes from `Quad6-6r`'s own `[Oratio
  Matutinum]` — text this project's engine could never reach while resolving
  `Tempora/Quad6-6` directly, since that file has no Vespers content of its own at all.
  Also confirmed for 15 June 2025 (Trinity Sunday, `Pent01-0` → `Pent01-0r`, an entirely
  non-Triduum trigger with no `Omit` involved) — proving the mechanism is genuinely
  general, not a Holy-Week special case.
- **`[Rule]`'s own general `"Omit A B C..."` directive was never ported either** — only
  its narrow `Preces Feriales` case existed. Ported `ruleOmits` (`specials.pl:83-94`:
  `$rule =~ /Omit.*? $ite/i`, `$ite` being the skeleton's own `#Name` marker's first
  word) and applied it to Incipit, the combined `Capitulum Hymnus Versus` group, and
  Conclusio, plus a separate application suppressing the appended Commemoratio.
  A substring match (not a whole-word one) is DO's own real behaviour here, not a
  simplification: the keyword `"Conclusio"` (this project's own marker spelling)
  matches a rule that says `"Conclusion"` (the English-suffixed spelling some real
  `[Rule]`s use, including Holy Saturday's own) purely because `"Conclusio"` is a
  literal prefix of `"Conclusion"`.
- **The Gloria Patri doxology after every psalm/canticle is replaced, not silently
  dropped, from Maundy Thursday's own second Vespers through Holy Saturday's**
  (`isTriduumGloriaOmitted`, ported from `horas.pl:223-234`/`303-311`): the visible page
  substitutes a small-font "Gloria omittitur" rubric note at the `&Gloria` macro's own
  call site, confirmed real for 19 April 2025 (every one of the five psalms and the
  Magnificat itself).
- **`unitsFromResolvedText` (the Oratio collect's own line-classifier) never checked for
  DO's own `!text` red-rubric-line convention** (`do-format.md`, already correctly
  handled by the sibling `unitsFromLines` via `DOMarkers.isRubricLine`) — a collect's own
  inline rubric note (`Quad6-6r`'s own "!Et sub silentio concluditur", telling the priest
  to conclude the prayer silently, one of several real Triduum rubrics of this shape) was
  rendering as plain prose with a literal leading "!" instead of as a rubric.
- **The Bea psalter's own `"a"`/`"b"` sub-verse letter is stripped from the *displayed*
  verse reference, not shown.** Ported `Psalm.strippingSubVerseLetter`
  (`horasscripts.pl:400-401`'s "remove subverse letter", `s/\d\K[a-z]//`): confirmed
  real for 19 January 2026 — a `"115:16a"`/`"115:16b"` pair both display as plain
  `"115:16"` on the real page (still two separate lines, only the visible label merges).
  This field wasn't previously displayed or oracle-compared anywhere in this project's
  own engine, so the fix has no effect on any mismatch count — it's required correctness
  ahead of the (not yet built) parallel-English UI, which `CLAUDE.md`'s own "merging
  half-verges where the Bea and Vulgate divisions differ" alignment rule already
  anticipates. The *further* step of realigning Latin/English across a genuine
  mid-verse Bea/Vulgate split (rather than just matching the displayed label) remains
  deliberately out of scope, per `pairedVerses`'s own existing doc comment — no English
  content exists yet to align against, and it would need treating `†`/`‡` as structural
  split points too.

Combined effect on the same full sweep — the redirect table alone explains most of it,
landing across nearly every section kind at once, confirming it as the single highest-
leverage fix this whole session found: **Psalmodia 295→169; Oratio 1,444→1,176; Hymnus
1,015→792; Canticum 737→628; Versus 647→438; Capitulum 499→261; Conclusio 79→31;
Introductio's own "entirely absent" count (previously 63, a `.introductio` sitting in
the audit's own `alwaysPresent` list) dropped to 0** (the audit's own `alwaysPresent`
list was also updated to drop `.introductio`/`.capitulum`/`.hymnus`/`.versus`/
`.conclusio`, since a real `[Rule]`'s own `Omit` can now legitimately make any of them
absent — matching how `.precesFeriales` was already excluded for the same reason;
`.psalmodia`/`.canticum`/`.oratio` never appear in any confirmed real `Omit` list, so
they stay). Full Kit test suite (196 tests) and all 48 named-case oracle tests, plus
four new (`holySaturdayVespersOmitsIncipitCapitulumAndConclusioEntirely`,
`holySaturdayVespersOratioComesFromTheRRedirectFileWithNoWrongCommemoration`,
`holySaturdayPsalmsAndCanticleShowGloriaOmittiturInsteadOfTheDoxology`,
`trinitySundayUsesItsOwnRRedirectedProperAntiphonNotTheOrdinaryFallback`), still pass.
Still open: Oratio's own "entirely absent" count (43 remaining, e.g. 2-3 November —
All Souls-adjacent, not yet traced) and the bulk of each category's own remaining
content mismatches — the next target, per the session's own explicit direction, is
Oratio specifically (still the largest single category by far).

**Continued the same session, "get on the oratio!"**:

- **The main Oratio's own real priority order was wrong**: `orationes.pl:63-82`
  resolves the office's own file completely — plain `[Oratio]`, then that *same
  office's own* indexed `[Oratio N]` overriding it if present — before ever consulting
  the Commune. This project's earlier code instead checked indexed-then-plain *across
  both* office and Commune together (`resolvedLocation(section: indexed) ??
  resolvedLocation(section: plain)`), which let a Commune's own generic indexed Oratio
  win over the office's own perfectly good plain one. Confirmed real for 20 January
  2025 (Ss. Fabian and Sebastian): `Sancti/01-20`'s own plain `[Oratio]` is `@Commune/
  C2::s/beáti N\. Mártyris tui atque Pontíficis/beatórum Mártyrum tuórum Fabiáni et
  Sebastiáni/` (a same-file-resolvable, name-substituted collect this project's own
  resolver already handled correctly *when actually reached* — confirmed by querying it
  directly before writing any fix), but the office's own `[Rank]` names `"vide C3"`,
  and `Commune/C3`'s own generic `[Oratio 3]` ("Da, quǽsumus... N. et N. ...", no name
  substituted) won instead under the old ordering. Added `oratioLocation`, replacing
  the old fallback chain and reusing `resolvedLocation`'s own Commune-daisy-chain logic
  (factored out into `communeChainLocation`) for the *Commune* half only, tried after
  the office's own file comes up empty — matching `orationes.pl`'s own real shape,
  including its "opposite index" Commune fallback (`$i = 4 - $i`) that hadn't been
  ported at all before.

Combined effect on the same sweep: Oratio 1,176→1,088; Oratio's own "entirely absent"
count also dropped 43→24 as a side effect (the same fix reaches offices that
previously found nothing at all). Full Kit test suite and all 48 named-case oracle
tests, plus one new (`officesOwnPlainOratioWinsOverTheCommunesOwnIndexedOne`), still
pass. Next: 26 January 2025 (S. Polycarpi) shows the *next* distinct pattern in the
same category — a whole cluster of wrong commemoration content (antiphon, versicle,
collect, and the "Commemoratio ..." heading itself) — not yet traced.

**Continued the same session**: `replaceNdot()`'s own general "N." name-substitution
mechanism (`specials.pl:778-817`) is used for *any* resolved text via `getproprium()`'s
own Commune fallback (`specials.pl:510-511`), not just the Oratio — this project's
engine only ever called its own `substituteName` for the Oratio, so a Magnificat
antiphon carrying its own "N." (the Common of Doctors' own "O Doctor óptime... beáte
N., ...") rendered the literal "N." instead of the saint's own name. The real mechanism
also picks a *different* tagged `[Name]` variant for this exact antiphon shape (the
`"Ant="`-tagged line, vocative case, `specials.pl:797-800`'s own "Doctor Antiphone:
Casus vocativus") than it does for the Oratio (the plain/default line, a different
case) — confirmed real for 14 January 2025 (St Hilary of Poitiers): `Sancti/01-14`'s
own `[Name]` is `"Hilárium\n(sed rubrica 1570 aut rubrica 1617)\nHilárii\n
Ant=Hilári"` — the Oratio gets the plain `"Hilárium"`, the Magnificat antiphon needs
the vocative `"Hilári"`. `substituteName` now takes an `isAntiphon` flag porting this
exact tag-selection logic, applied to the Magnificat's own antiphon (Latin and
English) in `assembleMagnificat`.

Combined effect on the same sweep: Canticum 628→449 (every Doctor-of-the-Church feast
across the whole range shares this one antiphon). Full Kit test suite and all 50
named-case oracle tests, plus one new
(`magnificatAntiphonSubstitutesTheDoctorsOwnVocativeName`), still pass.

**Continued the same session**, still on 26 January 2025 (S. Polycarpi)'s own wrong
commemoration cluster: static reading of `horascommon.pl`'s own multi-branch "discard
this sanctoral candidate entirely" check (`:364-387`) wasn't enough to confirm which
branch actually applied, so this round traced it directly against the pinned DO engine
running in the project's own Docker container (`scripts/docker/docker-compose.yml`) —
temporary `warn` statements added to a running container's own in-memory copy of
`horascommon.pl` (never the pinned checkout on disk), confirming `@commemoentries`
itself was already empty by the time `concurrence()`'s own commemoration-ranklimit
filter ran, i.e. the exclusion happens earlier, inside `occurrence()` itself. (One real
false trail on the way: querying `officium.pl` with an ISO `date=2025-01-26` parameter
silently falls back to the container's own system clock date instead of erroring —
DO's real CLI param is `MM-DD-YYYY`, per `scripts/oracle-date-list.pl`'s own
`"$month-$day-$year"` — a full round of debug output was garbage as a result until this
was caught and corrected.)

- **`horascommon.pl:379-381`'s own 1960-specific branch**: on *any* Sunday, once the
  winning temporal office's own rank reaches II. classis (5) or I. classis (6), a
  sanctoral candidate ranked below that *same* threshold is discarded from
  commemoration entirely — not merely filtered by the ordinary ranklimit
  (`ownVespersCommemorations`'s own flat 2 for an ordinary Sunday, which alone would
  have kept S. Polycarpi's Duplex/rank-3). Confirmed real for 26 January 2025
  ("Dominica III Post Epiphaniam", II. classis, rank 5). Added
  `Commemorations.isDiscardedOnSunday`, applied in `runnersUp` before any sanctoral
  candidate reaches the later ranklimit filters. **Only this one branch of the real
  check's four is ported** — the other three (non-Sunday I./II. classis feasts, common
  octaves, specific vigil rules) aren't yet confirmed against a real fixture, so porting
  them now would be guessing, not citing; flagged for a future pass if a real fixture
  surfaces one.

Combined effect on the same sweep: Oratio 1,088→689 — the single highest-leverage fix
of this whole Oratio round. Full Kit test suite and all 51 named-case oracle tests,
plus one new (`aDuplexRankedSaintIsNotCommemoratedOnAnIIClassisSunday`), still pass.
Still open, visible in the same sweep's own fresh examples: a literal `"_"` leaking
into Oratio content for 22 February 2025 (a stanza/paragraph-break marker rendering as
plain text somewhere it shouldn't), and 6 March 2025's own wrong commemoration of Ss.
Perpetua and Felicity (a *different* pattern from the Sunday-discard case just fixed,
since 6 March 2025 isn't itself a Sunday) — neither traced yet.

**Continued the same session**: `unitsFromResolvedText` (the Oratio/Commemoratio
line-classifier) only ever filtered genuinely *empty* lines — a bare `_`-only line, DO's
own general block-break marker (the same convention `hymnStanzas` already treats as a
stanza boundary, dropped rather than shown), rendered as a literal `"_"` line of its
own. Real example: `Sancti/02-22`'s own `[Oratio]` has a lone `_` line separating the
main collect's own `$Qui vivis` ending from the `@...:Commemoratio4` cross-reference
that follows it. Now filtered the same way blank lines already are. Full Kit test suite
and all 52 named-case oracle tests, plus one new
(`oratioDropsABareUnderscoreBlockBreakLine`), still pass — no change to the sweep's own
day-count (every date this fix touches already had another, still-open mismatch that
day), but a real, fixture-confirmed correctness fix regardless.

**Continued the same session**, tracing 6 March 2025's own wrong commemoration of Ss.
Perpetuae et Felicitatis (Duplex, rank 3, loses outright to "Feria V post Cineres",
`Tempora/Quadp3-4`, rank 3.9): a direct Docker trace of `occurrence()` initially found
`@commemoentries` empty by the time it returns, matching the shape of the Polycarp bug
just fixed — but reading `horascommon.pl:220`'s own `$sfile = shift @commemoentries;`
showed this was a red herring: for a single sanctoral candidate, the array is *always*
consumed into `$sfile` for winner-evaluation, empty-vs-populated tells nothing about
whether that candidate ends up commemorated. The real mechanism is a wholly separate
gate, `climit1960` (`horascommon.pl:1894-1919`), never previously ported: when the
*overall* winner of the day is the temporal office itself (not another sanctoral
office), a `Sancti/` candidate needs rank ≥ 6 to be Vespers-eligible at all — below that
it's Lauds-only (or nothing), never reaching Vespers, regardless of
`ownVespersCommemorations`'s own separate ranklimit (a flat 2 for an ordinary winner).
Simplifies this way because `$hora` is always `"Vespera"` in this engine, which collapses
the function's own Dominica-specific branch to the identical `$r[2] >= 6` test the
non-Dominica branch already uses — the winning office's own Dominica-ness turns out not
to matter for this specific gate. Confirmed against a second real fixture beyond
Perpetua/Felicity: 19 January 2026, where a Vigil similarly loses to an ordinary Feria
and gets no commemoration at all. Added `Commemorations.isVespersCommemorationEligible1960`,
applied in `runnersUp` before any `Sancti/` candidate reaches the later ranklimit
filters — sitting *ahead* of `ownVespersCommemorations`, not folded into it, since it's a
genuinely separate real gate.

This also caught two synthetic (non-fixture) unit tests in `CommemorationsTests.swift`
that had baked in the *old*, incomplete understanding — both asserted a rank-2 `Sancti/`
candidate gets commemorated after losing outright to a tied-rank ordinary Feria, which
the newly-confirmed `climit1960` gate now correctly excludes (and which two independent
real fixtures confirm is the actual DO behaviour). Per `CLAUDE.md`'s "never edit a
fixture to fix a test" — these aren't oracle fixtures, just hand-rolled synthetic ranks,
so they were corrected to rank 6 (genuinely `climit1960`-eligible) to keep testing
`ownVespersCommemorations`'s own ranklimit logic in isolation, plus one new test
(`ownVespersExcludesASanctiRunnerUpBelowClimit1960SixRegardlessOfTheOrdinaryRanklimit`)
pinning the composed behaviour directly.

Combined effect on the same sweep: Oratio 689→379. Full Kit test suite (198 tests, two
corrected) and all 53 named-case oracle tests, plus two new
(`losingLenFeriaCandidateBelowRankSixGetsNoVespersCommemorationAtAll` in OracleTests,
`ownVespersExcludesASanctiRunnerUpBelowClimit1960SixRegardlessOfTheOrdinaryRanklimit` in
BreviariumKitTests), still pass. No change to any other category (Hymnus 792, Canticum
449, Versus 438, Capitulum 261, Psalmodia 169, Conclusio 31), as expected — this fix is
commemoration-specific. Still open: Oratio's remaining 379 mismatched days (plus the 24
still entirely-absent and 3 missing-Magnificat-antiphon days, neither yet traced), and
the still-large Hymnus/Canticum/Versus/Capitulum categories.

**Continued the same session**, moving to Hymnus (now the single largest category at
792): `hymnusmajor` (`specials/hymni.pl:69-99`) tries a `" 3"`-suffixed section name
(office's own file, then Commune -- the same fallback chain the plain key already gets)
*before* falling to the plain `"Hymnus Vespera"` key, but only at second Vespers
(`$vespera == 3`, an unconditional guard in the real Perl with no first-Vespers
equivalent). This project's `assembleCapitulumHymnusVersus` only ever tried the plain
key, so any office defining only the indexed `[Hymnus Vespera 3]` (proper to its own
second Vespers) fell straight through to the Commune's generic hymn instead. Confirmed
real for 30 January 2025: S. Martina (Virgin and Martyr, "vide C6"), whose own
`Sancti/01-30.txt` defines `[Hymnus Vespera 3]` (a same-file cross-reference to `[Hymnus
Laudes]`, "Tu natale solum protege...") but no plain `[Hymnus Vespera]` -- this project's
engine used to render the Commune of Virgins' "Iesu, corona Virginum" instead. Checked
`capitulis.pl`'s equivalent Capitulum logic too: real DO genuinely uses a single
un-indexed `"Capitulum Laudes"` key shared between Laudes and Vespers (already this
project's own implementation, confirmed by the real Perl: 109 files use it against 7
narrow exceptions for 25 December's own first Vespers and the C12 votive office, neither
reconstructed here) -- so Capitulum needed no equivalent change.

Combined effect on the same sweep: Hymnus 792→758. Full Kit test suite and all 54
named-case oracle tests, plus one new
(`hymnusTriesTheIndexedSecondVespersSectionBeforeFallingToCommune`), still pass. No
change to any other category, as expected. Still open: the remaining 758 Hymnus
mismatches (a fresh example, 1 February 2025's "Ave maris stella" leaking its own
`/:...:/` flexis-genibus stage direction as literal text, looks like a different,
not-yet-traced pattern within the same category), plus Canticum/Versus/Oratio/
Capitulum/Psalmodia/Conclusio.

**Continued the same session**, tracing that same fresh example: `/:...:/` is DO's own
generic "render in a smaller font" wrapper (`horas.pl:190`'s own
`s{/:(.*?):/}{setfont($smallfont, $1)}eg`) — not a rubric (no colour change, just a
font-size wrapper), and it appears literally inside real source text, e.g.
`Commune/C11.txt`'s own `[Hymnus Vespera]` ("Ave maris stella") opens with
`/:Prima stropha sequentis hymni dicitur flexis genibus.:/`. This project's Hymnus
pipeline rendered the raw delimiters as literal text; added
`DOMarkers.stripSmallFontMarkers`, stripping them while keeping the inner text (the
closest faithful match this project's plain-text `Unit` model has for a font-size-only
change). Fixing that alone surfaced a second, related bug in the same stanza: the
following line's own `v. ` drop-cap marker (`DOMarkers.stripLineLabel`) was silently
never stripped, because the old code checked the *whole hymn text's own prefix* for
`"v. "` — which only ever matched when there was no preceding stage-direction line to
push the real first content line off of `line 0`. `hymnStanzas` now finds the first line
that isn't itself small-font-wrapped and strips the drop-cap from *that* line instead.
Confirmed real for 1 February 2025.

Combined effect on the same sweep: Hymnus 758→463 — the single highest-leverage fix of
this whole round, since the `/:...:/` convention turned out to be reused broadly across
many hymns and seasons, not just this one Marian common. Full Kit test suite and all 55
named-case oracle tests, plus one new
(`hymnusStripsTheSmallFontStageDirectionAndTheFollowingDropCap`), still pass. No change
to any other category. Still open: the remaining 463 Hymnus mismatches (a fresh example,
12 February 2025's revised-meter Confessor hymn "Iste Confessor..." — a mislabelled
citation, corrected below — but the checkmtv-revised text doesn't match the real
fixture, not yet traced), plus Canticum/Versus/Oratio/Capitulum/Psalmodia/Conclusio.

**Continued the same session**, tracing that 12 February 2025 example properly (Ss.
Septem Fundatorum Ordinis Servorum B.M.V., not S. Gregorius as mislabelled above):
`hymnusmajor`'s `checkmtv()` matches on the winning office's own `[Rule]` field
(`specials/hymni.pl:67-72`), which for this office says `"vide C5"` — inheriting C5's
own `[Rule]` behaviour, and matching the same `C[45]` regex `checkmtv` itself uses,
correctly per the real Perl. But the office's *real* Commune reference (its `[Rank]`
field's own `"vide C5c"`) chains through Commune/C5c → Commune/C5 → Commune/C4 (C5 itself
chain-extends `@Commune/C4`, confirmed by reading the raw file), landing on C4's own
revised `[Hymnus1 Vespera]`, "Iste Conféssor Dómini sacrátus..." (the Common of a
*Single* Confessor's hymn) — wrong for this feast of *seven* founders, and wrong anyway
since the office's own file has a proper `[Hymnus Vespera 3]`, "Matris sub almæ
numine...". Real DO guards against exactly this with its own reset-to-plain check
(`specials/hymni.pl:74-81`, not previously ported, flagged as a known gap in the earlier
addendum above): if the office's own file has neither the revised name nor its indexed
variant, but does have the plain (unrevised) name or its indexed variant, the revision
is dropped before any lookup happens. Ported as an explicit `resetsToPlain` check ahead
of `hymnusBaseSection`'s own construction.

Combined effect on the same sweep: Hymnus 463→408. Full Kit test suite and all 56
named-case oracle tests, plus one new
(`hymnusResetsToThePlainNameWhenTheOfficeHasItsOwnUnrevisedHymn`), still pass.

**Continued the same session**, on a second fresh example from the same sweep (5 April
2025, Passiontide): DO's own `!`-marked "red line" rubric convention (`horas.pl:167-
172`) can appear *mid-hymn*, not just as the whole-hymn-opening kind the `/:...:/`
small-font fix above already handles — a genuflection direction between two stanzas of
the Vexilla Regis ("`!Sequens stropha dicitur flexis genibus.`", right before "O Crux,
ave..."). `hymnStanzas` never checked `DOMarkers.isRubricLine` at all, unlike
`unitsFromLines`/`unitsFromResolvedText`, which already did elsewhere — so the literal
`!` leaked into the rendered text. Now stripped the same way, per line, alongside the
small-font marker.

Combined effect on the same sweep: Hymnus 408→191 — again a broad, high-leverage fix,
since this rubric convention recurs across multiple Passiontide/Holy-Week hymns. Full
Kit test suite and all 57 named-case oracle tests, plus one new
(`hymnusStripsAMidHymnRubricLineMarker`), still pass. No change to any other category.
Still open: the remaining 191 Hymnus mismatches (a fresh example, still 5 April 2025:
the Vexilla Regis's own final verse differs by *wording*, not markup — this project's
engine renders "In hac triúmphi glória", DO's real Passiontide-specific text is "Hoc
Passiónis témpore" — looks like a genuine version-conditional substitution DO applies
seasonally, not yet traced), plus Canticum/Versus/Oratio/Capitulum/Psalmodia/Conclusio.

**Continued the same session**, tracing that Vexilla Regis example to a real
architectural gap rather than a text-content bug: the hymn's own final verse in
`Psalterium/Special/Major Special.txt` carries an inline `(sed tempore Passionis)` /
`(sed tempore Paschali)` conditional (DO's ordinary conditional-line mechanism, already
generically ported as `ConditionalLineProcessor` — confirmed working correctly in
isolation with the right `tempore`). The real cause: on "Vespera de sequenti" (first
Vespers of tomorrow's office wins — 5 April 2025 is the Saturday before Passion Sunday,
"Dominica I Passionis ~ Vespera de sequenti"), DO's own whole rendering pass re-derives
every date-dependent global from *tomorrow's* date, not the queried one —
`get_tempus_id()` (`tempore`'s own source) among them. `HourAssembler.assembleVespers`
already made this swap for `weekName` (feeding the Major Special season fallback), but
never for `context.tempore` itself, which `ConditionalLineProcessor` actually uses to
resolve `(sed tempore ...)` lines *inside* the winning office's own content — so a
Saturday evening whose Vespers belongs to tomorrow's different season always evaluated
its own hymn's seasonal conditionals against *today's* season instead. Fixed by
deriving a `contentContext` (a copy of the ordinary context with `tempore`/`mense`
overridden to tomorrow's, when applicable) and using it for the office's own `Rule`
fetch and the main/English resolvers — while `Concurrence`/`Commemorations` keep the
original, today-based context, since occurrence/precedence genuinely is about today.

Combined effect on the same sweep: Hymnus 191→176. A comparatively narrow day-count
change for how broad the underlying gap is (it affects every inline `(sed tempore ...)`
or similar conditional inside *any* section of a "Vespera de sequenti" office, not just
Hymnus — most other sections on the same dates just don't happen to carry a
season-conditional line) — the day-count undercounts its real reach. Full Kit test
suite (197 tests) and all 58 named-case oracle tests, plus one new
(`firstVespersOfTomorrowUsesTomorrowsOwnSeasonForInlineConditionals`), still pass. No
change to any other category.

**Continued the same session**, on a fresh Canticum example (26 April 2025, Sabbato in
Albis within the Easter Octave): the real fixture's own title reads "Dominica in Albis
in Octava Paschæ ~ Vespera de sequenti", but this project's own `Concurrence` computed
`isFirstVespersOfTomorrow == false`, rendering the Octave's own shared antiphon ("Et
respiciéntes...", from `Tempora/Pasc0-0`) instead of Low Sunday's proper Magnificat
antiphon ("Cum esset sero..."). Root cause: `Concurrence`'s existing threshold cascade
(the ordinary Sunday/Festum-Domini branch, `horascommon.pl:1130-1189`) requires
tomorrow's rank to *strictly outrank* today's — Low Sunday's own 1960-conditioned rank
(6) is numerically *lower* than Sabbato in Albis's own (6.9), so that cascade alone
wrongly kept today's own Vespers. The real cause is a wholly separate branch,
`horascommon.pl:1072-1076`'s "two concurrent Tempora" case: when *neither* today's nor
tomorrow's winning office is sanctoral, the Sunday/Festum-Domini cascade doesn't apply
at all, and today's own `[Rule]` saying `"No secunda vespera"` forces tomorrow's first
Vespers to win outright regardless of rank — exactly what `Tempora/Pasc0-6.txt` (Sabbato
in Albis) says. Ported *only* this narrow, confirmed trigger (not the branch's other
disjunct, a non-strict rank comparison sitting inside a much larger real cascade this
project doesn't otherwise port) — two existing synthetic (non-fixture) unit tests
assumed the ordinary threshold cascade applies to *every* temporal-vs-temporal rank
comparison, which going further would have contradicted without real evidence either
way; left alone. The broader version was tried first and caught its own real regression
before being narrowed: it broke three real, previously-passing Holy Saturday fixture
tests (Holy Saturday's own Triduum-specific handling, already ported earlier this
session, isn't ordinary two-Tempora concurrence and must not go through this branch).

Combined effect on the same sweep (this fix touches which *office* wins Vespers at all,
so it reaches several sections at once on the same handful of dates): Canticum
449→433, Oratio 379→364, Capitulum 261→245, Psalmodia 169→153, Conclusio 31→15. Full
Kit test suite (197 tests) and all 60 named-case oracle tests, plus one new
(`sabbatoInAlbisGivesWayToLowSundaysFirstVespersViaNoSecundaVespera`), still pass.

**Continued the same session**, moving to Versus (now the largest category at 438): a
`Versum` can carry its own literal `"(Allelúja.)"` directly in the source text (real
example: the Annunciation's own `[Versum 1]`, `Sancti/03-25.txt`, shared as-is between
its ordinary Lenten occurrence and the far rarer occasion it falls within Paschaltide)
rather than an inline `(sed tempore paschali)` conditional — the same seasonal add/strip
`applyingSeasonalAlleluia` already applies to antiphons (`assemblePsalmodia`/
`assembleMagnificat`) had never been wired up for `Versus` at all. Confirmed real for 24
March 2025 (first Vespers of the Annunciation, still Lent): the real fixture's own
versicle/response reads "Ave, María, grátia plena." / "Dóminus tecum." with no
"(Allelúja.)" at all — this project's engine rendered the office's own literal
parenthetical unstripped. Applied the same function to each Versus line before building
its units.

Combined effect on the same sweep: Versus 438→406. Full Kit test suite and all 61
named-case oracle tests, plus one new
(`versusStripsALiteralAllelujaOutsidePaschaltide`), still pass. No change to any other
category. Still open: the remaining 406 Versus mismatches (fresh examples from the same
sweep, 20-22 April 2025 — Easter Octave dates — show "Mane nobíscum, Dómine, allelúia."/
"Quóniam advesperáscit, allelúia." mismatched; this looks like the *opposite* direction
of pattern, not yet traced), plus Canticum/Oratio/Capitulum/Hymnus/Psalmodia/Conclusio.

**Continued the same session**, tracing that Easter Octave example: the real fixture
doesn't show a Versus at all in the ordinary sense — its own heading reads "Versus (In
loco Capituli)" ("versicle in place of the Chapter"), and the content is a single
antiphon-formatted line, "Ant. Hæc dies * quam fecit Dóminus: exsultémus et lætémur in
ea.". This is `specials.pl:60-81`'s own "Capitulum Versum 2" rule: it replaces the whole
Capitulum/Hymnus/Versus group with the office's own `[Versum 2]` section (falling back
to Commune's), whose real content here isn't a versicle/response pair at all despite the
section's name. An earlier pass here had assumed no Vespers-relevant date had an
*unqualified* "Capitulum Versum 2" rule (Holy Saturday's own is qualified "ad Laudes
tantum", so it never reaches Vespers) — wrong: the whole Easter Octave (Easter Sunday
through Low Sunday) chain-extends `Tempora/Pasc0-0`'s own plain, unqualified "Capitulum
Versum 2;" via "Rule: ex Pasc0-0", so it applies at Vespers throughout the Octave. Added
`capitulumVersum2Qualifier`, checked ahead of the ordinary Capitulum/Hymnus/Versus
assembly in the main skeleton switch.

Combined effect on the same sweep (replacing an entire wrong three-part group with the
correct one-line content reaches every section in the group at once, across the whole
Easter Octave — 8 dates × up to 16 years): Versus 406→329, Capitulum 245→149, Hymnus
176→80. Full Kit test suite and all 62 named-case oracle tests, plus one new
(`easterSundayReplacesCapitulumHymnusVersusWithVersum2`), still pass. No change to
Canticum/Oratio/Psalmodia/Conclusio.

**Continued the same session**, on a fresh Canticum example (28 April 2025, S. Pauli a
Cruce, within the weeks following the Easter Octave): the real fixture's own Magnificat
antiphon reads "...cælo cóndidit ore, manu, allelúia.", but the office's own antiphon
text (`Sancti/04-28.txt`) ends plainly "...ore, manu." with no alleluia at all — a
*missing addition*, not a wrong removal, the opposite direction from every alleluia fix
so far this session. The real mechanism is `ensure_single_alleluia`
(`LanguageTextTools.pm:78-96`, called unconditionally from `postprocess_ant`/
`postprocess_vr` for *every* antiphon and versicle/response throughout Paschaltide,
`horas.pl:675,687-690`): add a trailing ", allelúia." whenever the text doesn't already
end with one. `applyingSeasonalAlleluia` only ever handled *removing or unbracketing*
an alleluia the source text already carried (the far rarer case — most proper antiphons
carry no alleluia annotation of their own); it never added a missing one. Folded this
in as a third step, alongside the existing bracket-handling and Septuagesima-to-Lent
suppression.

This also caught a synthetic (non-fixture) unit test
(`leavesAGenuinelyProperAntiphonAloneEvenDuringPaschaltide`) that had conflated two
different real mechanisms: the bare-"Alleluia, * alleluia, alleluia." *replacement*
(which genuinely only applies when nothing proper is defined) and
`ensure_single_alleluia`'s own separate, unconditional trailing-alleluia append (which
applies to every Paschaltide antiphon regardless of properness). Updated its expectation
to keep testing the replacement-vs-properness distinction while accepting the append.

Combined effect on the same sweep: Canticum 433→263, Versus 329→159 — both huge, since
`ensure_single_alleluia` reaches essentially every proper antiphon and versicle across
the whole ~8-10 week Paschaltide season, every year. Full Kit test suite (197 tests, one
corrected) and all 63 named-case oracle tests, plus one new
(`magnificatAntiphonGetsATrailingAllelujaDuringPaschaltideWhenMissingOne`), still pass.
No change to Oratio/Capitulum/Psalmodia/Hymnus/Conclusio.

**Continued the same session**, moving to Oratio (now the largest category at 364): a
fresh example, 22 February 2025 (In Cathedra S. Petri Apostoli), showed the main
collect's own closing doxology ("Qui vivis et regnas cum Deo Patre...Amen.") appearing
where the real fixture goes straight from the main collect to "Commemoratio S. Pauli
Apostoli" with no doxology in between at all. The office's own `[Rule]` says "Sub unica
concl[usione]" ("under a single conclusion") — `orationes.pl:216-222`'s own real
handling: when several collects are chained together within the *same* raw `[Oratio]`
section under one shared conclusion, 1960 drops the *main* collect's own closing macro
reference entirely before it's ever resolved (`$w =~ s/\$(Per|Qui) .*?\n//`), letting
the chain's own *final* collect (here, the Commemoratio S. Pauli) supply the one and
only "...Amen." at its own end. Added `strippingTrailingDoxologyMacro`, operating on the
already-resolved text (this project's `SectionResolver` has no public "raw, before
macro expansion" fetch): finds the *first* line starting "Qui "/"Per " (after stripping
its own `r. `/`v. ` drop-cap label) and removes only that line and its own
immediately-following "Amen." — deliberately `firstIndex`, not `lastIndex`, since the
chain's own *final* collect ends the exact same way and a last-match search was first
tried and caught removing exactly the wrong one before being corrected.

Combined effect on the same sweep: Oratio 364→341. Full Kit test suite and all 64
named-case oracle tests, plus one new
(`inCathedraSPetriOmitsItsOwnConclusionUnderSubUnicaConclusione`), still pass. No
change to any other category.

**Continued the same session**, on a fresh Canticum example (29 April 2025, S. Petri
Martyris, within the weeks following the Easter Octave): the real fixture's own
Magnificat antiphon, "Sancti et iusti * in Dómino gaudéte, allelúia...", is completely
different text from what this project's engine rendered ("Qui vult veníre post
me..."). The office's own `[Rank]` names `"vide C2a-1"` (Common of a Martyr not a
Bishop); real DO's `extract_common()` has a Paschaltide branch never previously ported
(`horascommon.pl:1501-1509`): for a genuine Commune-code reference, during Paschaltide,
if a `"p"`-suffixed variant of that Commune file actually exists, it's used instead,
unconditionally, for *every* section looked up against that Commune, not just the ones
the plain variant would have missed — `Commune/C2a-1p.txt` exists and chain-extends (→
`C2ap` → `C2p` → `C1p`) to a wholly different, Paschaltide-proper antiphon set. This
project's own Commune-chain walker (`communeFallbackPath`/`communeChainLocation`,
underlying essentially every Oratio/Hymnus/Versus/antiphon lookup that falls through to
a Commune) had no equivalent at all, always following the ordinary chain regardless of
season. Added `paschalCommuneFallbackPath` (checking `sectionExists(section:
"Officium")` as a proxy for the real Perl's own `-e $paschal_fname` file-existence
check, since this project has no direct "does this file exist" primitive), threaded
`weekName` through `resolvedLocation`/`communeChainLocation`/`oratioLocation` and all
their call sites to reach it.

Combined effect on the same sweep (reaching essentially every Commune-referencing
lookup throughout the whole ~8-10 week Paschaltide season, every year): Canticum
263→175, Versus 159→59, Capitulum 149→49, Hymnus 80→29, Oratio 341→325. Full Kit test
suite and all 65 named-case oracle tests, plus one new
(`sPetriMartyrisUsesThePaschaltideCommuneVariantForItsAntiphon`), still pass. No change
to Psalmodia/Conclusio.

**Continued the same session**, on a fresh Oratio example (14 April 2025, Holy Monday):
the real fixture shows a plain "Adiuva nos, Deus, salutáris noster..." collect with no
commemoration at all, but this project's engine wrongly appended a "Commemoratio Feria
Tertia Hebdomadæ Sanctæ" (Holy Tuesday) block. `Commemorations
.tomorrowsTiedFirstVespersCandidate` (the "equal rank, the preceding takes precedence"
tie-break, confirmed real for the Annunciation/St Joseph 2035 case) never reused
`Concurrence`'s own title-based exclusion (`Feria|Sabbato|Vigilia|Quat[t]*uor`, unless
overridden by `in Vigilia Epi|in octava|infra octavam|Dominica`) — every day of Holy
Week is I. classis, so tomorrow's rank clears the exact same threshold St Joseph 2035
does, but tomorrow's title is still `"Feria [Tertia/Quarta/...] Hebdomadæ Sanctæ"`,
which the exclusion should have caught. Duplicated `Concurrence`'s own (private)
exclusion check locally in `Commemorations.swift` rather than exposing it, since this
is the only other confirmed call site.

Combined effect on the same sweep: Oratio 325→262. Full Kit test suite and all 66
named-case oracle tests (including `josephTransfersToTheDayAfterAnnunciationsOwnTransfer2035`,
confirming the exclusion didn't regress the original confirmed case), plus one new
(`holyMondayDoesNotWronglyCommemorateHolyTuesday`), still pass. No change to any other
category.

**Still open, found but not yet fixed**: 16 April 2025 (Holy Wednesday) reveals a
substantially different, deeper Oratio bug than the pattern above. The real fixture is
plain: "Réspice, quǽsumus, Dómine...crucis subíre torméntum: Qui tecum vivit...Amen."
straight into `Conclusio`, with a `"secunda Domine, exaudi omittitur"` rubric noted (the
second `Domine, exaudi` versicle before `Orémus` is dropped). This project's own engine
instead renders a long, elaborate structure after that same collect: a blank
`"Commemoratio"` rubric, Holy Thursday's own Institution antiphon ("Cenántibus autem
illis..."), a `V/R` about angels (Psalm 90), `"Christus factus est pro nobis
obédiens..."` (the real Passiontide `Dominus vobiscum` replacement), `"secreto"` +
`Pater noster`, `"aliquantulum altius"`, the *same* collect repeated, and `"Et sub
silentio concluditur"` + a second `"Qui tecum vivit...Amen."` — a whole pre-existing
elaborate ritual sequence (not built this session) that appears to be misapplied to
this specific date, mixed with a wrongly-inserted commemoration of Holy Thursday. This
needs its own dedicated investigation into where that elaborate structure is meant to
apply for real, and why a commemoration block is threading through the middle of it —
substantially more involved than tonight's steady run of narrower, single-mechanism
fixes, so left for a fresh, focused pass rather than guessed at under fatigue.

**Continued in a later session**, tracing the Holy Wednesday structure bug flagged above
to its actual root cause — not the elaborate Passiontide "Christus factus est / secret
Pater Noster / repeated collect" sequence itself (that part turned out to be genuinely
correct, already-existing behaviour, not a bug), but a wrongly-inserted commemoration
threading through it: `SectionResolver.resolveRank`'s own Officium-title-fallback (`
SetupString.pl`'s `if (exists($sections{'Officium'}))` safeguard, which reads an
already-chain-resolved section hash) used a *literal*, non-chain-aware existence check
(`corpus.rawSections(path:name:).isEmpty`) instead of `sectionExists`, this project's
own chain-aware equivalent used everywhere else. A pure `@`-inclusion redirect file
(real example: `Tempora/Quad6-4r.txt`, Holy Thursday's own redirect target, whose entire
content is the single line `@Tempora/Quad6-4`) has no `[Officium]` section *directly at
that path*, so the guard failed and `OfficeRank.title` came back empty for it — even
though the same file's `[Rank]` field's own numeric/degree parts resolved correctly via
that same chain. That empty title then slipped past every title-based exclusion check
downstream (`Concurrence`'s and `Commemorations`' own `isExcludedByTitle`, both matching
against `.title`, including the Feria-exclusion just added for the Holy Monday case
above), wrongly commemorating Holy Thursday's own Institution-of-the-Eucharist antiphon
at Holy Wednesday's Vespers. Fixed by using `sectionExists` in the guard instead.

Combined effect on the same sweep: Oratio 262→230, Canticum 175→168, Versus 59→52,
Capitulum 49→51 (a real fixture check confirmed this small increase is an *already-known,
not-yet-fixed* mismatch pattern — a wrong Capitulum reading on "Friday within the week
after Ascension"-type days — recurring on a different year's occurrence, not a new
regression from this fix), Hymnus 29→22, Psalmodia 147→146. Full Kit test suite (197
tests) and all 68 named-case oracle tests, plus two new
(`resolveRankFillsTheTitleThroughAPureInclusionRedirectFile`,
`holyWednesdayDoesNotWronglyCommemorateHolyThursday`), still pass. Given the breadth of
what `resolveRank` feeds (every title-based check in the whole engine), this fix likely
reaches further than the sweep's own day-counts show on their own.

**Continued in a later session**, on a fresh Oratio example (30 April 2025, S.
Catharinæ Senensis, displaced by St Joseph the Worker's own first Vespers the next
day): `displacedVespersCommemorations`'s own ranklimit was keyed by the *displaced*
office's own rank rather than the *winner's* (tomorrow's) — confirmed wrong by direct
Docker tracing of `$comrank`, the real variable this mechanism actually gates on
(`horascommon.pl:1203`'s own `$comrank == 1.15 || ... || $comrank == 3.9` check, inside
a branch whose own entry condition requires the *winner's* rank, `$crank`, to reach 5
or 6 — never the displaced office's own `$rank`). The old, wrong threshold (based on the
displaced office's own rank) was nearly always trivially cleared (`>= 2`, the fallback
case), regardless of how high tomorrow's own rank actually was — so a plain Duplex
saint (St Catherine, rank 3) kept getting wrongly commemorated at any pre-empting first
Vespers, no matter how far it outranked her. Confirmed real for two contrasting
fixtures: 30 April 2025 itself ("Vespera de sequenti; nihil de præcedenti" — no
commemoration at all, rank 3 below the winner-rank-6 threshold of 4.2) and the
already-confirmed 28 June 2026 (SS. Petri et Pauli pre-empting an ordinary Sunday,
which *does* get commemorated, since its own real rank — 5, corrected in the synthetic
unit tests below from an earlier unrealistic 3.0 — clears that same threshold). Swapped
`displacedRank` for `winnerRank` in the ranklimit computation, matching the identical
pattern `ownVespersCommemorations` already used correctly.

This also caught two synthetic (non-fixture) unit tests whose own rank values were
unrealistic for an ordinary Sunday (3.0, when the real `Tempora/Epi2-0.txt` uses 5) —
correcting one directly, and correcting the second's own *sanctoral* candidate rank
(from a tied 5.0 to a genuinely outranking 6.0) to keep its own distinct scenario (the
Sunday losing occurrence entirely, becoming a runner-up rather than a displaced office)
intact once the Sunday's own rank became realistic.

Combined effect on the same sweep: Oratio 230→184. Full Kit test suite (197 tests, two
corrected) and all 69 named-case oracle tests (including
`aNonSundayHigherRankTomorrowDoesCommemorateTodaysOwnDisplacedWinner`, confirming the
SS. Petri et Pauli case still passes), plus one new
(`stCatharineIsNotCommemoratedWhenStJosephTheWorkersFirstVespersPreEmptsHer`), still
pass. No change to any other category.

**Continued in a later session**, on a fresh Oratio example (9 June 2025, Die II infra
octavam Pentecostes, I. classis, tied in rank with tomorrow's Die III infra octavam
Pentecostes): `Commemorations.tomorrowsTiedFirstVespersCandidate` (the "equal rank, the
preceding takes precedence" tie-break, originally built for the Annunciation/St Joseph
2035 case) wrongly commemorated the *next* day within the same privileged octave,
because its existing Feria-title exclusion doesn't catch an "infra octavam"-titled
office. Real DO routes octave-day succession through an entirely different branch —
`horascommon.pl:965-1072`'s own outer condition — which never produces a cross-day
commemoration between two ordinary octave days. Two separate real disjuncts there both
apply: `:984-988` (tomorrow's own title matches `"infra octavam|Vigilia Pent"`, not
`"Dominica"`, *and* today's own title separately matches `"infra octavam|post Octavam
Asc|Quat.*Pent|Dominica (Resurrectionis|Pentecostes)"`) and, simpler and the one
actually confirmed against the real fixture, `:990-991` (today's own *week*, not
title — `TemporalCycle.weekName`'s `"Pasc0"`/`"Pasc7"` — is within the Easter or
Pentecost octave specifically, and tomorrow's title isn't `"Dominica"`). Both were
ported as their own guards in `tomorrowsTiedFirstVespersCandidate`, deliberately kept
separate from the existing `isExcludedByTitle` (whose own "infra octavam" override
exists for a different purpose — granting an octave day its own genuine first Vespers
is correct; this is not that check). Confirmed real for 9 June 2025: the real fixture
shows no commemoration at all, even though "Die III infra octavam Pentecostes" isn't
Feria-titled and so wasn't caught by the pre-existing exclusion.

Combined effect on the same sweep: Oratio 184→152. Full Kit test suite (197 tests),
`BreviariumDataTests` (8 tests), and all 70 named-case oracle tests, plus one new
(`pentecostOctaveDayDoesNotWronglyCommemorateTheFollowingOctaveDay`), still pass. No
change to any other category.

**Continued in the same session**, moving to Canticum (now the largest remaining
category at 168): `LatinOrthography.normalizeLine` treated a whole
`@file:section:substitution` line as an opaque reference directive — structurally
correct for the `path:section` identifier, which must survive unchanged to keep
matching real file/section names, but wrong for the line's own third segment, an
`s/pattern/replacement/flags` regex that `SectionResolver.applySubstitutions` matches,
at render time, against `section`'s own content. That target content is ordinary prose
and so has *already* been J-to-I normalised by the time the substitution runs — a
`j`-spelled pattern in the substitution itself could then never match, silently turning
the whole substitution into a no-op. Confirmed real for 7 August 2025 (S. Cajetani
Confessoris, III. classis): `Sancti/08-07.txt`'s own `[Ant 1]` is
`@Tempora/Pent14-0:Ant 3:s/, allelúja//`, borrowing an ordinary "time after Pentecost"
antiphon and stripping its trailing seasonal "allelúja" for this non-Paschal feast —
the real fixture's own Magnificat antiphon ends plainly "...adiciéntur vobis." with no
alleluia at all, but this project's engine rendered "...vobis, allelúia." (the *only*
alleluia-suppression machinery that ran here, `applyingSeasonalAlleluia`, correctly did
nothing, since this date genuinely isn't Paschaltide — the bug was upstream of it,
in the substitution that should have removed the literal annotation before that logic
ever saw it). Fixed by normalising only the line's own substitution segment
(`LatinOrthography.normalizeInclusionLine`), leaving `path:section` itself untouched.
A repo-wide grep found the same `@...:s/...[Jj].../` shape in well over a hundred real
files, so this wasn't a one-date fix.

Combined effect on the same sweep: Canticum 168→146. Full Kit test suite (199 tests,
two new orthography ones) and all 71 named-case oracle tests, plus one new
(`nonPaschalBorrowedAntiphonHasItsAlleluiaStrippedNotJustRespelled`), still pass. No
change to any other category — the remaining Canticum mismatches (e.g. 2025-11-02's
Office of the Dead antiphons, 2025-12-17's O-Antiphon) are a different mechanism.

**Continued in the same session**, back on Oratio (still the largest at 152, now that
Canticum has dropped below it): `commemorationUnits` looked up a commemorated office's
`Ant`/`Versum`/`Oratio N` fields using the *winning* office's own Vespers index
(`MacroContext.isFirstVespers`, threaded straight through from `assembleCommemorations`)
— but a cross-day commemoration needs the *commemorated* office's own natural index
instead. Traced against the real Perl (`getcommemoratio`'s second argument, `$cvespera`,
`horascommon.pl`): every branch that sets up a cross-day commemoration sets `$vespera`
(the *winning* office's index) and `$cvespera` (the *commemorated* office's index) to
*opposite* values — 3-and-1 or 1-and-3, never the same — and the `@cvesp = (1, 3)`
same-day-runner-up loop confirms the pattern holds unconditionally: candidates sourced
from *today's* own date are always processed at index 3 (`@commemoentries`), candidates
from *tomorrow's* always at index 1 (`@ccommemoentries`), regardless of which of the two
days actually wins tonight's Vespers. This happened to already coincide with
`MacroContext`'s own index for `ownVespersCommemorations` (today-sourced, and today's
own office also happens to be winning at index 3 in that branch) and for
`winnerRunnersUpCommemorations` (tomorrow-sourced, tomorrow's office winning at index 1)
— but not for `displacedVespersCommemorations` (today-sourced, needs 3, but tomorrow's
office is winning at index 1) or `tomorrowsTiedFirstVespersCandidate` (tomorrow-sourced,
needs 1, but today's office is winning at index 3) — confirmed real for 31 May 2025
(Beatæ Mariæ Virginis Reginæ, II. classis, winning under the 1960 tie-break at its own
index 3): the commemorated "Dominica post Ascensionem" needs `Tempora/Pasc6-0.txt`'s own
`[Ant 1]` ("Cum vénerit Paráclitus...", the real fixture's own text), not `[Ant 3]`
("Hæc locútus sum vobis...", this project's own wrong rendering before this fix). Added
a `Commemoration.ind` field, set once (correctly, by source) in `Commemorations.swift`'s
four construction sites, rather than passed in from `MacroContext` at render time.

Combined effect on the same sweep: Oratio 152→147. Full Kit test suite (199 tests) and
all 72 named-case oracle tests, plus one new
(`crossDayCommemorationUsesItsOwnNaturalVespersIndexNotTheWinnersOwn`), still pass. No
change to any other category.

**Continued in the same session**, on Psalmodia (unchanged at 146 across the three prior
fixes this session, so a distinct mechanism): `festalFifthPsalmNumber`'s own
`value(forRuleKey:)` matched a `[Rule]` line's `"Psalm5 Vespera="` tag with a
case-sensitive `hasPrefix`, but the real Perl's own extraction regex
(`psalmi.pl:577-580`, `/Psalm5 (Vespera3?)=([0-9]+)/i`) carries `/i` on all four of its
alternatives — genuinely case-insensitive, not a simplification. Confirmed real for 28
May 2025 (Ascension's own first Vespers, `Tempora/Pasc5-4.txt`): its own `[Rule]` reads
`"Psalm5 vespera=116"`, lowercase "vespera" — the only file in the whole corpus spelled
this way (59 others use the capitalised `"Psalm5 Vespera="`) — so the case-sensitive
match silently missed it, falling back to the ordinary festal default (Psalm 113, "In
exitu Israël") instead of the real fifth psalm (116, "Laudáte Dóminum, omnes gentes").

Combined effect on the same sweep: Psalmodia 146→114 (Ascension recurs every year,
each occurrence contributing several mismatched verses). Full Kit test suite (199
tests) and all 73 named-case oracle tests, plus one new
(`festalFifthPsalmTagMatchesRegardlessOfCase`), still pass. No change to any other
category.

**Continued in the same session**, closing a gap `Occurrence`'s own type doc had
already flagged explicitly ("Ember days" among the cases "not covered by this pass"):
`Occurrence.temporalPath` never consulted DO's own "monthday" merge (`Computus.
monthday`, already ported for the Magnificat antiphon in `HourAssembler`) when deciding
the temporal office's own rank. A full-corpus grep found this only actually matters for
three files in the whole corpus — the September Ember days (`093-3`/`093-5`/`093-6`,
Wednesday/Friday/Saturday), the only monthday files that define their own `[Officium]`/
`[Rank]` at all (every other monthday file only ever supplies `[Ant 1]`/lessons, already
merged in separately). Confirmed real for 23 September 2026 (Ember Wednesday): the
ordinary week-based path's own unmerged rank is just 1 (an ordinary feria), so even a
low-grade Semiduplex saint (S. Linus, rank 2.2) numerically outranked it and wrongly won
the day outright — the real fixture's own title is "Feria Quarta Quattuor Temporum
Septembris ~ II. classis". Added a new `Occurrence.temporalPath(...corpus:context:)`
overload that checks for a monthday file defining its own `[Officium]` and, if found,
uses it as the winning path outright — confirmed via a full-corpus grep that none of the
140 monthday files ever define `[Ant Vespera]`/`[Capitulum Vespera]`/`[Hymnus Vespera]`,
so Capitulum/Hymnus/Versus/Ant Vespera correctly keep falling through to the ordinary
temporal path's own Commune/Major Special fallback exactly as they already do for any
other low-rank feria — this single fix was never expected to need any further
special-casing beyond the winner decision itself, and the sweep confirms it.

Combined effect on the same sweep — the single highest-leverage fix this whole
session, touching five categories at once from one root cause: Oratio 147→120,
Canticum 146→133, Versus 52→39, Capitulum 51→38, Hymnus 22→9 (79 mismatched lines
resolved in total). Full Kit test suite (200 tests, one new) and all 75 named-case
oracle tests, plus one new (`emberWednesdayWinsItsOwnVespersInsteadOfALowRankedSanctoralCandidate`),
still pass.

**Continued in the same session**, two further fixes found while investigating nearby
December dates in the same sweep:

- **Christmas Eve's own Capitulum.** `capitulis.pl`'s own `capitulum_major` is a
  hardcoded, narrow two-way special case, not a general "prefer the indexed key" rule:
  `$name = 'Capitulum Vespera 1' if $winner =~ /12-25/ && $vespera == 1;` (the other
  branch, `C12`'s votive office, is out of this project's current scope). Confirmed
  real for 24 December 2025 (first Vespers of Christmas): `Sancti/12-25.txt`'s own
  `[Capitulum Vespera 1]` is "Titus 3:4-5" ("Appáruit benígnitas..."), the real
  fixture's own text — trying `"Capitulum Laudes"` first (this project's own earlier,
  un-special-cased version) found the same file's own `[Capitulum Laudes]` instead
  ("Heb 1:1-2", the *second* Vespers/Lauds text).
- **The seven "O Antiphons" (17-23 December).** Ports `ant123_special`
  (`horas.pl:471-500`), called *unconditionally first* in the real `canticum()`, ahead
  of every other antiphon lookup — not a fallback tier at the bottom of the chain like
  `monthdayLocation`/`majorSpecialAntLocation`, but an override that wins outright
  whenever `$month == 12 && $day > 16 && $day < 24 && $winner =~ /tempora/i`, before the
  office's own `[Ant $ind]` is ever consulted. Confirmed real for 17 December 2025
  (Ember Wednesday in Advent, `Tempora/`-won): the real fixture's own Magnificat
  antiphon is exactly `Major Special.txt`'s own `[Adv Ant 17]`, "O Sapiéntia, * quæ ex
  ore Altíssimi prodiísti...".

Combined effect on the same sweep: Capitulum 38→22, Canticum 133→63 (the O Antiphons
recur every year's 17-23 December window, the single highest-leverage part of this
pair). Full Kit test suite (200 tests) and all 76 named-case oracle tests, plus two new
(`christmasEveUsesChristmasDaysOwnFirstVespersCapitulumNotItsSecond`,
`oAntiphonOverridesTheOrdinaryMagnificatAntiphonSeventeenToTwentyThirdDecember`), still
pass.

**Continued in the same session**, a genuinely structural fix this time, not a narrow
data quirk: `RawSectionParser` captured a preamble's whole-file inclusion (`do-format.md`)
unconditionally, even when the very next line is itself a `(sed ... omittitur)`
conditional gating it. `Tempora/Pasc6-5.txt` and `Pasc6-6.txt` (the Friday/Saturday
within the week after Ascension) are the only two real files in the whole corpus shaped
this way: `@Tempora/Pasc6-0` (Sunday after Ascension's own file) immediately followed by
`(sed rubrica 196 aut rubrica cisterciensis omittitur)` — under 1960 rubrics that
condition holds, so the real engine omits the inclusion entirely and falls through to
each section's own ordinary Commune-reference chain instead (`Pasc6-5`'s own `[Rank]`
names `"ex Tempora/Pasc5-4"`, Ascension's own file). This project's engine always
followed the base file regardless, wrongly rendering the Sunday-after-Ascension's own
Capitulum/Hymnus/Versus on both dates every year instead of Ascension's own — confirmed
real for 22 May 2026 (Friday after Ascension): the real fixture's own Capitulum is
"Act. 1:1-2" and its own Hymnus is Ascension's "Salútis humánæ Sator", not the ordinary
ferial default this project's engine fell back to via the wrong base chain.

Respecting the project's own explicit architectural rule (`docs/PLAN.md`'s 2026-09-16
data-pipeline amendment: `BreviariumData` never evaluates conditionals, only
`BreviariumKit`'s single render-time engine does — even for a condition, like this one,
that happens to only ever test `rubrica`, which is fixed for this whole app), the fix
doesn't evaluate anything at parse time. `RawOfficeFile.baseFile` becomes a small
`BaseFileReference(file:condition:)` — the trailing conditional line preserved raw,
exactly like `RawSection.condition` already is — and `SectionResolver.
resolvingBaseChain` evaluates it at render time by running the two-line preamble
snippet through the exact same `ConditionalLineProcessor` every section body already
uses, rather than re-deriving what an "omittitur" scope phrase means as new logic.

Combined effect on the same sweep: Oratio 120→111, Capitulum 22→13, Versus 39→30,
Canticum 63→54 (all four move together — two dates recurring across the full 16-year
range). Full Kit test suite (202 tests, two new) and all 77 named-case oracle tests,
plus one new (`fridayAfterAscensionUsesAscensionsOwnCapitulumNotSundayAfterAscensions`),
still pass.

**Continued in a later session**, opening with a full remaining-bugs plan (executive
summary + staged steps, approved before execution) targeting the last ~230 mismatched
lines toward zero. Two fixes landed clean; a third was found, built, confirmed to
regress broadly, and reverted rather than shipped — all reported here for the full
picture, not just the wins.

- **The general Oratio-fallback catch-all.** `orationes.pl:115-120`'s own final
  catch-all — general, not gated on any `[Rule]` text (unlike `oratioDominicaOffice`'s
  own literal `"Oratio Dominica"` trigger, a narrower, separate real mechanism nearer
  the top of the same real function): whenever the winning office is a `Tempora/` path
  and nothing else found an Oratio at all, DO falls back to that same week's own Sunday
  file's plain `[Oratio]`, or failing that, its `[Oratio 2]`. Confirmed real for 8 June
  2026 (an ordinary low-rank feria whose own winning `[Rank]` variant under 1960 has no
  Commune reference at all and no `[Oratio]` of its own): `Tempora/Pent02-0.txt`'s own
  `[Oratio]` ("Sancti nóminis tui, Dómine...") is exactly the real fixture's own text.
  This closed all 24 real dates that previously rendered with an entirely empty Oratio
  section — a structural gap flagged, not silently carried, since M4.
- **All Souls' Day transferred away by a Sunday.** Initially mistaken for a missing
  "Office of the Dead" feature — the real mechanism is much narrower and was already
  half-built: when 2 November falls on a Sunday (a dominical-letter-"e" year, e.g.
  2025), `Tabulae/Transfer/e.txt` redirects 2 November's sanctoral office from All
  Souls (`Sancti/11-02`, I. classis rank 6) to `Sancti/11-02oct` ("Secunda die infra
  Octavam Omnium Sanctorum," rank 2), which then naturally loses to the Sunday through
  completely ordinary occurrence rules — no special-casing needed once the transfer
  itself is read correctly. The bug: `TransferResolver.parseEntries` treated a line's
  *present but empty* trailing version list (`"11-02=11-02oct;;"`, nothing after the
  second `;;`) the same as a version list that explicitly doesn't list `"1960"`,
  silently discarding the one real line in the whole corpus shaped this way. Confirmed
  real for 2 November 2025: the real fixture's own winner is "Dominica XXI Post
  Pentecosten", with a plain Sunday Oratio ("Famíliam tuam..."), not any
  Requiem/Office-of-the-Dead text.

Combined effect on the same sweep: Oratio 111→108, Canticum 54→51, Versus 30→27, plus
the "sections entirely absent" structural category (24 days) closed to zero entirely.
Full Kit test suite (203 tests, three new) and all 79 named-case oracle tests, plus two
new (`ordinaryFeriaWithNoOratioOfItsOwnFallsBackToItsOwnWeeksSunday`,
`allSoulsIsTransferredAwayWhenTwoNovemberFallsOnASunday`), still pass.

**A third fix was attempted and reverted.** 6 January 2029 (Epiphany, `Sancti/01-06`,
I. classis rank 6.5, own `[Rule]` tagged `"Festum Domini"`) is real-fixture-confirmed
to lose its own second Vespers to Holy Family's first Vespers the next evening
(`Tempora/Epi1-0`, II. classis rank 5 under 1960 — numerically *lower* than Epiphany's
own), matching a second, separate real concurrence disjunct
(`horascommon.pl:1157-1163`, "on any Sunday or 1st Vespers of a Feast of the Lord:
nothing of a preceding III. cl feast") distinct from the strict-rank-inequality
pre-emption `Concurrence.resolve` already ports. A direct transcription of that
disjunct was implemented, confirmed correct for the Holy Family/Epiphany date in
isolation, but the full sweep showed a **severe regression** — Psalmodia, Oratio,
Canticum, Versus, Capitulum, and Hymnus mismatches all roughly *doubled* (e.g. Oratio
111→173), with wrong content appearing throughout the Epiphany octave and beyond
(dates like 2025-01-12, unrelated to Holy Family at all). The disjunct's own condition,
taken in isolation, doesn't explain firing that broadly — grepping the corpus found
only one other nearby file (`Epi1-0` itself) tagged `"Festum Domini"` at all — so
either the port has a mechanical bug not yet found, or this disjunct genuinely
requires more of the surrounding real cascade's own context (the several other
disjuncts in the same real `elsif`, or an ordering/precondition from an earlier branch)
to behave correctly in isolation. Reverted cleanly (confirmed via a full clean re-run,
which returned to the numbers above) rather than ship a broad regression; the
Epiphany/Holy Family case remains open, flagged here rather than silently dropped,
for a more careful re-derivation of the full real cascade before it's attempted again.

**Continued in the same session**, a fourth, cleaner fix: `festalFifthPsalmNumber` (the
`[Rule]`'s own `Psalm5 Vespera(3)=` override) was only ever consulted for the
*unnumbered*-antiphon case — but the real Perl (`psalmi.pl:560-586`) checks it
unconditionally for the 5th psalm slot, overriding even an antiphon that already
carries its own explicit `;;N` tag. Confirmed real for 15 June 2025 (Trinity Sunday,
second Vespers): `Tempora/Pent01-0`'s own `[Ant Vespera]` antiphons are all explicitly
numbered, the fifth tagged `;;116` directly — but its own `[Rule]` has `"Psalm5
Vespera3=113"` (a *different* value from its `"Psalm5 Vespera=116"`, for first
Vespers), so the real fifth psalm is 113, not the antiphon's own literal tag. Applied
as a single unconditional final step in `assemblePsalmodia` (covering the numbered,
unnumbered, and weekday-schedule-fallback cases alike, matching the real Perl's own
unconditional check), rather than duplicated across each of the three paths
separately.

Combined effect on the same sweep: Psalmodia 111→95. Full Kit test suite (203 tests)
and all 80 named-case oracle tests, plus one new
(`explicitlyNumberedFifthAntiphonStillGetsOverriddenByItsOwnRuleTag`), still pass. No
change to any other category, and no regression this time.

**Continued in the same session**, a fifth fix: `&Dominus_vobiscum2`
(`horasscripts.pl:136-140`, the Office-of-the-Dead-specific wrapper around
`&Dominus_vobiscum`) was never implemented at all, so `Prayers.txt`'s own `[A porta
inferi]` section — part of All Souls' own Oratio chain (`Sancti/11-02`'s `[Oratio
mortuorum2]` → `Commune/C9`'s `[Oratio_a_porta]` → `$A porta inferi` → `[A porta
inferi]`) — rendered the literal, unresolved macro name as text. Ported: identical to
plain `&Dominus_vobiscum` for a priest, but for a non-priest it forces `$precesferiales`
first, selecting `[Dominus]`'s own 5th line — a small-font `/:...:/ ` annotation
("secunda «Domine, exaudi» omittitur") the real fixture *does* show, but which this
project deliberately omits entirely (`CLAUDE.md`'s "no explanatory text in the office"
rule, the same precedent `majorSpecialAntLocation`'s own `/:ut in Proprio de
Tempore:/` placeholder already follows) rather than reproduce DO's own literal
small-font UI element. Confirmed real for 3 November 2025 (All Souls' Day proper,
transferred here since 2 November is a Sunday that year): every other line of the real
fixture's own Oratio now matches exactly.

**Not addressed by this fix, and left open**: the same date's own Conclusio still
mismatches — All Souls' Day sets `"Special Conclusio"` in its own `[Rule]`
(`specials.pl:378-383`), a real mechanism this project doesn't implement at all yet
(the winning office's own `[Conclusio]` section should replace the ordinary skeleton's
generic one entirely). Flagged here rather than silently left unexplained.

Combined effect on the same sweep: Oratio 108→93. Full Kit test suite (203 tests) and
all 81 named-case oracle tests, plus one new
(`dominusVobiscum2ResolvesInsteadOfLeakingTheLiteralMacroName`), still pass. No change
to any other category.

**Continued in the same session**, a sixth fix, closing the Conclusio gap flagged
immediately above: `specials.pl:378-383`'s own "Special conclusions, e.g. on All
Souls' day" — when the winning office's own `[Rule]` contains `"Special Conclusio"`,
the whole Conclusio group's content is the winning office's own `[Conclusio]` section
verbatim, replacing the ordinary skeleton's generic one entirely. Not implemented at
all before this fix, so the ordinary "Dómine, exáudi... Benedicámus Dómino..."
skeleton always rendered instead. Confirmed real for 3 November 2025 (All Souls' Day
proper, transferred here since 2 November is a Sunday that year): `Sancti/11-02`'s own
`[Conclusio]` is "Conclusio specialis" / `&Gloria` / "V. Requiéscant in pace. R.
Amen." — not the ordinary skeleton text the group would otherwise assemble.

Along the way, found and fixed a real bug in the assembler's own text-splitting: the
first implementation attempt resolved the office's own `[Conclusio]` section with
`unitsFromResolvedText`, which strips a line's own V./R. label unconditionally while
building only `.prose`/`.rubric` units — it has no versicle/response pairing at all,
because every prior caller's own raw resolved text already had its V./R. intro
supplied separately by the skeleton. That produced two unpaired `.prose` units
("Requiéscant in pace." / "Amen.") instead of one `.versicleResponse`. Fixed by
switching to `unitsFromLines` (pre-splitting the resolved text into `[String]`
first), which already has correct V./R.-pairing logic and is exactly what every
other skeleton-driven group already uses.

Effect on the same sweep: Conclusio 15→1 (the one remaining day, 2030-11-02, is a
distinct, not yet traced case). Full Kit test suite (203 tests), Data test suite (8
tests), and all 82 named-case oracle tests, plus one new
(`allSoulsUsesItsOwnConclusioNotTheOrdinarySkeletonOne`), still pass. No regression to
any other category.

**Continued in the same session**, a seventh fix: `orationes.pl:585-594`'s "1960: at
most one commemoration on a high-ranked day" rule was reducing to the first candidate
`Commemorations.resolve` returned (insertion order), a known-approximate placeholder
already flagged in `HourAssembler`'s own doc comment. The real survivor is picked by a
numeric priority key (`orationes.pl:551-561`): a Sunday-titled candidate's own key is
unconditionally `7000` (every 1960-family version string fails `$version =~
/trident/i`), fixed and higher than any non-Sunday candidate's `$cr[2] * 1000` (at most
`6000`, for I. classis) — so a Sunday-titled candidate always outranks every non-Sunday
one regardless of its own rank. Ported as `highestPriorityCommemoration`. Confirmed real
for 27 December 2025 (S. Ioannis Apostoli, II. classis, rank 5, winning outright): the
candidate pool has two entries — today's own runner-up (`Tempora/Nat27`, "Dies III infra
Octavam Nativitatis", rank 5) and the tied-tomorrow Sunday ("Dominica Infra Octavam
Nativitatis") — and the real fixture commemorates the Sunday, not the temporal
runner-up this project rendered before this fix. New test:
`sundayCommemorationOutranksSameDayTemporalRunnerUp`.

**Continued in the same session**, an eighth fix, resolving the Aug-16-vs-Jan-13
Psalm5-Commune contradiction flagged as an open, self-acknowledged gap at the end of the
previous session: `festalFifthPsalmNumber` no longer ever consults the Commune's own
`[Rule]` for a `"Psalm5 Vespera(3)="` tag — only the winning office's own `[Rule]`.
`psalmi.pl:577-580`'s real condition does have a second, Commune-Rule-gated alternative
(`($commune{Rule} =~ /Psalm5.../ && $c eq 4)`), but direct instrumentation of the real
Perl in the pinned Docker container (a temporary `warn` inserted at the check, run
against the live engine, then reverted) showed `$c` is empty/undef at that exact point
for *every* case traced — including 13 January 2025, the very case the old Commune
fallback was built to match. The `$c` at that check turns out to be a bare, undeclared
Perl global (`specials/psalmi.pl` has `# use strict;` commented out), not the
antiphon-lookup's own same-named `my $c` a few dozen lines above despite the identical
name and nearby textual location — real DO's own Commune-gated alternative essentially
never fires. The previous session's Commune fallback (keyed on "did the antiphons come
from a different path than the office," an approximation of `$c eq 4`) happened to give
the right answer for 13 January 2025 only because Psalm 113 is *also* the ordinary
festal default with no override at all — but it wrongly fired for 16 August 2025 (S.
Ioachim, `Commune/C5`'s own `"Psalm5 Vespera=116"`, no `Vespera3=` counterpart),
rendering 116 instead of the real fixture's 113. Removed rather than reconciled: there's
no principled, safely-portable version of "was `$c` left at 4 by some earlier, unrelated
`getproprium` call" to reconstruct. New test:
`festalFifthPsalmIgnoresTheCommunesOwnTagWhenTheOfficeHasNoneOfItsOwn`; the two
pre-existing tests in the same file (13 January 2025, 28 May 2025) still pass unchanged,
since neither actually depends on the Commune fallback once traced through (13 January's
113 comes from the ordinary default; 28 May's 116 comes from the office's own `[Rule]`
directly, term A/C, never gated by `$c`).

Combined effect confirmed against a full 2025-2040 sweep, run later the same session:
Oratio 93→86, Psalmodia 95→81 — both net-positive, no other category affected.

**Full-suite validation note (this session):** this machine suffered severe, sustained,
oscillating CPU contention for several hours (independently confirmed via `Get-Process`
CPU-time deltas showing genuine but very slow progress, never a hard stall — other
processes on the shared machine, not a code issue) that prevented a full `swift test`
run from completing in reasonable time. Both new fixes' own dedicated oracle tests
were run individually and passed cleanly *before* the contention worsened; the fixes
were committed on that partial validation, with a full-suite confirmation run left going
in the background to catch anything missed.

**That confirmation run has now finished — one failure, not a regression in the two new
fixes.** All 84 named oracle tests passed (including both new ones), all 8
`BreviariumDataTests` passed, and exactly one of the 203 `BreviariumKitTests` failed:
`festalUnnumberedAntiphonsPairWithTheSundayPsalmsAndARuleGivenFifth`, a *synthetic* unit
test whose own doc comment already flagged the risk — it asserted the Commune-Rule
fallback this session's Psalm5 fix removed, on a fixture it had explicitly built to
"additionally exercise that the mechanism also works when reached through a Commune
fallback, which isn't independently confirmed against a real fixture." That caveat
turned out to be exactly right: the live Perl instrumentation proved the Commune
fallback isn't real DO behaviour at all. Fixed the test to match the confirmed real
shape instead (the `[Rule]` tag lives directly on the office, like the real S. Agatha
case its own comment already cites, not on the Commune) rather than the disproven one.
Full suite (203 Kit + 8 Data + 84 named oracle) now passes clean.

**Continued in the same session**, a full fresh 2025-2040 sweep (run once the above was
confirmed clean) surfaced counts of Oratio 86, Psalmodia 81, Canticum 51, Versus 27,
Capitulum 13, Hymnus 9, Conclusio 1 — and, using the sweep's own wait time for active
investigation rather than idle polling (per standing guidance), found and fixed four
more bugs, three of them confirmed by reading `specials.pl`/`psalmi.pl`/`orationes.pl`
directly rather than by a sweep diff (the sweep's own `mismatches()` can only ever catch
*wrong* rendered content, never *missing* content it never saw at all — a structural
blind spot these four exploit in different ways):

1. **`ruleOmits` lacked a real global guard.** `specials.pl:83-94`'s own closing
   condition, `($rule !~ /Omit ad Matutinum/ || $hora eq 'Matutinum')`, checks the
   *whole* `[Rule]` text, not the specific `Omit` clause being evaluated — if the rule
   contains `"Omit ad Matutinum"` **anywhere**, no `"Omit ..."` directive in that rule
   applies to any hour but Matins, for *any* item. Since this project only ever renders
   `hora == "Vespera"`, this project's own version of the check collapses to: whenever
   the rule contains `"Omit ad Matutinum"` anywhere, never omit anything. Confirmed real
   for 6 January 2025 (Epiphany, first Vespers): `Sancti/01-06.txt`'s own `[Rule]` is
   exactly `"Omit ad Matutinum Incipit Invitatorium Hymnus"` — Matins-only — but this
   project's earlier version matched `"Omit"` then found `" Incipit"` later on the same
   line and wrongly rendered an *empty* Incipit section, even though the real fixture's
   own Vespers shows the ordinary "Deus in adiutorium..." Incipit in full. Grepping the
   whole corpus found exactly one file using this literal phrase (`Sancti/01-06.txt`,
   plus the Dominican `SanctiOP` variant) — narrow, but genuinely invisible to the sweep:
   `.introductio` is deliberately excluded from `alwaysPresent` (a real `"Omit"` can
   legitimately empty it), and `mismatches` only checks that *rendered* text appears in
   the fixture — an empty section has no rendered text to check at all. New tests:
   `epiphanyDoesNotWronglyOmitVespersOwnIncipit`,
   `holySaturdayStillOmitsItsOwnIncipitAtVespers` (confirms the fix doesn't disturb Holy
   Saturday's own genuine, unqualified Vespers-scoped Omit).

2. **`oratioDominicaOffice` missed a second, dynamic trigger.** `orationes.pl:44-53`'s
   own "Special handling for days during the suppressed octave of the Epiphany"
   synthesizes an `"Oratio Dominica"` flag on the fly (`$rule .= "Oratio Dominica\n"`)
   whenever the current week is `Epi1` and the winning office's own `[Rule]` carries
   `"Infra octavam Epiphaniæ Domini"` — even though the office's own literal `[Rule]`
   text never says `"Oratio Dominica"` itself. This project's port only checked for the
   literal text, missing the synthetic case entirely. Confirmed real for 12 January 2026
   (`Sancti/01-12`, the Monday after that year's 11 January Sunday within the octave):
   the real fixture's own collect is `Epi1-0a`'s "Vota, quaesumus, Domine..." — not
   `Sancti/01-06`'s own "Deus, qui hodierna die..." this project rendered instead via the
   office's ordinary `"vide Sancti/01-06"` Commune-chain fallback (a real mechanism, just
   the wrong one here) — and confirmed the gate is genuinely week-scoped, not
   octave-wide, against 7 January 2026 (still week `Nat1`, before that year's Sunday),
   where the real fixture *does* still show Epiphany's own collect. New test:
   `epiphanyOctaveDayAfterTheOctaveSundayUsesTheOldSundayCollect`.

3. **The unnumbered-antiphon default psalm numbers were hardcoded to 109-113.**
   `psalmi.pl:606-609`'s own positional pairing of an unnumbered antiphon with `@p` was
   already ported, but `@p` itself isn't always the festal 109-113 set — `psalmi.pl:
   499-524`'s own gate (`$rule =~ /Psalmi Dominica/i || ($commune{Rule} && $commune{Rule}
   =~ /Psalmi Dominica/i)`, this project's 1960/non-Cist scope) decides which of two real
   sources supplies it: the festal `"Day0 $hora"` set when the gate passes, or the
   *plain weekday* `"Day$dayofweek $hora"` default when it doesn't — `$dayofweek` being
   the actual calendar day of the date rendered, not the winning Sunday office's own
   natural day. A Sunday reached via its own *first* Vespers is rendered on the
   preceding Saturday's own calendar date, so `$dayofweek` is 6, not 0. Confirmed real
   for 29 November 2025 (First Vespers of Advent I, `Tempora/Adv1-0`, rendered on its own
   Saturday date): `[Rule]` has no `"Psalmi Dominica"` tag and no Commune at all, so the
   gate fails — the real fixture's own first psalm is "143(1-8)" (`Psalmi major.txt`'s
   own "Day6 Vespera" first entry), not "109". Contrast 30 November 2025 (the same
   Sunday's own *second* Vespers, rendered on the Sunday's own date, `$dayofweek == 0`):
   the real fixture *does* use 109-113 there — not because of the gate (still fails, same
   `[Rule]`) but because `"Day0 Vespera"` *is* the ordinary Sunday-default numbering
   anyway, confirming the fix's dayOfWeek-keyed lookup (not a reintroduced hardcoded
   festal default) gets this contrasting case right too. New tests:
   `firstVespersOfAnUngatedSundayUsesTheWeekdaysOwnPsalmNumbersNotTheFestalDefault`,
   `secondVespersOfTheSameSundayStillUsesTheFestalDefault`.

4. **`psalmTitleNumber` wrongly stripped a real, displayed verse-range suffix.** A long
   psalm split across two of the hour's five Vespers slots (`Psalmi major.txt`'s own
   notation, e.g. `"138(1-13)"`/`"138(14-24)"`) had its own `"(N-M)"` range stripped from
   the *title* by this project's engine, on the assumption — never actually checked
   against the literal fixture text — that the range was "an internal file-organisation
   detail... not something recited or printed as part of the title." Direct fixture
   checks for two separate real dates disprove this: 9 April 2027 (`Tempora/Quad6-6`,
   a plain ferial Friday, `Psalmus 138` split) and 29 November 2025 (Advent I's own first
   Vespers, `Psalmus 143` split, found investigating fix 3 above) both show the range in
   the title verbatim — "Psalmus 138(1-13)", "Psalmus 143(1-8)". Removed the stripping
   entirely; fixed the one pre-existing test whose own assertion had silently encoded the
   wrong behaviour (`fridayFerialVespersSplitsPsalm138AcrossItsFirstTwoSlots`, `docs/
   PLAN.md`'s own M4-era citation had only confirmed verses stopped crashing, never
   checked the literal title text).

The fast suite's own first run after these four landed caught one real regression in a
*synthetic* unit test, `festalUnnumberedAntiphonsPairWithTheSundayPsalmsAndARuleGivenFifth`
— not a bug in the fix itself, but a fixture gap: fix 3's own "Psalmi Dominica" gate now
genuinely needs a real `"Day0 Vespera"` number source to consult, and the shared
synthetic `Psalmi major` fixture only ever defined `"Day1 Vespera"` (sufficient for
every previously-existing test). Added `"Day0 Vespera"` (five placeholder-antiphon,
real-number entries) and a `"Psalmi Dominica"` tag on the synthetic test's own
`Commune/C99` (matching the real S. Agatha shape this test already cites — her own
"Psalmi Dominica" comes from her Commune, C6, not her own office file either). Full
suite (203 Kit + 8 Data + 89 named oracle, four new) confirmed clean after this fix.

Combined effect on a fresh full sweep: Oratio 86→52, Psalmodia 81→23 — both large wins.
Canticum (51), Versus (27), Capitulum (13), Hymnus (9), and Conclusio (1) unchanged, as
expected (none of these four fixes touch those categories). Total mismatches across the
whole sweep for the session: 268→176.

**Still open, traced but not resolved**: a distinct Oratio-commemoration-versicle bug
found in the same sweep, 24/25 March-adjacent (Annunciation displacing a Passiontide
feria's own second Vespers, commemorated at Annunciation's first Vespers). The real
fixture's own commemoration versicle is "Eripe me, Domine, ab homine malo. / A viro
iniquo eripe me." (Psalm 139:2-shaped); this project's engine renders the generic
seasonal fallback "Angelis suis Deus mandavit de te." (`Psalterium/Special/Major
Special.txt`'s own `[Quad Versum 3]`) instead. Traced the real `getcommemoratio`'s own
versicle-lookup chain (`orationes.pl:791-802`) directly via live Perl instrumentation in
the pinned Docker container: the displaced office (`Tempora/Quad5-2`, "Feria Tertia
infra Hebdomadam Passionis") genuinely has no `[Versum]` section of its own and no
Commune reference at all, so by that chain's own logic the render *should* reach
`getfrompsalterium('Versum', 3, ...)` — which *does* return exactly the "Angelis suis"
text this project renders, `[Quad Versum 3]` being the only real `[Quad Versum N]`
section that exists at all (no `[Quad Versum 1]`). Instrumenting `getcommemoratio`
directly at that lookup showed `$commemo`/`$file` both empty and no `Versum` keys in
either `%w`/`%c` — consistent with what's expected, yet the *actual* rendered fixture
still doesn't match, meaning either a different, not-yet-found real function handles
this specific "commemorate the displaced office at a pre-empting first Vespers"
case, or something downstream of this lookup overrides `$v` before final output.
Left unresolved rather than guessed at — flagged here for a fresh, focused pass.

**Continued in a later session (2026-09-24)**, working from an explicit user gameplan:
investigate the All Souls and Epiphany mismatch clusters in depth first (without making
changes), then execute fixes for what those investigations found, then whittle down each
remaining category least-to-most. The two investigations, done via live Docker tracing
and careful reading of `specials.pl`/`horascommon.pl` with no code changes, surfaced four
independent, narrowly-scoped bugs, all now fixed and confirmed:

1. **All Souls: the `Capitulum Versum 2` replacement always built an `.antiphon` unit.**
   `specials.pl:60-81`'s own replacement mechanism doesn't always produce an
   antiphon-formatted line — All Souls' own `[Versum 2]` (→ `Commune/C9`'s own
   `[Versum 1]` via cross-reference) is a genuine `"V. .../R. ..."` pair ("Audívi vocem
   de cælo dicéntem mihi. / Beáti mórtui qui in Dómino moriúntur."), confirmed real for
   3 November 2025 (transferred All Souls). The engine joined it into one prose-like
   string with a literal "R." embedded instead of a real `.versicleResponse`. Fixed by
   detecting the shape from the first non-blank line (`"V."`-prefixed → pair; otherwise
   → the pre-existing single-antiphon behaviour, confirmed unchanged for Easter Sunday's
   own antiphon-formatted `[Versum 2]`, 20 April 2025). New tests:
   `allSoulsCapitulumVersum2IsAGenuineVersicleResponsePair`,
   `easterStillUsesItsOwnAntiphonFormattedCapitulumVersum2`.

2. **All Souls: `assembleMagnificat` had no `getantvers`-style "ind, then 4-ind"
   fallback.** `specials.pl:575-596`'s own `getantvers` tries the *swapped* index
   (`[Ant (4-$ind)]`, office then Commune) before ever falling to the Major Special
   seasonal default, whenever `$ind > 1` (second Vespers only). This project's engine
   had no equivalent attempt at all, going straight from `[Ant $ind]` to
   `[Ant Vespera $ind]` to the Major Special fallback. Confirmed real for 3 November
   2025: neither `Sancti/11-02` nor its own Commune (`C9`, via `ex C9`) defines
   `[Ant 3]` (`ind == 3`), but `Commune/C9` *does* define `[Ant 1]` ("Omne quod dat
   mihi Pater..."), matching the real fixture's own Magnificat antiphon exactly — this
   project's engine fell through everything to a wrong Major-Special default instead.
   New test: `allSoulsMagnificatAntiphonUsesTheSwappedIndexFallback`.

3. **All Souls: a missing occurrence-level Saturday-suppression rule.**
   `horascommon.pl`'s own "Office of All Souls' day ends after None" exclusion removes
   All Souls from sanctoral candidacy entirely when 2 November falls on a Saturday
   (`($version !~ /196/ || $dayofweek == 6) && $month == 11 && $srank =~ /Omnium
   Fidelium defunctorum/i && !$caller`, collapsing to exactly "Saturday, November, this
   title" for this project's 1960-only, non-chained scope). This project's engine kept
   All Souls (and its own Special Conclusio) as the day's winner regardless of the
   date. Confirmed real for 2 November 2030 (a Saturday): the real fixture's own
   Vespers is the ordinary "Dominica XXI Post Pentecosten... Vespera de sequenti" with
   a plain ferial Conclusio ending, not All Souls' own "Conclusio specialis" — this
   was the confirmed cause of the one remaining Conclusio mismatch in the whole sweep.
   New tests: `allSoulsIsSuppressedWhenNovemberSecondIsASaturday`,
   `allSoulsStillWinsItsOwnDayOnAnOrdinaryWeekday`.

Full suite (203 Kit + 8 Data + 94 named oracle, six new across the three fixes)
confirmed clean.

**Also found during the same investigation, not yet fixed**: an off-by-one bug in the
O-Antiphon date mapping — 20 December 2025 renders 21 December's own O-Antiphon ("O
Óriens...") instead of 20 December's own ("O clavis David..."), confirmed against the
real fixture. Unrelated to All Souls; found opportunistically while checking the
Canticum category broadly. Flagged for the Canticum category pass.

**Epiphany cluster: attempted, regressed again, reverted — with a more precise
diagnosis than the first attempt.** Deep investigation (live Perl instrumentation of
`concurrence()`'s own decision variables, no code changes) confirmed the real mechanism
precisely for 6-7 January 2029 (Epiphany, I. classis rank 6.5, own `[Rule]` tagged
"Festum Domini", vs. Holy Family Sunday, II. classis rank 5, that year's own `[Rule]`
*also* tagged "Festum Domini"): Holy Family wins Epiphany's own second Vespers outright
("nihil de præcedenti"), via `horascommon.pl:1156-1163`'s own second real `elsif`
disjunct — reached, in the real cascade, only once an earlier sibling `if` (call it
Branch 1, `horascommon.pl:965-1003`) is false. Re-traced the previously-regressed date
(12 January 2025) and found the debug print never fires there at all — that date is
resolved entirely within Branch 1, before the target disjunct is ever reached.

This time, the disjunct was ported gated behind `clearsFloor` (`tomorrow.rank >=
threshold`, the project's own existing rank-threshold check) on the theory that this
replicates "Branch 1 is false" closely enough to be safe. **It doesn't.** A fresh full
sweep after landing it showed Conclusio hit 0 (confirming the All Souls Saturday fix)
and Canticum/Versus improved (51→35, 27→18, from the All Souls fixes), but Oratio
(52→58), Psalmodia (23→29), Capitulum (13→20), and Hymnus (9→16) all got *worse* — new
mismatches on dates with nothing to do with Epiphany or Holy Family at all (e.g. 1 July
2028). Root cause of *this* over-firing, now understood precisely: `clearsFloor` only
replicates Branch 1's own rank-threshold sub-condition — one of *seven* total disjuncts
in Branch 1's own `||` chain (the other six: 1955-specific, Barroux-specific, a
Feria/Sabbato/Vigilia/Quatuor title exclusion, an infra-octavam/Vigilia-Pentecost
exclusion, a Paschal/Pentecost-octave-week exclusion, and a `01-01`/Nat1-adjacent
exclusion). `clearsFloor` failing is *sufficient* to know Branch 1 is false (matching
the 12 January 2025 case correctly), but `clearsFloor` passing does *not* mean Branch 1
is false — any of the other six disjuncts can independently make Branch 1 true (meaning
today keeps its own second Vespers) even when the rank threshold alone would have let
tomorrow through. The target disjunct was being evaluated on dates the real cascade
would never even let it reach.

Reverted cleanly (`git checkout --` on `Concurrence.swift`, deleted the new test file,
confirmed with a clean build). **This is now a well-scoped problem for a future
attempt**: porting the target disjunct safely needs Branch 1's *other* six exclusions
gated too, not just the rank threshold — or, more surgically, a narrower condition
confirmed to only ever match the genuine Epiphany/Holy-Family-shaped case without
needing the full Branch 1 replication. Not attempted again this session; the Epiphany
octave's own remaining mismatches (Hymnus/Capitulum/Versus, `Jan 6`-shaped) are picked
up again in the category passes below, on their own terms, without this mechanism.

**Accurate post-revert baseline**, a fresh full sweep run after the Epiphany attempt was
cleanly reverted (confirming the three All Souls fixes' own full effect, not muddied by
the reverted change): Oratio 51, Canticum 28, Psalmodia 22, Capitulum 13, Versus 11,
Hymnus 9, Conclusio 0. The All Souls fixes alone brought Canticum 51→28 and Versus
27→11 in addition to closing Conclusio entirely (15→0 across the whole session) — larger
wins than their own category names suggested going in. Phase 2 (category-by-category,
least mismatches to most) starts from this baseline, worked in the *current* true order:
Conclusio (done) → Hymnus → Versus → Capitulum → Psalmodia → Canticum → Oratio.

**Hymnus category pass.** Got the full per-category mismatch date list (a temporary,
uncommitted tweak to `OracleTests.swift`'s own `report()` — printing the whole sorted
`Set<String>` instead of five capped examples — run once, reverted immediately after)
and traced all 9 remaining Hymnus dates. Two distinct, both concurrence-level, both
deferred rather than risked a third regression this session:

- **8 of 9** (`2029-01-06`, `2030-01-12`, `2030-01-13`, `2032-01-04`, `2035-01-06`,
  `2036-01-02`, `2036-01-12`, `2036-01-13`) are the *same* already-deferred
  Epiphany/Holy-Family concurrence cluster — including a variant not previously
  traced: when Epiphany itself falls on a *Sunday* (2030, 2036), Holy Family gets
  pushed to the *following* Sunday instead, and still pre-empts the intervening
  Saturday's own Vespers completely ("nihil de præcedenti") — same real mechanism,
  same real disjunct, just triggered by a different day-of-week alignment. Confirmed
  real for 12 January 2030 (a Saturday): the real fixture's title is already "Sanctæ
  Familiæ..." with "Vespera de sequenti; nihil de præcedenti", Holy Family's own hymn.
- **1 of 9** (`2038-07-01`) is a *different* concurrence-level gap: the real fixture
  shows the Feast of the Sacred Heart (movable, Friday after the Corpus Christi
  octave) pre-empting 1 July's own Vespers (the fixed Feast of the Most Precious
  Blood) completely. `horascommon.pl` has a specific named real disjunct for the
  adjacent commemoration question ("no commemoration of Precious Blood on the Feast
  of the Sacred Heart: Github #4586", `$winner =~ /Pent02-5/ && $cwinner =~
  /07-01\./`), but the pre-emption itself (which office wins Vespers outright) is a
  separate question this project's `Concurrence.swift` doesn't yet handle correctly
  for this date either — not investigated further tonight, flagged alongside the
  Epiphany cluster as a second, distinct concurrence gap needing its own careful,
  well-scoped attempt later.

No further Hymnus-specific work is safely available without touching `Concurrence.swift`
again — deferred, not fixed, for this pass.

**Psalmodia category pass**, one real fix: `assemblePsalmodia`'s own antiphon lookup
used the plain `communeFallbackPath`, never switched over to `paschalCommuneFallbackPath`
the way every sibling lookup in this file (Capitulum/Hymnus/Versus/Oratio/
Magnificat-antiphon) already had been. `extract_common()`'s own Paschaltide branch
(`horascommon.pl:1501-1509`) swaps in a Commune's own `"p"`-suffixed variant during
Paschaltide when one exists — this one lookup never made that swap, so any Paschaltide
office whose plain Commune has no `[Ant Vespera]` of its own (common: the ordinary
antiphons live only on the Paschal variant's own base chain) silently fell through to a
wrong default. Confirmed real for 25 April 2026 (S. Marci Evangelistæ, II. classis, `"ex
C1a"`): `Commune/C1a.txt` has no `[Ant Vespera]` at all; the real antiphons come from
`Commune/C1p.txt`, reached only via the Paschal variant `Commune/C1ap.txt`'s own
`@Commune/C1p` base inclusion — this project's engine reached plain `Commune/C1a`
directly, found nothing, and fell through to a wrong default (a psalm-verse-shaped
fragment with a stray "allelúia" appended, not a real antiphon at all). New test:
`paschaltideEvangelistUsesTheCommunesOwnPaschalAntiphons`. This pattern recurs almost
every year in the sweep range (any 25 April within Paschaltide), so it's likely the
single largest remaining contributor to Psalmodia's own count. Full suite (203 Kit + 8
Data + 95 named oracle) confirmed clean.

Confirmed on a fresh sweep: Psalmodia 22→11, exactly as predicted — the Paschal-Commune
fix alone closed half its remaining count. Capitulum/Versus/Hymnus unchanged (13/11/9,
as expected — none of them share this specific antiphon-lookup path).

**Capitulum category pass**, two real fixes, found together on the same date:

1. **`horascommon.pl:314-315`'s own named, narrow special case: "ensure the Dominica IV
   adventus win in case it has a '1st Vespers' on Dec 23."** Inside `occurrence()`'s own
   `$tomorrow` branch, when today is 23 December, tomorrow's own sanctoral candidate
   (Christmas Eve's Vigil, `Sancti/12-24s`, rank 6.9) is zeroed out entirely (`$srank =
   ''`), forcing tomorrow's occurrence to resolve to its temporal winner instead. This
   only matters in the rare years the 4th Sunday of Advent coincides with Christmas Eve
   itself — otherwise the Vigil naturally wins occurrence anyway. Ported as a narrow,
   `day == 23 && month == 12`-gated guard in `Concurrence.resolve`, re-deriving
   tomorrow's occurrence from its temporal path alone whenever its ordinary winner would
   be sanctoral. Confirmed real for 23-24 December 2028: the real fixture's own title is
   "Dominica IV Adventus ~ I. classis" ("Vespera de sequenti"), with Capitulum "1 Cor
   4:1-2 ... Sic nos exístimet homo..." — not the Vigil's own "Gen 49:10 Non auferétur
   sceptrum de Iuda..." this project's engine had been rendering instead, having let the
   Vigil win occurrence outright. New tests:
   `adventFourWinsChristmasEveWhenItFallsOnTheFourthSunday`,
   `ordinaryChristmasEveStillWinsItsOwnFirstVespersMostYears`
   (`AdventFourthSundayOnChristmasEveOracleTests.swift`). Scoped tightly enough (one
   specific trigger date per year) that it can't affect any other date's own occurrence,
   including a direct query of 24 December itself as "today."

2. **A second, previously-unexercised bug this first fix surfaced: `oAntiphonLocation`'s
   own O-Antiphon date was pointed at the wrong day for first Vespers.** Real Perl
   instrumentation (reading `horas.pl:476`'s `ant123_special` directly) confirmed
   `$day`/`$month` there are the same package-global, never-reassigned values the whole
   request was invoked with — Divinum Officium never advances them to "tomorrow" when
   first Vespers of the next day wins occurrence (only `$vespera` flips to 1). This
   project's `oAntiphonLocation` had been advancing the effective date by one whenever
   `isFirstVespers`, on an earlier, unconfirmed guess that DO keyed off the *winning
   office's* own nominal date — a guess never actually exercised by any prior fixture,
   since the only realistic year `isFirstVespers` and the 17–23 December O-Antiphon
   window coincide at all is exactly this same rare Advent-IV-on-the-24th case (in an
   ordinary year, the evening's `$winner` is the Christmas Vigil, `Sancti/12-24s`,
   already failing `$winner =~ /tempora/i`). Fixed by dropping the `addDays(1, ...)`
   entirely: the function now always uses the requested `day`/`month` directly, since the
   O Antiphon custom is tied to the calendar date of the *evening being prayed* (the
   23rd), not the following day's own date (the 24th, which fails the `< 24` guard
   outright). Confirmed real for the same 23-24 December 2028 fixture: the real
   Magnificat antiphon is the 23rd's own "O Emmánuel, * Rex et légifer noster...", not
   the wrong Major-Special Saturday fallback ("Suscépit Deus Israël...") the engine had
   fallen through several tiers to reach. This fix turned out to be the *general* fix for
   the whole O-Antiphon cluster, not just this one date — it also resolved the
   previously-flagged Canticum off-by-one bug (20 December 2025 rendering 21 December's
   antiphon) as a side effect, since both bugs shared the same wrong-date root cause via
   different call paths. Test assertions added to the same two tests above.

Full suite (203 Kit + 8 Data + 97 named oracle) confirmed clean after both fixes. Fresh
sweep, measuring both fixes together against the prior baseline (Oratio 51, Canticum 28,
Psalmodia 11, Capitulum 13, Versus 11, Hymnus 9, Conclusio 0):

Oratio 49, Canticum 12, Psalmodia 9, Capitulum 11, Versus 11, Hymnus 9, Conclusio 0.

Every category held steady or improved, none regressed — Canticum's drop (28→12) is
larger than either fix's own category name would suggest, confirming the O-Antiphon
fix's general reach across the cluster. Capitulum's own remaining 11 dates include `2033-12-29`/`2039-12-29`, confirmed (real
fixtures checked directly) to be a *third*, distinct concurrence gap, not the Dec-23
pattern: both real fixtures read "Dominica Infra Octavam Nativitatis ~ II. classis
Vespera de sequenti" — the floating Sunday within the Christmas Octave pre-empting 29
December's own Vespers outright. Not traced further this session (no Docker-based Perl
instrumentation done yet); flagged alongside the Epiphany/Holy-Family cluster and the
Sacred-Heart/Precious-Blood gap as a third named, well-scoped concurrence problem for a
future attempt, rather than risked a fourth `Concurrence.swift` change without first
understanding its own real mechanism. Capitulum's remaining count otherwise matches the
already-known Epiphany/Holy-Family cluster dates (`2029-01-06`, `2030-01-12`,
`2030-01-13`, `2032-01-04`), deferred with Hymnus above.

**Versus category pass**, one real fix, found by tracing two of the 11 remaining dates
(`2032-01-04`, `2036-01-02`) that weren't part of any already-known cluster: both real
fixtures read "Sanctissimi Nominis Jesu ~ II. classis" (the Feast of the Holy Name of
Jesus, kept on the Sunday between 1 January and Epiphany) — not a concurrence question at
all (no "Vespera de sequenti"), so lower-risk than another `Concurrence.swift` change.

The real mechanism is `Directorium.pm`'s own `load_transfers` (lines 141-162) plus
`load_transfer_file` (lines 55-73): under 1960 rubrics, Holy Name has no fixed Sancti
file of its own any more (`Sancti/01-02` is actually "In Octava S. Stephani"); instead a
`Tabulae/Transfer/<letter>.txt` entry like `Transfer/d.txt`'s own
`"01-04=Tempora/Nat2-0"` redirects whichever January date is the right Sunday that year
onto the week-numbered temporal file, which itself carries Holy Name's proper texts. This
project's `SanctoralCalendar.transferSource` already had this whole mechanism (confirmed
working for `01-05` in an ordinary year), but **in leap years it was silently wrong**:
`load_transfers` always loads its primary letter file through `load_transfer_file`'s own
`$filter` parameter set to `$isleap` — `1` means "Feb 24 - Dec", silently dropping every
January/early-February line from that file in a leap year — and only then, inside its own
`if ($isleap)` branch, loads a *second* letter file (`$letters[$letter - 6]`; Perl's
negative array index wraps from the end, so really `$letters[$letter + 1]` mod 7) filtered
to `2`, "Jan + Feb 23" only, supplying exactly the entries the primary file just dropped.
This project's `transferSource` never consulted that second file at all. Confirmed real
for 4 January 2032 and 2 January 2036 (both leap years): the primary letter computed for
both is `"c"`, but `Transfer/c.txt`'s own January entries don't apply in a leap year
regardless, and `Transfer/d.txt`'s `"01-04=Tempora/Nat2-0"` (reached only via the second
file) is what actually governs.

**A first attempt at this fix regressed on the very next full sweep.** It loaded the
extra letter file's entries unconditionally for *every* key in a leap year, not just
January/Feb-23 ones — new mismatches immediately appeared on 30 October 2028 (Christ the
King) and 30 December 2028 (Holy Family), both wrongly picking up the *other* letter
file's own October/December entries instead of the correct primary file's. Caught before
committing (the sweep is always run before trusting a fix); root cause found by reading
`load_transfer_file` itself, which showed the `$filter` parameter — not a blind letter
swap — is what actually keeps the two files' January/Feb-23 and Feb-24/December halves
mutually exclusive. Fixed properly by mirroring that same regex-driven split
(`isJanuaryOrEarlyFebruaryTransferKey`), so the extra file is only ever consulted for a
January/Feb-1-23 target key, and the primary file is skipped for exactly those same keys
in a leap year — never touching either file's other half. New tests:
`holyNameOfJesusWinsOnTheSundayInALeapYear`, `holyNameOfJesusWinsOnTheSundayInASecondLeapYear`
(`HolyNameJesusLeapYearTransferOracleTests.swift`).

Full suite (203 Kit + 8 Data + 99 named oracle) confirmed clean after the corrected fix.
Fresh sweep against the prior baseline (Oratio 49, Canticum 12, Psalmodia 9, Capitulum 11,
Versus 11, Hymnus 9, Conclusio 0):

Oratio 47, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7, Conclusio 0.

Every category improved, none regressed — critically, 30 October 2028, 30 December 2028,
and 2032-10-24 do **not** reappear, confirming the corrected, date-range-scoped fix. The
remaining Versus/Capitulum/Hymnus/Psalmodia/Canticum counts are now fully accounted for by
the three already-deferred concurrence clusters (Epiphany/Holy-Family, Sacred-Heart/
Precious-Blood, Dec-29 Christmas-Octave-Sunday) — no further category-specific work is
safely available without attempting one of those three, each already flagged for a future,
carefully-scoped session rather than risked here.

**Canticum category pass**, no new fix: got the full per-category mismatch date list
(the same temporary, uncommitted `OracleTests.swift` tweak used for prior passes, run
once, reverted immediately after) and confirmed all 9 remaining dates are exactly the
union of the three already-deferred clusters, with no new pattern among them —
`2029-01-06`/`2030-01-12`/`2030-01-13`/`2035-01-06`/`2036-01-12`/`2036-01-13` (Epiphany/
Holy-Family), `2038-07-01` (Sacred-Heart/Precious-Blood), `2033-12-29`/`2039-12-29`
(Dec-29 Christmas-Octave-Sunday). Nothing to fix here without attempting one of those
three concurrence gaps directly.

**Oratio category pass**, the largest and most varied remaining category (47 dates,
spanning many distinct real liturgical days — Annunciation, St Joseph, Circumcision/Holy
Name, the Nativity Octave Sunday, St John Baptist's Nativity, assorted Lenten ferias —
not explainable by the three deferred concurrence clusters alone). First fix, the largest
single sub-pattern (7 of the 47 dates): a Passiontide commemoration's own versicle always
fell through to the week-agnostic generic Lenten one.

`orationes.pl`'s own `getcommemoratio` (traced via live Perl instrumentation this
session, after an earlier session's attempt at the same function hit a dead end) ends its
own Versum fallback chain with `getfrompsalterium('Versum', $ind, $lang)`
(`specials.pl:639-652`), which builds its lookup key as `gettempora('getfrompsalterium
major') . " Versum $ind"` — confirmed by instrumenting `getfrompsalterium` itself (`GFP
name=[Quad5 Versum] ... GFP return=[Éripe me, Dómine, ab hómine malo...]` for 24 March
2026) to return the *full* week name (`"Quad5"`, not the digit-stripped `"Quad"`) when a
week has its own override. `Major Special.txt`'s own `[Quad5 Versum 3]` section exists,
but its body is itself just a same-file cross-reference (`@:Quad5 Versum 3_`) to the
underscore-suffixed section that actually holds the text — DO's own convention for giving
two section headers non-colliding names within one file, not a special lookup key on its
own; `SectionResolver` already follows it like any other `@`-inclusion once the plain
header `[Quad5 Versum 3]` is found. This project's `HourAssembler.seasonalVersumLocation`
had always stripped the week number outright (`"Quad5"` → `"Quad"`) before ever looking
anything up, so it never even *tried* a week-specific override on any week — not just the
ones (`Quad1`, confirmed against 24 February 2026) that genuinely lack one. Fixed by
trying the full week name first, falling back to the digit-stripped generic prefix only
when no week-specific override exists. Confirmed real for 24 March 2026 (a Tuesday within
Passion week, commemorated at the Annunciation's own pre-empting first Vespers): real
versicle "Éripe me, Dómine, ab hómine malo. / A viro iníquo éripe me.", not the generic
"Ángelis suis Deus mandávit de te." this project's engine had been rendering. New tests:
`passionWeekCommemorationUsesItsOwnMoreSpecificVersum`,
`ordinaryLentenWeekCommemorationStillUsesTheGenericVersum`
(`PassionWeekCommemorationVersumOracleTests.swift`).

Full suite (203 Kit + 8 Data + 101 named oracle) confirmed clean. Fresh sweep against the
prior baseline (Oratio 47, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7,
Conclusio 0): **Oratio 47 → 37**, every other category unchanged — a bigger drop than the
7 directly-traced dates alone would suggest, meaning several of those dates had more than
one mismatched line each (the versicle and its response counted separately). Oratio's own
remaining 37 dates are still under investigation — distinct sub-patterns spotted so far
include Annunciation-adjacent Ave Maria versicles, Nativity-octave/Circumcision
commemoration collects, and St Joseph/St John Baptist collects, each needing its own
real-Perl trace before any fix is attempted, following the same discipline as this one.

**Second Oratio fix, in `Commemorations.swift`** (concurrence-adjacent, so treated with
the same caution as a `Concurrence.swift` change — full sweep run before trusting it):
a duplicate-commemoration bug affecting the St Joseph/Annunciation "Ecce fidelis
servus"-shaped dates. Traced with tagged diagnostics directly in `Commemorations.resolve`
(temporary `print` statements, reverted before committing) after live Perl
instrumentation of `getcommemoratio` confirmed real DO calls it *exactly once* per night
(`GC wday=[Sancti/03-19.txt] ind=[1]`) for 19 March 2028, while this project's engine
built *two* candidates for the same office.

The real mechanism: when a high-rank office (St Joseph, `Duplex I classis`) loses
same-day occurrence to a Sunday/Festum-Domini on its own natural date, it's annually
transferred by `SanctoralCalendar`'s own transfer table (the same mechanism that moves a
displaced Annunciation onto a later free day) onto the very next free day. This project's
`Commemorations.resolve` found the office through *two independent mechanisms at once*:
`runnersUp` found it as an ordinary same-day loser on its own natural date (`ind: 3`,
reaching the office's own separate `[Ant 3]`/`[Versum 3]`, "Ecce fidélis servus..."/"Glória
et divítiæ..."), while `tomorrowsTiedFirstVespersCandidate` *separately* found it again as
tomorrow's own occurrence winner once transferred (`ind: 1`, reaching the correct `[Ant
1]`/`[Versum 1]`, "Exsúrgens Ioseph a somno..."/"Constítuit eum dóminum domus suæ...").
Both mechanisms are individually correct for the cases they were built for — the bug is
only that they can name the *same* office at once when a transfer is in effect, and
nothing previously deduplicated between them. Fixed by removing any existing same-day
entry sharing the transferred candidate's own path before appending it, so the correct
`ind: 1` entry always wins over the stale `ind: 3` one rather than both rendering.
Confirmed real for 19 March 2028 (St Joseph, transferred to 20 March that year, its own
Vespers commemorated once, correctly). New test:
`transferredStJosephCommemoratesOnceNotTwice`
(`TransferredCommemorationDuplicateOracleTests.swift`).

Full suite (203 Kit + 8 Data + 102 named oracle) confirmed clean. Fresh sweep against the
prior baseline (Oratio 37, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7,
Conclusio 0): **Oratio 37 → 34**, every other category unchanged — no regressions, despite
touching concurrence-adjacent code. Oratio's remaining 34 dates still include the
Annunciation Ave Maria versicle pattern, the Nativity-octave/Circumcision commemoration
collects (mostly downstream of the three already-deferred concurrence clusters), and St
John Baptist's own Nativity collect — each still needing its own real-Perl trace before
any further fix is attempted.

**Third Oratio fix**: the Annunciation Ave Maria versicle pattern (6 of the 34 remaining
dates) turned out to have the *same* underlying content as the real fixture — the
mismatch was purely a formatting difference. `horas.pl:675,687-690`'s own
`postprocess_ant`/`postprocess_vr` run the real Perl's seasonal-Alleluia handling
(`applyingSeasonalAlleluia`'s own real counterpart) over *every* displayed antiphon and
versicle/response in the whole office — this project already applied it to the main
Psalmodia/Magnificat units, but `commemorationUnits` never ran it over a commemoration's
own antiphon or versicle/response at all. Some proper antiphons (the Annunciation's own
"Missus est... (Allelúia.)" family) carry a parenthesized Alleluia annotation whose
visibility depends on the season; outside Paschaltide the parens (and the word) should be
stripped entirely, and *inside* Paschaltide the word is kept but the parens dropped —
this project's engine had been showing the raw, still-parenthesized text unconditionally,
since nothing ran it through this processing at all. Confirmed real for 4 April 2027 (Low
Sunday, within the Easter Octave, commemorating the Annunciation transferred there that
year): the real fixture's antiphon/versicle/response read "...obumbrábit tibi. Allelúia."
/ "Ave, María, grátia plena. Allelúia." / "Dóminus tecum. Allelúia." — unbracketed, not
"...(Allelúia.)". New test: `paschaltideCommemorationAlleluiaIsUnbracketed`
(`CommemorationSeasonalAlleluiaOracleTests.swift`).

Full suite (203 Kit + 8 Data + 103 named oracle) confirmed clean. Fresh sweep against the
prior baseline (Oratio 34, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7,
Conclusio 0): **Oratio 34 → 27**, every other category unchanged. Oratio's remaining 27
dates are now almost entirely the Nativity-octave/Circumcision commemoration collects
(downstream of the three already-deferred concurrence clusters) and St John Baptist's own
Nativity collect (`2033-06-24`) — no further clean, independent sub-pattern was found
worth a fourth fix this session; the category pass stops here for now, with the
remaining count well-explained rather than mysterious.

**Phase 3 (later session, 2026-09-24): exhaustive bug hunt.** The user asked for a
precise scope count rather than the working estimate above. A fresh full recount (not
just the top-5-per-category examples the sweep normally prints) found the earlier "4
bugs" estimate was stale and wrong — the real count was **11 distinct root-cause bugs**
across 27 unique dates, most never previously identified: the three already-named
concurrence clusters (Epiphany/Holy-Family, Dec-29, Sacred-Heart/Precious-Blood), plus
eight newly-found ones (a Nativity-Octave-Sunday-commemorated-at-Christmas pattern, Holy
Name commemorated at Circumcision, Annunciation commemorated on its own 25 March, an
unexplored "Hoc est testimonium" Advent commemoration, the previously-flagged-but-never-
traced "Sabbato infra Hebdomadam II in Quadragesima" pattern, a suspected regression in
the St Joseph transfer fix for 2035 specifically, St Joseph the Worker, and St John
Baptist's Nativity). The user asked to fix all of them, expecting zero bugs remaining.

**Bug 1: transferred-away offices still commemorated on their own natural date.**
Re-diagnosing the suspected 2035 St Joseph regression found it wasn't actually a gap in
the dedup fix at all — it's a different, more fundamental omission. `horascommon.pl:
229-232`'s own `transfered()` check runs immediately after `occurrence()` fetches a
day's own Kalendaria candidate, *before* any rank comparison: `elsif ($sfile &&
transfered($sfile, $year, $version, $dioecesis)) { $sfile = ''; }`. An office that's
itself been transferred to a different date this year is excluded from candidacy on its
own natural date entirely — not merely a rank comparison it might lose, but a complete
disqualification. `Commemorations.runnersUp` only ever checked whether a same-day
candidate *lost* occurrence, never whether it had already been excluded from candidacy
altogether.

Confirmed real for 19 March 2035: Easter falls unusually early that year (25 March),
pushing 19 March into Holy Week itself ("Feria Secunda Hebdomadæ Sanctæ ~ I. classis").
Live Perl instrumentation (patching `horascommon.pl` to print `@commemoentries`/
`@ccommemoentries` at their final assignment points) showed *both* completely empty for
that Vespers — unlike an ordinary transfer year (2028), where St Joseph survives as a
same-day-loser commemoration candidate. The year's own numeric transfer file
(`Transfer/325.txt`) carries `"04-03=03-19"`, confirming St Joseph is transferred to 3
April that year — exactly the entry `transfered()`'s reverse lookup would find. Real
DO's `transfered()` (`Directorium.pm:235-269`) does a *reverse* lookup across the same
year's merged transfer table (the same letter/leap-extra-letter/numeric files
`transferSource` already assembles forward): does this office's own key appear as
anyone's *value* this year? Ported as `SanctoralCalendar.isTransferredAwayThisYear`,
mirroring the same file selection and the same two value-exclusions (`Tempora/`-
referencing values, and values ending in `v` for vigil-only transfers), wired into
`Commemorations.runnersUp` right where the office's rank is first read. New tests:
`transferredAwayOfficeIsNotCommemoratedOnItsOwnDate`,
`stJosephStillCommemoratesInAnOrdinaryTransferYear`
(`TransferredAwayCommemorationExclusionOracleTests.swift`).

**Not yet applied to `Occurrence.resolve`'s own winner selection** — only to
`Commemorations.runnersUp`, since that's the one confirmed broken; St Joseph already
loses occurrence to Holy Week's own rank (7) naturally, so this exclusion was never
needed to produce the right *winner* for this date, only the right *commemoration* list.
Extending it to occurrence itself is deferred until a real fixture is found that actually
needs it.

Full suite (203 Kit + 8 Data + 105 named oracle) confirmed clean. Fresh sweep against the
prior baseline (Oratio 27, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7,
Conclusio 0): **Oratio 27 → 23**, every other category unchanged — a bigger drop (4
dates) than the single confirmed date alone, meaning this same general mechanism also
silently fixed other transferred-office commemoration dates elsewhere in the range.

**Bug 2/6/7: the "No Commemoratio" rule directive was never ported.** `getcommemoratio`'s
own check (`orationes.pl:655-660`): `if ($rule =~ /no\s+(\w+)?\s*commemoratio/i && (!$1
|| $wday =~ /$1/i) && !($hora eq 'Vespera' && $vespera == 3 && $ind == 1)) { return ''; }`
— `$rule` there is the *winning* office's own `[Rule]` text (not the commemorated
office's). Several very high-rank proper offices carry a bare "No Commemoratio"
directive that suppresses any commemoration outright, regardless of how eligible the
candidate would otherwise be — confirmed present verbatim in `Tempora/Pent01-4.txt`
(Corpus Christi), `Sancti/12-25.txt` (Christmas), and `Sancti/01-01.txt` (Circumcision).
This project's engine had no equivalent check at all, so any date where one of these
offices wins and something is nominally commemorated (per the title line DO still
generates even when the body suppresses it) wrongly rendered that commemoration's
content anyway. Ported as `HourAssembler.isCommemorationSuppressedByRule`, filtering
`Commemorations.resolve`'s own output before the "reduce to one" step.

**A first attempt also ported the real exception clause and regressed on the very next
test run.** The exception (`!($hora eq 'Vespera' && $vespera == 3 && $ind == 1)`) was
read as carving out the "equal rank, the preceding takes precedence" tie-break case
(`!isFirstVespers && ind == 1`) — reasonable on paper, since that's the exact shape
`tomorrowsTiedFirstVespersCandidate` already handles correctly elsewhere in this file.
But three of the four real-fixture cases confirmed for this same fix (Corpus Christi/St
John Baptist, Christmas, and Circumcision) *all* reach their own commemoration candidate
via that identical `ind == 1` tie-break path (each commemorated office having itself been
transferred to the very next day — St John Baptist's own Nativity is transferred forward
by `Transfer/425.txt`'s own `"06-25=06-24~06-25"` in 2038, confirmed via the same live
Perl instrumentation technique as Bug 1), and the real fixtures show every one of them
suppressed regardless. Whatever `$vespera` actually tracks in the real Perl evidently
isn't equivalent to this project's own `isFirstVespers`/`ind` pairing the way the first
attempt assumed. Caught immediately by the targeted tests (not even reaching the sweep)
— reverted to the safe, conservative reading: a bare "No Commemoratio" match always
suppresses, no exception, until a real fixture is found that genuinely needs one. New
tests: `corpusChristiSuppressesStJohnBaptistsCommemoration`,
`christmasSuppressesTheNativityOctaveSundayCommemoration`,
`circumcisionSuppressesTheHolyNameCommemoration`,
`stJosephStillCommemoratesInAnOrdinaryTransferYearRegardlessOfThisRule`
(`NoCommemoratioRuleOracleTests.swift`) — the last confirming the suppression doesn't
wrongly catch an ordinary commemoration whose winning office carries no such directive.

Full suite (203 Kit + 8 Data + 109 named oracle) confirmed clean. Fresh sweep against the
prior baseline (Oratio 23, Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7,
Conclusio 0): **Oratio 23 → 14**, every other category unchanged — this one general rule
resolved 9 dates at once (the Corpus Christi/St John Baptist, Christmas, and Circumcision
clusters together), confirming the mechanism generalizes well beyond the three dates it
was directly traced against.

**Running total this session (2026-09-24, Phase 3 exhaustive bug hunt): 3 of 11
originally-identified bugs fixed and pushed (Bug 1 directly resolved Bugs 3 and 5 as a
side effect; Bug 2's fix directly resolved Bugs 6 and 7 too), 8 remaining**: Bug 4
(Sabbato infra Hebdomadam II in Quadragesima / wrong commemoration selected, not yet
traced), Bug 8 ("Hoc est testimonium" Advent commemoration, not yet traced), and the
three original concurrence clusters (Epiphany/Holy-Family, Dec-29 Christmas-Octave-
Sunday, Sacred-Heart/Precious-Blood). Paused here at the user's request to switch models
and continue in a cloud session — every fix so far has been validated against the full
2025-2040 sweep and the full Kit/Data/Oracle suite before committing, with no known
regressions.

**Phase 4 (cloud session, 2026-09-24): the five remaining oracle bugs.** Environment
note first, since the next cloud session will hit the same thing: this container had no
Swift toolchain and `download.swift.org` is blocked by the network policy. What worked:
start `dockerd`, pull `mirror.gcr.io/library/swift:6.1-noble` (Docker Hub itself
returned 429, and the ECR public mirror's CloudFront blob host is blocked), then run
`swift build`/`swift test` inside that container with the repo bind-mounted. The DO
submodule also needed `git submodule update --init`. Baseline re-measured on a clean
`HEAD` worktree before touching anything: Oratio 14, Canticum 9, Psalmodia 7, Capitulum
9, Versus 9, Hymnus 7, Conclusio 0 (unchanged from the Phase 3 total).

**Bug 8 of 11 (the "Hoc est testimonium" Advent commemoration): O Antiphon override for a
commemorated temporal office.** `getcommemoratio` (`specials/orationes.pl:772-785`)
overrides a commemorated office's antiphon *after* the ordinary `Ant $ind` lookup:
`if ($wday =~ /tempora/i) { if ($month == 12 && ($hora eq 'Vespera' && $day >= 17 && $day
<= 23 ...)) { $a = $v{"Adv Ant $day"} } }`. In 2029/2035/2040, 21 December is the Advent
Ember Friday, and `Tempora/Adv3-5.txt` has its own `[Ant 3]` ("Hoc est testimónium..."),
which this project rendered; the real fixtures show "O Óriens splendor lucis ætérnæ...".
Ported by reusing `oAntiphonLocation` (same window, same never-advanced request date) at
the top of `commemorationUnits`' antiphon chain.

Writing the *control* test (21 December 2026, an ordinary Advent feria) surfaced a
second bug the sweep cannot see: the commemoration was silently **dropped**, not wrong.
`Tempora/Adv4-1` has no `[Ant N]` and no `[Oratio]` of its own (its `[Rule]` is just
"Oratio Dominica"), so `commemorationUnits` returned `nil`. The O Antiphon override
supplies the antiphon; the collect needed `getcommemoratio`'s own "Oratio Dominica"
redirect (`orationes.pl:704-711`: `$wday =~ s/\-[0-9]/-0/; $wday =~ s/Epi1\-0/Epi1\-0a/;`,
then that file's `OratioW // Oratio`), ported as
`HourAssembler.commemoratedOratioDominicaLocation`. The real 2026 fixture's commemoration
("Ant. O Óriens... ℣. Roráte, cæli... Orémus. Excita, quǽsumus, Dómine, poténtiam tuam, et
veni: et magna nobis virtúte succúrre...") now matches word for word. **Methodology
note:** `vespersFullRangeContentAudit` only checks that rendered text appears in the
fixture, so an omitted commemoration is invisible to it. A commemoration-count check
against the fixture would close that blind spot. New tests:
`emberFridayCommemorationTakesTheOAntiphon`,
`ordinaryAdventFeriaCommemorationIsRenderedWithItsSundayCollect`
(`CommemorationOAntiphonOracleTests.swift`).

**Bug 4 of 11 (wrong commemoration at a Lenten Sunday's first Vespers).** 19 March 2033
(St Joseph, Saturday) should commemorate St Joseph; 24 February 2035 (St Matthias,
Saturday) should commemorate nothing. This project commemorated the Lenten Saturday on
both. Read from `concurrence()` directly (`horascommon.pl:842-1472`, static reading was
enough; no instrumentation needed). The fix has three pieces:

1. `:937-964` ("if tomorrow is a Sunday, get rid of today's tempora completely"): when
   tomorrow's *temporal* office (`$ctrank[0]`) is titled `(?<!De )Dominica|Trinitatis`
   (not "Dominica Resurrectionis" under 1955/1960) and a saint wins today, today's
   temporal runner-up, which `occurrence()` always `unshift`s to the front of
   `@commemoentries`, is dropped. Ported as `Commemorations.droppingTemporaBeforeSunday`.
   Only the saint-wins branch is ported; the temporal-wins `else` branch clears `$winner`
   and feeds the wider cascade. **Pitfall:** Swift's `Regex` has no lookbehind, and the
   file's `matches` helper treats a pattern that fails to compile as "no match". The
   first build silently did nothing until the `(?<!De )` was spelled out by hand.
2. `:1166-1170`: the "nothing of the preceding office" exclusion before a Sunday or Feast
   of the Lord is rank-gated (`$rank < ($crank >= 6 ? 6 : 5) || $wrank[0] =~ /Dominica/i
   || $winner{Rule} =~ /Festum Domini/i`). This project had excluded the preceding office
   before *any* Sunday. St Joseph (6) before a 6.9 Sunday escapes the gate and is
   commemorated by `:1296`'s `$crank > $rank` branch; St Matthias (5) does not.
3. `:1063-1081` ("two concurrent Tempora"). **Found by the sweep, not by reading:**
   pieces 1 and 2 alone moved Oratio 14 → 30. The 5 target dates were fixed, but every
   Pentecost Vigil and several 29/30 December dates were newly wrong. The old blanket
   exclusion had been masking this branch: when both days' winners are temporal and
   tomorrow wins, today's temporal winner is never `$commemoratio`, and unless `$crank <
   7 && $crank != 6.5 && $crank != 6 && $comrank > 2 && $cwinner{Rule} !~ /no
   commemoratio/i`, `@commemoentries` is emptied too (the title's plain "Vespera de
   sequenti."). Confirmed real for 7 June 2025 and 30 December 2028.

New tests: `firstClassFeastBeforeFirstClassSundayIsCommemorated`,
`secondClassFeastAndLentenSaturdayBeforeSundayAreNotCommemorated`,
`pentecostVigilIsNotCommemoratedAtPentecostsFirstVespers`,
`christmasOctaveDayIsNotCommemoratedAtTheOctaveSundaysFirstVespers`
(`SundayFirstVespersPrecedingOfficeOracleTests.swift`).

Full suite: 322 tests passed (the 6 new named tests included). Fresh sweep with both
fixes, measured against the re-confirmed baseline: **Oratio 14 → 9**, every other category
unchanged (Canticum 9, Psalmodia 7, Capitulum 9, Versus 9, Hymnus 7, Conclusio 0). No new
mismatch date in any category. Fixed dates: 2029-12-21, 2035-12-21, 2040-12-21 (Bug 8)
and 2033-03-19, 2035-02-24 (Bug 4).

**Dec-29 Christmas-Octave-Sunday concurrence (the third deferred cluster).** In 2033 and
2039 Christmas is a Sunday, so no Sunday falls between 26 and 31 December and
"Dominica Infra Octavam Nativitatis" is kept on Friday 30 December (`Transfer/b.txt`/
`g.txt`, `12-30=Tempora/Nat1-0`, which `SanctoralCalendar` already applied). The real
fixtures for 29 December show its first Vespers ("Vespera de sequenti."). The mechanism is
a one-word gap: `concurrence()`'s first-Vespers threshold (`horascommon.pl:974-977`) is
`$cwrank[2] < (($cwrank[0] =~ /Dominica/i || (Festum Domini && $dayofweek == 6)) ? 5 : 6)`,
keyed off tomorrow's **title**, and this project used `tomorrow.isSunday`. The
Friday-kept Sunday (5.4) therefore faced the I. classis threshold of 6. Fixed in
`Concurrence.resolve` and in the duplicate threshold in
`Commemorations.tomorrowsTiedFirstVespersCandidate`. Past the threshold, the ordinary
`crank > rank` check (5.4 > `Nat29`'s 5) does the rest. The real branch taken is `:1063`'s
"two concurrent Tempora", whose commemoration side was ported just above. Sweep against
the post-Bug-4 baseline: **Canticum 9 → 7, Capitulum 9 → 7, Oratio 9 → 7, Versus 9 → 7**,
Hymnus 7 and Psalmodia 7 unchanged, no new mismatch date. Full suite: 328 passed. New
tests: `christmasOctaveSundayKeptOnFridayHasFirstVespers`,
`twentyNinthDecemberKeepsItsOwnVespersWhenTheOctaveSundayIsOnSunday`
(`ChristmasOctaveSundayOnFridayOracleTests.swift`).

**Sacred-Heart/Precious-Blood concurrence, plus 2 of the 6 Epiphany/Holy-Family dates.**
`concurrence()` checks `horascommon.pl:1161-1170` *before* the 1960 tie-break at `:1242`.
Its second disjunct gives tomorrow first Vespers even at equal rank when both days are a
Sunday or a Feast of the Lord: `($cwrank[0] =~ /Dominica/i || $cwinner{Rule} =~ /Festum
Domini/i) && (... || $wrank[0] =~ /Dominica/i || $winner{Rule} =~ /Festum Domini/i)`. On 1
July 2038 the Precious Blood (6) is followed by the Sacred Heart (6), both "Festum
Domini", so the Sacred Heart wins ("Vespera de sequenti; nihil de præcedenti"). This
project had kept the Precious Blood on the tie-break. Ported as
`Concurrence.precedingYieldsToSundayOrFeastOfTheLord`. It is skipped when both days are
temporal (`:1063` decides those first). It is guarded by the three `:1136-1152` "nihil de
sequenti" disjuncts that can still apply once the threshold is cleared: I. classis today
(rank 7 on a Saturday) against a tomorrow below 6; a Feast of the Lord against a II.
classis Sunday outside `Nat1`; and the literal Pent02-5/07-01 case. The same disjunct also
fixed 6 January 2029 and 2035: Epiphany (6.5, Festum Domini) on a Saturday before Holy
Family (5, Festum Domini, threshold 5 on a Saturday). Low Sunday 2027 before the
transferred Annunciation, which has no "Festum Domini", still keeps its own Vespers (control
test). Sweep against the post-Dec-29 baseline: **every content category 7 → 4**, no new
mismatch date. Full suite: 331 passed. New tests: `sacredHeartPreEmptsPreciousBloodAtEqualRank`,
`holyFamilyPreEmptsEpiphanyOnSaturday`,
`lowSundayKeepsItsVespersBeforeTheTransferredAnnunciation`
(`FeastOfTheLordConcurrenceOracleTests.swift`). **Remaining: 4 dates, one pattern**:
2030-01-12/13 and 2036-01-12/13 (Holy Family on Sunday 13 January, where the Baptism of
the Lord is reduced to a Lauds-only commemoration).

**The last four Epiphany/Holy-Family dates: an occurrence gap, not a concurrence one.** In
2030 and 2036, 13 January (the Baptism of the Lord, `Sancti/01-13`, rank 5, "Festum
Domini") is a Sunday, so Holy Family (`Tempora/Epi1-0`, rank 5) falls the same day. The
real fixtures give Holy Family both 13 January and its first Vespers on the 12th, with the
Baptism reduced to a Lauds-only commemoration. `occurrence()`'s 1960 exception, "II. cl.
feasts of the Lord and all I. cl. feasts beat II. cl. Sundays" (`horascommon.pl:487-493`),
sits inside `elsif ($trank[0] =~ /Dominica/i && $dayname[0] !~ /Nat1/i)`. That tests the
temporal office's **title**, and Holy Family's title has no "Dominica", so the Baptism
(5, not > 5) doesn't beat it. This project tested the weekday. It is the same
title-versus-weekday shape as the Dec-29 fix. The two reverted Phase 2 attempts went at
the concurrence cascade (`:1156-1163`); the real gap was upstream, in occurrence. Fixed in
`Occurrence.resolve`. Two *synthetic* unit tests (`sundaySecondClassFeastOfTheLordBeatsSunday`,
`immaculateConceptionBeatsSundayViaRG15EvenAtLowRank`) built their Sunday with an empty
title and no `[Officium]`, which no real Sunday file has. They now carry `Tempora/Epi2-0`'s
real title ("Dominica II post Epiphaniam"), with the assertions unchanged. No oracle
fixture was touched. New tests: `holyFamilyBeatsTheBaptismOnSundayThirteenthJanuary`,
`holyFamilyHasFirstVespersBeforeSundayThirteenthJanuary`
(`HolyFamilyBaptismOccurrenceOracleTests.swift`).

**`vespersFullRangeContentAudit` now passes: 0/0/0/0/0/0/0** across 2025-2040 (it was
4/4/4/4/4/4/0 before this fix). Full suite: 333 passed.

**New audit: `vespersFullRangeCommemorationAudit` (the reverse direction).** The
content audit only checks that rendered text appears in the fixture, so omissions are
invisible to it. The new audit sits beside it in `OracleTests.swift`. For every date
2025-2040 it counts the commemoration blocks each side renders in the Oratio section
(DO's "Top Next Oratio" up to "Top Next Conclusio"; the header forms "Commemoratio: ..."
and "Commemoratio ad Laudes tantum: ..." sit outside it). It also checks that each of our
"Commemoratio ..." titles opens a block in the fixture. **First run: 89 dates wrong**, all
omissions. About 80 were a Sunday commemorated at a feast's Vespers (the feast on the
Sunday, or on the Saturday before). The rest were Ash-Wednesday-week ferias at St Matthias
(2034, 2039), St Paul plus the Sunday on 22 February (2025, 2031), and All Saints at
Christ the King. Fixes, each read from the Perl:

1. **`getfrompsalterium`'s real key** (`specials.pl:639-652` + `gettempora`), replacing
   `seasonalVersumLocation`, now `psalteriumVersumLocation`. The key is the season (Adv;
   Quad5 for both Passion weeks, so Holy Week no longer falls to `Quad`; Quad; Asc; Pasch;
   Pent; 1960's Nat/Epi), else `Dominica`/`Feria` by the request's weekday, tried at
   `$ind`, 1, 3, 2. The missing Dominica/Feria tier left every per-annum Sunday with no
   versicle, so `commemorationUnits` returned `nil`.
2. **The monthday merge for commemorations** (`SetupString.pl:723-780`): the
   Scripture-cycle antiphon overrides the file's own, and the title gains " III.
   Augusti"-style suffixes ("Commemoratio Dominica X Post Pentecosten III. Augusti",
   16 August 2025).
3. Once Sundays rendered, 70 dates flipped the other way (we commemorated, DO didn't):
   every Feast of the Lord kept on a Sunday. **`occurrence()`'s 1960 tempora removal**
   (`horascommon.pl:388-406`) drops the temporal office outright. It applies to a II.
   classis Sunday displaced by a Feast of the Lord of at least II. classis, and to a
   non-privileged, non-Sunday temporal office under a I. classis saint. Ported as
   `Commemorations.isTemporaDiscardedBySanctoral1960`.
4. The last 8 were Saturday Feasts of the Lord before an ordinary Sunday: **branch A,
   "Vespera de præcedenti; nihil de sequenti"** (`:1136-1152`), checked before the
   tie-break. It is now guarded in `tomorrowsTiedFirstVespersCandidate`, with the same
   disjuncts as `Concurrence.precedingYieldsToSundayOrFeastOfTheLord`.

Both audits now pass: **content 0/0/0/0/0/0/0 and commemorations 0 dates**. Full suite:
338 passed. New tests: `saturdayFeastCommemoratesTheFollowingSundayWithThePsalterVersicle`,
`monthdayMergedSundayCommemorationHasItsTitleSuffixAndAntiphon`,
`feastOfTheLordOnSundayDoesNotCommemorateTheSunday`,
`christTheKingCommemoratesAllSaintsNotTheResumedSunday`,
`saturdayFeastOfTheLordHasNothingOfTheFollowingSunday`
(`SundayCommemorationOracleTests.swift`). (Housekeeping: commit `5972ca9` accidentally
included a temporary debug-dump test, `ZZDebugTmp.swift`, removed in the next commit.)
**Still unaudited:** the *main office's* own title with the monthday suffix (the
day-title block), which neither audit compares.

**Hold-out year 2044, priest off and on.** The main fixtures stop at 2040 and cover
the priest form only on ~128 spot-check dates, so every fix above was traced and measured
in-sample. To get an out-of-sample check, 2044 (a leap year, Easter 17 April) was
rendered in full with both priest settings. The DO image couldn't be rebuilt here: CPAN
and deb.debian.org are blocked. `officium.pl`'s CLI path needs only Perl with CGI.pm,
installed from Ubuntu's `libcgi-pm-perl`. `oracle-worker.sh` gained `DO_ROOT`/
`ORACLE_RAW` overrides (container defaults unchanged). Host rendering was first verified
**byte-identical** to the committed container fixtures: all 365 dates of 2026 priest off
and all 128 priest-on spot-check files, 0 differences. New:
`scripts/generate-holdout-fixtures.sh`, `data/oracle-fixtures/holdout/2044.tar.gz` (732
renders, 1.2 MB, deterministic across two runs), `OracleFixture.holdout(year:date:priest:)`,
and `holdout2044VespersMatchesDivinumOfficium(date:priest:)`, a parameterized Swift
Testing test with one case per date and priest setting (732 cases). Each case asserts
the Psalmodia/Canticum/Oratio sections are present, runs the content check (every
rendered piece in the fixture) and the commemoration check (count and titles). A
negative control confirmed the check discriminates: a priest-on render against the
priest-off fixture is flagged ("Dóminus vobíscum." / "Et cum spíritu tuo."), 0 against the
right one. **Result: all 732 cases pass on the first run, with no engine change.**
Full suite: 340 passed.

### M5 — User interface

SwiftUI views to the visual spec: Today/Vespers page (paginated), TOC sheet, date/calendar
picker, Settings, About. No liturgical logic in the app target — everything consumes the
already-assembled `Hour` model. Iterated purely through CI: push → `app-ci.yml` renders
snapshots on the simulator → download the PNG artifacts → compare against
`design/reference/` with concrete measurements (element, measured value, expected value)
→ fix → repeat. Snapshot matrix per `CLAUDE.md`: ferial day, day with commemoration, I
class feast, Holy Week day; each with English off (portrait) and English on
(portrait + landscape); each at default and largest text size; page 1 and one psalmody
page. Final snapshots shown to you before moving on.

**M5 audit and reading modes (2026-09-24).** Audit of the App target against `CLAUDE.md`:

- **Correctness bug, fixed:** `OfficeDataStore` built `SanctoralCalendar` without
  `temporaRedirect`. The phone rendered Vespers differently from the verified engine
  output on 262 dates in 2025-2040. Fixed via `DataBundle.makeSanctoralCalendar()`, now
  used by the app and every test (`appCalendarFactoryCarriesTheTemporaRedirectTable`).
- **Paging (user decision):** book-style flow instead of "one page per section group".
  The text runs line by line onto the next page at any text size. Settings choose
  horizontal pages (default) or vertical scroll, and a slide or page-curl turn. This is
  the approved UIKit exception (`CLAUDE.md` now records it). `OfficeTypesetter` typesets
  the whole hour once into one attributed string. It carries over every style the old
  SwiftUI `UnitView` had settled on, and the page-1 header's date line and TOC icon become
  in-text links. `VerticalOfficeReader` is one TextKit-1 `UITextView`;
  `PagedOfficeReader`/`OfficePager` flow the same text through page-sized
  `NSTextContainer`s in a `UIPageViewController` (`.scroll` or `.pageCurl`). Changing text
  size or orientation re-paginates and keeps the reading position; changing date starts
  at page 1. `UnitView` and `HangingIndentText` are removed (the hanging indent is now a
  paragraph style). The footer's "Page N of M" is real, and its short date is a
  jump-to-date button.
- **English (user decision):** stays deferred to beta; `CLAUDE.md` updated.
- **UI tests:** updated for text-view rendering. New `testHorizontalPagesFlowAndCountUp`
  (counter advances on swipe; more pages at XXL), `testReadingModesSnapshots`,
  `testFooterDateOpensJumpToDateSheet`, and `testPageOneDateLineLinkOpensJumpToDate`,
  which skips if UIKit doesn't expose text-view links to accessibility.
- **Blocked here:** snapshot PNGs can't be downloaded into this cloud container
  (`*.blob.core.windows.net` is denied by the network policy), so visual comparison
  against `design/reference/` needs that host allowed, or the user reviewing the CI
  `snapshots` artifact.
- **Not yet verified:** Hoefler Text against the reference, and the date-line size.
  Also, `CLAUDE.md` names `design/reference/universalis-compline-night.png`, but the
  file on disk is `Format.png` (plus `Calendar.png` and `Hours Picker.png`).

**First snapshot comparison of the new renderer (App CI run on `2ef9957`, all UI tests
green on the first compile).** Measured in points at @3x, `design/reference/Format.png`
against our 16 September 2026 page 1. These already match: body (cap to descender 18.0
against 18.3, line pitch 23, margin 28 against 27.3), response and half-verse indent
(23), hanging indent (36.7 against 37.7), rule (82.7 against 83.3 wide) and the gap from
rule to heading (45 against 44.3). Hoefler Text at 19pt is confirmed: "Glória Patri et
Fílio*" is about 164pt wide in both. Fixed from the measurements:
- the last line to the next rule, 53.4 → 37: a separate `separatorSpacingAbove` of 28pt;
- the heading to the first line, 21 → 26.7: 0.9× body below the heading;
- the table-of-contents icon to the hour title, 21 → 12.

The screenshot's title sizes are smaller than `CLAUDE.md`'s ratios (name ≈1.0× against
1.3×, hour title ≈1.2× against 1.5×, headings ≈1.0× against 1.1×, date line ≈18.5pt against
24.7pt). The user chose to keep the ratios, and `CLAUDE.md` records it. Two further bugs:
- vertical mode showed "Page 1 of 1", because the count was taken before layout. The text
  view now reports it after its own layout pass;
- one snapshot came out at XXL, inherited from an earlier test's Settings choice. UI tests
  now pin the text size at launch.

**M5 closed (2026-09-24).** App CI is green on `d763107`. The re-measured snapshots match
`Format.png`: last line to rule 37.3 (reference 37.0), heading to first line 26.3 (26.7),
TOC icon to hour title 12.0 (12.0). Vertical mode reports real page counts. The user
approved the milestone. What remains for M6 is on the user's side: run Build IPA, fetch
it with `get-ipa.ps1`, sideload it, and run the checklist in `install-on-iphone.md`. The
alpha retrospective is in [`alpha-retrospective.md`](alpha-retrospective.md).

**Next: the betas (2026-09-24).** Beta 1: the Vulgate psalter as the default (Bea kept as
an option) and English. Beta 2: all the day hours. Beta 3: the Ambrosian and Dominican
rites. Beta 4: Matins. Beta 1's plan is [`Beta_1_plan.md`](Beta_1_plan.md), and its work
log continues in a "Beta 1" section at the end of this file.

### M6 — Sideload release

Ship the real alpha via the pipeline proven in M0: `build-ipa.yml` produces the unsigned
`.ipa`, `scripts/get-ipa.ps1` fetches it, the sideloading tool signs and installs it with
the free Apple ID. Short manual verification checklist for you (date line for today,
paging, TOC navigation, priest toggle, rubrics toggle, English toggle, largest text size,
previous/next day, jump-to-date). `build-ipa.yml` stays a one-click re-run whenever a
fresh build is needed, independent of the 7-day re-sign routine (which is purely a
Windows-side/on-device action against a `.ipa` you already have — see
`docs/install-on-iphone.md`).

---

## Testing strategy detail

### Oracle fixtures

- **Generation** happens locally against the Dockerised DO instance from M0, driven by
  `scripts/generate-oracle-fixtures.*`, reading DO's own `web/cgi-bin/horas/officium.pl` /
  `horas.pl` invocation pattern (not guessed URL parameters) to call it directly rather
  than over HTTP where possible, for speed.
- **Coverage (confirmed, reduced from the original brief):** the primary sweep is
  **2025-01-01–2040-12-31 (5,844 dates), Latin only, priest off** — one rendered Vespers
  page per date, 5,844 renders. On top of that, a **~100-date spot check** (spread across
  the range, weighted toward the named edge cases and a mix of ferias/feasts/Sundays) is
  run with the other three option combinations (priest on/Latin, priest off/English,
  priest on/English) specifically to catch inconsistencies in how the priest toggle and
  the English text track the Latin — roughly 300 more renders. ~6,150 renders total
  instead of 23,376, which meaningfully cuts the one-off generation time while still
  exercising every option combination. Runs in parallel workers against the local Docker
  container; only needs to be re-run when the DO pin moves or the covered range/spot-check
  set changes, not on every CI run.
- **Storage:** normalised (HTML stripped, whitespace collapsed, same J→I rule applied),
  compressed, and committed under `data/oracle-fixtures/` — a few MB after compression at
  this reduced scope; split by year to keep individual files and diffs manageable.
- **Comparison:** `Tests/OracleTests` reads the committed fixtures directly — no Docker,
  no network, at test time — so it runs cheaply and offline as part of `kit-ci.yml` on
  every push, honouring the "no network calls" rule for anything except the one-off
  fixture-generation script itself (which `CLAUDE.md` explicitly allows: "Build and CI
  tooling may use whatever is convenient").

### CI minute budget

| Job | Runner | When | Approx. cost driver |
|---|---|---|---|
| `kit-ci.yml` | ubuntu-latest (1×) | every push/PR | `swift build/test`, incl. oracle diff — cheap |
| `app-ci.yml` | macos-26 (10×) | every push/PR touching `App/` or `Packages/` | Xcode build + simulator boot + snapshot tests |
| `build-ipa.yml` | macos-26 (10×) | manual (workflow_dispatch) | unsigned device build + zip — no signing/upload step, so it's cheaper than the old TestFlight archive+upload was |

Given macOS runner minutes cost 10× Linux minutes on GitHub's free/included quota, Kit
tests run **only** on Linux (per `CLAUDE.md`'s own instruction), and `app-ci.yml` is
scoped with a path filter so pure-Kit changes never trigger a macOS run.

---

## Risks

- **DO's 1960 implementation, hardest parts to port:** the precedence/occurrence/
  concurrence rules (which commemorations survive, and in what order, when two offices
  compete); first-vs-second-Vespers determination; Passiontide/Advent-specific
  commemoration suppression; Ember days and Our Lady on Saturday fallbacks; the
  macro/conditional mini-language itself (`$`/`&` macros, nested version conditionals).
  M1's close reading is deliberately sequenced before any engine code specifically to
  surface these before they're guessed at.
- **Oracle fixture generation time/size.** Reduced scope (Latin/priest-off full sweep +
  ~100-date spot check for the other option combinations, ~6,150 renders total) plus
  running it as an infrequent local batch job (not CI-gated), compressing/splitting the
  committed fixtures; if DO's CGI turns out too slow per-call even in parallel, invoking
  its Perl entry points directly in-process (bypassing HTTP) is the fallback, to be
  confirmed during M1.
- **No-Mac debugging, and now no TestFlight diagnostics either.** No breakpoints, no
  Instruments, no on-device console — and, since there's no App Store Connect without the
  paid program, none of the automatic crash-report collection TestFlight builds get
  either. If a defect can't be diagnosed from CI logs and snapshot PNGs alone, on-device
  crash logs would need to be pulled manually (Settings → Privacy & Security → Analytics &
  Improvements → Analytics Data, on the iPhone itself, since there's no Mac to sync them
  via Xcode's device console) or reproduced by adding more logging and re-sideloading. If
  that's still not enough, the fallback is a short paid rental of a cloud Mac for a
  focused session.
- **Free-tier sideloading limits.** A free Apple ID caps sideloaded apps at 3 concurrent
  and roughly 10 new App IDs per rolling week (see `docs/install-on-iphone.md`, sourced
  from the sideloading tools' own docs). The fixed bundle identifier keeps every Breviarium
  re-sign from consuming a new App ID, so this should never bind in practice — but it's
  worth remembering if the sideloading tool itself, or any other personal sideloaded app,
  is also competing for the same weekly quota.
- **7-day re-sign is a standing chore, not a one-time step.** Unlike TestFlight's 90-day
  window, a free-tier signature expires in 7 days and there is no server-side push to
  remind you. `docs/install-on-iphone.md`'s routine (and, if wireless refresh is set up,
  the sideloading tool's own background refresh) is the mitigation; missing a week just
  means the app stops opening until it's re-signed — no data loss (see that doc).
- **Xcode/SDK version drift.** GitHub's `macos-26` image (GA) currently ships Xcode
  26.0.1–26.6 with the iOS 26.5 SDK preinstalled, confirmed current as of this plan — `M0`
  should pin an explicit Xcode version in `app-ci.yml`/`build-ipa.yml` rather than trust a
  rolling default, and revisit if GitHub deprecates the image.

---

## Decisions

These were open questions in an earlier draft; all are now resolved and folded into the
plan above.

1. **Today view** opens on the last hour consulted, with the date always refreshed to
   today; only `.vesperae` is reachable in the alpha, but the mechanism is built
   generically. (§ Note on the design references, § M5)
2. **Settings** doesn't need to match a reference pixel-for-pixel — designed fresh from
   `CLAUDE.md`'s text description.
3. **Divinum Officium commit to pin:** no preference stated — M0 pins to current `master`
   and records the hash in `data/SOURCE.md`.
4. **Date picker colour dots:** wanted, using the 1960/pre-conciliar liturgical colour
   rules rather than the Novus Ordo scheme in `Calendar.png`. (§ M3)
5. ~~**Apple Developer Program:** already enrolled...~~ **Superseded 2026-09-16:** the
   user has decided against the paid program entirely. Installation is by sideloading
   with a free Apple ID instead — see the amendment at the top of this document, the
   updated M0/M6, and `docs/install-on-iphone.md`.
6. ~~**fastlane match storage:** a separate private repo...~~ **Superseded 2026-09-16:**
   moot — there's no `fastlane match`, no certificates, and no certificate storage repo
   in the sideloading approach.
7. **Oracle fixture scope:** reduced to a full Latin/priest-off sweep over 2025–2040 plus
   a ~100-date spot check across the other three option combinations, rather than the
   full four-way matrix over the whole range. (§ Testing strategy, § M4, § Risks)

---

Sources consulted for the CI details above:
- [runner-images/images/macos/macos-26-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [macos-26 is now generally available for GitHub-hosted runners](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
- [DivinumOfficium/divinum-officium](https://github.com/DivinumOfficium/divinum-officium)

Sources consulted for the 2026-09-16 sideloading amendment (see `docs/install-on-iphone.md`
for the full citation list): Sideloadly's own site and FAQ, AltStore/AltServer's FAQ site,
and SideStore's documentation.

---

## Beta 1 (plan: [`Beta_1_plan.md`](Beta_1_plan.md))

### B1-M0 — Housekeeping and baseline

**Baseline (2026-09-24, `main` at `13c6a52`, Linux, Swift 6.1 in Docker):**
- the fast suite, 341 tests, passes (`swift test --skip vespersFullRange`, 202 s);
  it includes all 732 `holdout2044VespersMatchesDivinumOfficium` cases;
- `vespersFullRangeContentAudit` passes: 0/0/0/0/0/0/0 over 2025–2040 (307 s);
- `vespersFullRangeCommemorationAudit` passes: 0 dates (220 s).

**CI budget.** Measured on the last full runs (`d763107`): Kit CI 4.8 min, App CI 20 min.
Kit CI stays under the plan's 10-minute threshold, so the long audits stay in it for now.
Revisit in B1-M2, when the Vulgate and bilingual fixture sets roughly triple the audit
time. `kit-ci.yml` and `app-ci.yml` now use `concurrency`: a newer push to a pull request
cancels that PR's older run, and pushes to `main` never cancel each other.

**Bug: hymns shown as single lines, not stanzas.** Measured with the new
`scripts/measure-snapshot.py --pitch` on the M5 snapshot of 19 November 2026 ("Fortem virili
pectore"): **every** hymn line had a 34.3 pt pitch, which is the 23 pt line pitch plus
the 11.4 pt stanza gap (0.6 × 19). The final doxology, the last unit and so without a
trailing gap, was at 23.0. The engine is correct: `HourAssembler.hymnStanzas` emits one
`.prose` unit per stanza, its lines joined by `\n`. But TextKit starts a new paragraph at
every `\n`, so the stanza's `paragraphSpacing` applied after every line. The regression
came in with the TextKit port (`2ef9957`).

Fixed in `OfficeTypesetter.appendParagraph`: line breaks inside a unit become U+2028 LINE
SEPARATOR, so a stanza stays one paragraph, with the gap only after its last line. This
covers any multi-line unit, and hymn stanzas are the only one today. The string length is
unchanged, so the table of contents' offsets are unaffected. Also added a
`BREVIARIUM_SNAPSHOT_SECTION` launch hook (open at a section, like the table of
contents) and `testHymnStanzasSnapshots` (19 November 2026 at the hymn, horizontal and
vertical, M and XXL).

**After the fix** (App CI on `b8684b6`, `hymn-*` snapshots, `measure-snapshot.py --pitch`):

| Snapshot | Within a stanza | Between stanzas |
|---|---|---|
| vertical, M | 23.0 (±0.3) | 34.3–35.0 |
| vertical, XXL | 34.3 (±0.4) | 51.7–52.7 |
| horizontal, M | — (see below) | — |
| horizontal, XXL | 34.3 | — (one stanza on the page) |

Within a stanza the pitch is now the plain line pitch. The stanza gap appears once per
stanza, 11.4 pt at M and about 17.5 pt at XXL, which is 0.6 × body at both sizes. The
doxology's *Amen.* stays inside its stanza. The ferial psalmody page still measures 23.0 pt
body pitch, so nothing else moved.

**Second bug, found by these snapshots: table-of-contents jumps in horizontal mode could
land one page early.** A section's offset is its separator rule, a paragraph of its own. At
M on 19 November 2026 the rule before *Hymnus* is the last line of page 7, and the heading
starts page 8. So the jump showed page 7 (the end of the *Capitulum*), and the M hymn
snapshot shows no hymn. `PagedOfficeReader` now jumps to the page of the paragraph after
the rule, which is the heading. When the rule and the heading share a page, which is the
usual case, nothing changes. The vertical reader still scrolls to the rule, which it
always shows above the heading.

**`CLAUDE.md` updated** as approved with the B1-M0 plan:
- the Vulgate psalter becomes the default, with Pius XII as an option;
- a *Psalterium* setting is added (final label in B1-M5);
- the oracle scope covers both psalters;
- the options mapping notes that the psalter option off means the Vulgate;
- the reference screenshot is named correctly (`Format.png`).

### B1-M1 — The psalters and the English (document)

Written as [`psalters-and-english.md`](psalters-and-english.md), for review; no code.
Headline findings:
- the psalter switch changes only `Psalterium/Psalmorum/`;
- the Vulgate and the English match line for line, while Bea does not;
- DO's English is complete for Vespers (92 sampled evenings);
- DO's psalter is Challoner Douay-Rheims (0.6% word variants against DRBO), but about a
  dozen of its 83 chapters use King James or modern wording.

Five questions are waiting for the user, including Bea pairing and DRBO against DO.

### B1-M2 — Fixtures

- **Generator.** `oracle-worker.sh` takes a psalter (`lang1`) and a format; the new
  "rows" format keeps DO's Latin and English cells apart. `scripts/generate-fixture-set.sh`
  builds the sets.
- **Sets generated** (`data/SOURCE.md` has the table and every check):
  - `vulgate/` 2025-2040, 9.7 MB;
  - `bilingual/` 2025-2040, 23 MB;
  - `holdout/2044-bilingual.tar.gz`, 1.6 MB.

  The committed fixtures grow from 12 MB to 46 MB.
- **Checks:**
  - host renders equal container renders;
  - rows joined equal the flat page;
  - 2044 generated twice, byte-identical;
  - no empty renders, cells or rows;
  - on all 5,844 dates the bilingual Latin column equals the Vulgate Latin-only page.
- **Bea suite.** No engine or test code changed, so the Bea suite is unaffected; Kit CI
  confirms it.
- **Render speed.** Host rendering ran at about 0.3 s per page with 4 workers, so a full
  set takes about 7-12 minutes.

### B1-M3 — Vulgate in the engine

**Psalter option.** `Psalter` (`.vulgate`, `.pius12`) and
`DataBundle.makeLatinCorpus(psalter:)`:
- `.vulgate` is plain `Latin/` alone;
- `.pius12` is `Latin-Bea/` layered over `Latin/`, as before.

Every test passes its psalter explicitly. The full-range content and commemoration audits,
the new psalmody audit and the 2044 hold-out run in both psalters (the Vulgate hold-out
reads the Latin column of `holdout/2044-bilingual.tar.gz`).

The plan's `OfficeOptions` value is not introduced yet. The psalter selects which files
the corpus holds, so it belongs where the corpus is built, not in a per-call option like
`priest:`. `OfficeOptions` arrives with English in B1-M4, where it carries `priest` and
`english`.

**First measurement: the Vulgate already passes the existing audits.** Unchanged engine,
Vulgate fixtures:
- content audit 0/0/0/0/0/0/0;
- commemoration audit 0 dates.

Everything that differs between the psalters (`‡`, titles, ranges, the Magnificat) was
either already handled or invisible to those two audits.

**New audit, `vespersFullRangePsalmodyAudit`** (`PsalmodyAuditOracleTests.swift`). It
compares each psalm's title and exact verse-reference list with DO's page, which is the
direction the content audit can't see.
- **Baseline** (counted by the first difference on each date): Pius XII 5,683 dates,
  Vulgate 634.
- **Parser correction.** A first version miscounted about 570 Paschaltide dates, where
  the five psalms share one antiphon. The parser now also ends a psalm at the next title;
  the counts above are after that correction.

**Bug 1: both halves of 144:13 dropped at Psalm 144's split** (Saturdays with the ferial
psalms, 634 dates, both psalters).
- *Cause.* `Psalm.parseVerses` stripped the `a`/`b` letter before the verse range was
  applied, so `144(8-'13a')` and `144('13b'-21)` both rejected an unlettered "13".
- *DO.* It filters the lettered lines (`horasscripts.pl:598-614`) and drops the letter
  only for display (`:400-403`).
- *Fix.* Parse with letters, filter, then strip (`HourAssembler.versesInRange`).
- *Named test:* `saturdayDividedPsalm144KeepsBothHalvesOfVerse13`.

**Bug 2: psalm titles.**
- *Symptom.* The title was built from the raw `Psalmi major` token, so it read
  `Psalmus 144(8-'13a')`. The Pius XII subtitle (`— Messias rex, sacerdos victor`) was
  never shown.
- *DO.* `psalmi.pl:692-697` passes `8` and `'13a'` as Perl arguments, and
  `horasscripts.pl:561-562` titles the psalm `Psalmus 144(8-13a)`. `:581-596` appends the
  Bea `(subtitle)` line, dropping it for a part that starts after the first verse
  (`138(14-24)`, `144(8-13a)`).
- *Fix.* `HourAssembler.psalmTitle(baseNumber:range:fileText:)`. The subtitle is read
  off the file: no plain-Latin psalm file (1-150) starts with a `(…)` line; only
  canticles do, and DO titles those separately.
- *Named test:* `dividedPsalmTitlesMatchDivinumOfficium`.

**After both fixes:** psalmody audit 0 dates in both psalters.

### B1-M4 — English in the engine

**English corpus.** `DataBundle.makeEnglishCorpus()` is `English/` layered over the
Vulgate `Latin/`, as DO builds its second column (`SetupString.pl:589-639`): a section
missing in English falls back to the Latin. `LayeredOfficeCorpus` now returns every
layer's variants, lower layers first, so the last applicable one wins across layers too.
For example, English `[Feria Versum 3] (feria 7)` beats the Latin `@:Dominica Versum 3`.
`HourAssembler` resolves every unit a second time against it, per language: antiphons,
verses, versicles, hymn stanzas, chapter, collect, commemorations and rubrics. With the
Pius XII psalter, a psalm whose verses don't line up with the English gets one
`.englishPsalm` block, paired whole (`psalters-and-english.md`).

**New audit, `vespersFullRangeEnglishAudit`** (`EnglishAuditOracleTests.swift`), against
the bilingual fixtures (Vulgate plus English, one DO table row per line). It makes four
checks:
- **content:** every English piece we render is in DO's English column;
- **coverage, English:** nothing but chrome is left in DO's English column once ours is
  removed;
- **coverage, Latin:** the same for DO's Latin column, which the Latin content audit
  can't see;
- **pairing:** a unit's Latin and English sit in the same DO row.

The 2044 hold-out runs it too, with the priest on and off.

**Baseline** (engine with no English yet):
- 944 distinct uncovered English texts, on 5,844 dates;
- one mispairing, on 591 dates;
- no English at all for any hymn, psalm, canticle, chapter, collect or versicle.

**Fixes found by the audit**, each checked against DO's Perl:
- `†` is removed and `‡` becomes the half-verse break, in both languages
  (`horasscripts.pl:397-419`).
- The Oratio preamble. The V/R is replaced by the line-5 rubric of `[Dominus]` when there
  is no priest and the preces were said (`$precesferiales`). *Orémus* is added, and the
  whole preamble is gated on `Limit…Oratio` (`orationes.pl:152-213`). *Orémus* also goes
  before each commemoration's collect (`orationes.pl:820`).
- A closing antiphon's first `*` is removed (`psalmi.pl:688`, `orationes.pl:818`, no
  `/g`).
- The seasonal alleluia in English is the lower-case `alleluia`
  (`LanguageTextTools.pm` `ensure_single_alleluia`).
- `$`/`&` macro names are trimmed, e.g. the English `$Per Dominum ` in `Sancti/02-24`
  (`webdia.pl` expand).
- `;` counts as punctuation when matching an antiphon's opening (`horas.pl` `depunct`),
  which fixes Psalm 111 on 531 dates.
- The commemoration rubric names the office from the English `[Rank]`
  (`SetupString.pl`'s naming), e.g. "Commemoration of Annunciation of the Blessed Virgin
  Mary".
- The Ascension/Paschaltide "major special" rule applies only when the office isn't a
  Sunday's (`horascommon.pl:2296`). This fixes the missing hymn on the Saturdays before
  the Sundays after Easter.
- Holy Thursday's and Good Friday's `[Prelude Vespera]` rubric (`specials.pl:123-125`) is
  now `Hour.prelude`, shown as header item 6.
- A commemoration's antiphon loses its first `*`, as the closing antiphons do. This fixes
  the double asterisk in the Lenten feria commemorated on 24 February 2026.
- The Magnificat antiphon's location is looked up separately in each language. On Tuesday
  of the third week after Easter the English has its own `[Ant 3]` where the Latin falls
  back.

**After the fixes:** every check is 0 over 2025-2040. The Latin content, commemoration
and psalmody audits stay 0 in both psalters, and the 2044 hold-out passes in both
psalters with English.

**CI split.** The full-range audits took Kit CI to over 20 minutes, so they moved to
their own workflow, `oracle-audits.yml` (`--filter vespersFullRange`), which runs in
parallel. Kit CI runs `swift test --skip vespersFullRange`.

### B1-M5 — English and the psalter setting in the app

**Day title (alpha carry-over), audited.** New `vespersFullRangeTitleAudit`
(`TitleAuditOracleTests.swift`) compares the title block's name line with DO's page title
(the text before " ~ ") on every date from 2025 to 2040. Its baseline found two causes,
not one:
- **First Vespers.** The title followed the day's own office, while DO titles the page
  after the office whose Vespers is prayed. Examples: every Saturday evening before a
  Sunday, Christmas Eve, the eves of the Ascension and the Assumption, and 30 June (the
  Precious Blood).
- **The monthday suffix** ("… III. Augusti") was missing on the Sundays and ferias after
  Pentecost, and on the resumed Sundays after Epiphany, from August to November.

*Fix.* `LiturgicalCalendarEngine.vespersDay` builds the title from `Concurrence`'s Vespers
office and adds `HourAssembler.monthdayTitleSuffix`, the function already used and
audited for commemorations. The app uses it.

*After:* 0 dates. The fast suite passes (346 tests). New named tests:
`augustFeriaTitleHasItsMonthdaySuffix`, `saturdayEveningTitleIsTheSundaysFirstVespers`.

**Parallel layout (English on).** `OfficeTypesetter.typesetParallel` turns the hour into rows:
- **Full width:** the page-1 header, rules and headings, psalm titles, anything without
  English, and, in portrait, the chapter and collect, stacked Latin then English.
- **Two columns:** antiphons, verses, versicles and responses, rubrics and hymn stanzas.
  In landscape, the chapter and collect go side by side too.
- **Pius XII:** a psalm's Latin sits beside its whole-psalm `.englishPsalm` block.

`ParallelLayout` (`OfficeReaders.swift`) lays each column out in its own TextKit 1 stack
and packs rows onto pages like the Latin-only book pages:
- a row too long for the page continues on the next, each column at its own line
  boundary, never leaving one line of a longer run at the foot of a page;
- headings and psalm titles never end a page;
- a versicle stays with its response.

Both reading modes, slide and page curl, and vertical scroll, share it. The Latin-only
pages now also move a heading or psalm title at the foot of a page to the next one (alpha
carry-over).

**First snapshots (App CI), four fixes:**
- the date line drew in the system link style;
- section rules sat on the previous row, because TextKit drops a text's leading
  paragraph spacing;
- words broke letter by letter in XXL columns (now hyphenated, with margins capped at
  28 pt);
- vertical mode showed "Page 1 of 1".

Two UI-test harness bugs were also fixed: a failed landscape step left later tests
rotated, and the longer Settings form needs scrolling.

**Open:**
- the landscape captures came back in the portrait screen buffer, cropped. Taken from the
  app window instead, they confirm the landscape layout (two columns at full width, with
  the chapter and collect side by side). They also showed a real bug: rotating moved the
  reader a page or two on, because the position kept on relayout was the page's *last*
  row. It is now the first row (`ParallelLayout.firstRow(onPage:)`);
- at XXL the hyphenator finds no break in "sæculórum", which still splits "sæculóru /
  m." in the narrow column.
