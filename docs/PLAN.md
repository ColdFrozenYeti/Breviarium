# Breviarium — Alpha Implementation Plan

## Context

Breviarium is a personal, offline iPhone app that computes and displays the traditional
(1960 rubrics, Pius XII psalter) Divine Office, styled after the Universalis app's night
mode. The alpha scope is Roman Vespers only. The defining constraint is that development
happens entirely without a Mac: `BreviariumKit` (the engine) must build and test on this
Windows machine with the open-source Swift toolchain, while the app itself, its signing,
and its delivery to the user's iPhone all happen on GitHub Actions macOS runners and
TestFlight. Every milestone below is sequenced so that the no-Mac pipeline is proven
first, before any liturgical logic is built on top of it.

This plan was produced after reading `CLAUDE.md` in full and inspecting the three images
actually present in the repository (`Design/Reference/Format.png`,
`Design/Reference/Calendar.png`, `Design/Reference/Hours Picker.png` — see the note on
naming below).

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
    docker/                        (docker-compose for DO, pinned to the submodule commit)
    generate-oracle-fixtures.*     (drives the Docker DO instance, writes data/oracle-fixtures)
  .github/workflows/
    kit-ci.yml                     (ubuntu-latest: swift build/test for Kit, Data, Oracle)
    app-ci.yml                     (macos-26: xcodegen generate, build, UI snapshot tests, upload PNG artifacts)
    testflight.yml                 (macos-26, manual/tag-triggered: archive + fastlane pilot upload)
    bootstrap-signing.yml           (macos-26, manual, one-time: fastlane match appstore)
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

Parses the pinned Divinum Officium checkout, resolves every **static** conditional
(rubric-version gates like `(sed rubrica 1960)`, language selection, priest/non-priest
text variants that don't depend on the day being viewed), follows `@Commune/...`
cross-references, applies J→I to Latin fields, and emits one bundled data file containing:

1. The sanctoral calendar table (from `Tabulae/Kalendaria/1960.txt`): date → feast(s) →
   rank → commune reference. This is genuine *data*.
2. The de-duplicated text corpus (temporal + sanctoral propers, commune texts, the Bea
   psalter, fixed ordinary text) in Latin and English, keyed by DO's own section
   identifiers.
3. **Day-dependent** conditionals (the ones that can't be resolved once at build time —
   e.g. anything keyed off moveable-cycle position) are left as structured references in
   the data for `BreviariumKit`'s rite logic — never resolved as code inside the data
   tool. This preserves "the app computes the office itself."

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
   generate the project, `xcodebuild build` a placeholder app (one screen, black
   background, "Breviarium" text) for the simulator, then archive for a real device.
8. **Apple Developer / App Store Connect bootstrap (browser checklist for you).**
   Documented step by step in `docs/PLAN.md` and repeated as an issue/checklist:
   enrol in the Apple Developer Program; create the App ID and App Store Connect app
   record; create an **App Store Connect API key** (download the `.p8` once); store the
   key, key ID, and issuer ID as GitHub secrets; create a private repo (or private branch)
   for **fastlane match**'s encrypted certificate storage and its passphrase as a secret.
9. **`bootstrap-signing.yml`** (manual, one-time): runs `fastlane match appstore` **on the
   macOS runner itself**, authenticated with the App Store Connect API key (no Apple ID
   password, no interactive 2FA — confirmed current fastlane guidance, see sources) —
   this is what makes certificate/profile creation possible without ever touching a Mac.
10. **`testflight.yml`** (manual/tag-triggered): archive, export, and `fastlane pilot
    upload` the placeholder app to TestFlight.
11. **Exit criterion:** the placeholder app is installed on your iPhone via TestFlight,
    proving repo → Linux Kit CI → macOS app CI → signing → TestFlight, before any
    liturgical logic depends on the pipeline working.

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

### M2 — Data pipeline

Build `BreviariumData` per the "Data pipeline" section above: parse, resolve static
conditionals, normalise orthography, emit the bundled file. Tests cover every DO syntax
feature catalogued in `docs/do-format.md`. Report bundle size (compressed and
decompressed) and cold-load time on a representative device class.

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

### M4 — Vespers assembly

The full hour as the structured, formatting-free `Hour`/`Section`/`Unit` model, including
every commemoration the 1960 rubrics require, *Dominus vobiscum* vs. *Domine, exaudi*
per the priest toggle, and Latin/English pairing. Diffed against the DO oracle — see the
reduced fixture scope below. Done only when the diff is empty or every remaining
difference is written up for you with the Codex Rubricarum 1960 citation and DO's output
side by side, per `CLAUDE.md`'s rule against silently editing fixtures.

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

### M6 — TestFlight release

Ship the real alpha via the pipeline proven in M0: archive, sign, `fastlane pilot upload`.
Short manual verification checklist for you (date line for today, paging, TOC navigation,
priest toggle, rubrics toggle, English toggle, largest text size, previous/next day,
jump-to-date). `testflight.yml` stays a one-click re-run for the 90-day expiry.

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
| `testflight.yml` | macos-26 (10×) | manual / tag | archive + upload |
| `bootstrap-signing.yml` | macos-26 (10×) | manual, one-time | cert/profile creation |

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
- **No-Mac debugging.** No breakpoints, no Instruments, no on-device console beyond what
  TestFlight/App Store Connect crash diagnostics expose. If a defect can't be diagnosed
  from CI logs, symbolicated crash reports, and snapshot PNGs alone, the fallback is a
  short paid rental of a cloud Mac for a focused session — flagged here so it's a known,
  cheap escape hatch rather than a surprise.
- **First-run signing bootstrap.** `fastlane match`'s certificate creation is confirmed to
  work with App Store Connect API-key auth only (no Apple ID password/2FA), which is what
  makes `bootstrap-signing.yml` possible entirely on a CI runner — but this is worth a
  dry run early (in M0) rather than discovering an auth gap only at M6.
- **Xcode/SDK version drift.** GitHub's `macos-26` image (GA) currently ships Xcode
  26.0.1–26.6 with the iOS 26.5 SDK preinstalled, confirmed current as of this plan — `M0`
  should pin an explicit Xcode version in `app-ci.yml` rather than trust a rolling
  default, and revisit if GitHub deprecates the image.

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
5. **Apple Developer Program:** already enrolled, so M0's browser checklist starts from
   "create the App ID / App Store Connect record," not from enrolment — no turnaround-time
   gate on M0.
6. **fastlane match storage:** a separate private repo, per the plan's original
   recommendation.
7. **Oracle fixture scope:** reduced to a full Latin/priest-off sweep over 2025–2040 plus
   a ~100-date spot check across the other three option combinations, rather than the
   full four-way matrix over the whole range. (§ Testing strategy, § M4, § Risks)

---

Sources consulted for the CI/signing details above:
- [runner-images/images/macos/macos-26-Readme.md](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)
- [macos-26 is now generally available for GitHub-hosted runners](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
- [Using App Store Connect API — fastlane docs](https://docs.fastlane.tools/app-store-connect-api/)
- [match — fastlane docs](https://docs.fastlane.tools/actions/match/)
- [DivinumOfficium/divinum-officium](https://github.com/DivinumOfficium/divinum-officium)
