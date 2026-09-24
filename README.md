# Breviarium

A personal iPhone app for the traditional Divine Office, modelled on Universalis's night
mode but giving the pre-conciliar office: the *Breviarium Romanum* under the **1960
rubrics**, with the Universal Calendar and the Pius XII (Bea) psalter. The app computes
the office itself for any date. It is fully offline, night mode only, and for private
use. It is installed by sideloading with a free Apple ID.

## Status: alpha

The alpha is **Roman Vespers**, in Latin.

- **The office is right.** For every evening from 2025 to 2040, the engine's Vespers is
  checked against [Divinum Officium](https://github.com/DivinumOfficium/divinum-officium)'s
  own output, and every section matches. That covers psalms, chapter, hymn, versicle,
  Magnificat, collect and conclusion, and every commemoration, including those DO shows
  that the engine might have left out. All of 2044 is checked too, with the priest form
  on and off, as an out-of-sample year the engine was never tuned against.
- **The app** shows Vespers for any date:
  - The office reads like a book: pages turn sideways (a slide or a page curl) and the
    text flows line by line from one page to the next. A continuous vertical scroll is
    available instead.
  - The layout follows `design/reference/`: the date line, day title, table of contents,
    section headings, and a *Page N of M* footer.
- **Settings:**
  - *Sacerdos vel diaconus adest* (*Dominus vobiscum* or *Domine, exaudi*)
  - *Rubricæ* (show or hide rubrics)
  - Text size
  - Scrolling (horizontal pages or vertical scroll)
  - Page turn (slide or page curl)
  - About, with the Divinum Officium licence
- **Deferred to beta:** the parallel English translation (visible in Settings but
  disabled), the other seven hours, and the Ambrosian rite.

The build log, with every decision and every bug traced to the Divinum Officium source
it was checked against, is in [`docs/PLAN.md`](docs/PLAN.md).

## Installing on the iPhone

There is no Mac and no paid developer account. CI builds an **unsigned** `.ipa`, and a
sideloading tool on Windows signs it with a free Apple ID. The signature lasts 7 days
and is renewed weekly.

1. On GitHub, run the **Build IPA** workflow (Actions → Build IPA → Run workflow).
2. On Windows, fetch it with `.\scripts\get-ipa.ps1` (needs the GitHub CLI).
3. Sign and install it with AltStore/AltServer.

[`docs/install-on-iphone.md`](docs/install-on-iphone.md) covers the one-time setup, the
weekly re-sign routine, and a short checklist to run on the phone after each install.

## Repository layout

| Path | What it is |
|---|---|
| `Packages/BreviariumKit/` | The engine: calendar, occurrence and concurrence, commemorations, hour assembly, text model. Pure Swift and Foundation, so it builds on Linux and Windows. Also contains `BreviariumData`, the build-time tool that turns the Divinum Officium texts into the app's bundled data file. |
| `App/` | The SwiftUI app (XcodeGen `project.yml`) and its UI snapshot tests. Built only on CI. |
| `data/divinum-officium/` | Divinum Officium, as a git submodule pinned to one commit (see `data/SOURCE.md`). |
| `data/oracle-fixtures/` | Divinum Officium's own rendered Vespers, used as the tests' reference: every day 2025–2040, a spot-check set with the other option combinations, and the 2044 hold-out year. |
| `docs/` | The plan and build log, the 1960 Vespers rubrics reference, the Divinum Officium file format, and setup and install guides. |
| `design/reference/` | Universalis night-mode screenshots, the visual reference. |
| `scripts/` | Test runners, fixture generators, and the Windows `.ipa` fetcher. |

## Development

Clone with the submodule:

```
git clone --recurse-submodules https://github.com/ColdFrozenYeti/Breviarium.git
```

**Engine and tests** (Linux, macOS or Windows, open-source Swift 6 toolchain, no Xcode):

```
cd Packages/BreviariumKit
swift build
swift test --skip vespersFullRangeContentAudit     # the fast suite, as CI runs it
swift test --filter vespersFullRangeContentAudit   # the full 2025-2040 content audit (~5 min)
```

`scripts/test-kit.sh` and `scripts/test-kit.ps1` wrap the build and tests. For first-time
Windows setup, see [`docs/windows-swift-setup.md`](docs/windows-swift-setup.md).

What the tests check:

- **Oracle tests** compare the engine with Divinum Officium's own output. There are
  named tests for specific dates, each citing the Divinum Officium source it was checked
  against. There is a full-range content audit, a full-range commemoration audit, and
  one test case per day and priest setting for 2044.
- **Fixtures** are regenerated from the pinned checkout by
  `scripts/generate-oracle-fixtures.sh` (in Docker) and
  `scripts/generate-holdout-fixtures.sh <year>`.
- **Never "fix" a failing oracle test by editing a fixture.**

**The app** is built only on GitHub Actions macOS runners:

- `app-ci.yml` builds for the simulator and runs the UI tests. It uploads the snapshot
  PNGs as an artifact, which is how the layout is compared against `design/reference/`.
- `build-ipa.yml` produces the unsigned `.ipa`.

[`CLAUDE.md`](CLAUDE.md) holds the project rules: scope, visual specification, testing
discipline, and the non-negotiables.

## Credits and licence

The Latin texts and the rubrical logic come from
[Divinum Officium](https://github.com/DivinumOfficium/divinum-officium) (MIT licence),
pinned to commit `126a07f` (see [`data/SOURCE.md`](data/SOURCE.md)). Its licence notice
is shown on the app's About screen.
