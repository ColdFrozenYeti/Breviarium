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
`#Preces Feriales` still isn't resolved (`horasscripts.pl`'s `preces()` gating wasn't
traced) — see `HourAssembler`'s own doc comment for the full, current scope-limit list.

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

**Not yet built:** `#Preces Feriales`; Latin/English pairing; and the actual oracle diff
(`Tests/OracleTests`, which reads `data/oracle-fixtures/` and applies `LatinOrthography`
at compare time).

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
