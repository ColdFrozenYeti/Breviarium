# Breviarium — project rules

Breviarium is a personal, native iPhone app for the traditional Divine Office. It is modelled closely on the Universalis app's night mode in layout and behaviour, but it gives the pre-conciliar office instead of the Liturgy of the Hours. It is for private use by one person and will never be distributed publicly.

Read this file at the start of every session. If a decision here conflicts with a request in chat, ask before proceeding.

## Non-negotiables

- **Fully offline.** The app makes no network calls of any kind: no analytics, no crash reporting, no remote fonts, and no update checks. Do not add network entitlements. Everything, including all texts, ships inside the app bundle.
- **No third-party dependencies** in the app or the engine: Apple frameworks and the Swift standard library only. Build and CI tooling may use whatever is convenient, as long as nothing from it is linked into the app.
- **The app computes the office itself.** There is no precomputed ordo with an expiry date, and any date must work.
- **iPhone only**, with a deployment target of **iOS 26.5** and no backwards compatibility.
  - Use SwiftUI and current Swift concurrency.
  - Avoid UIKit unless SwiftUI genuinely cannot do something, and say so first.
- **Night mode only.** There is no light theme.
- **No features beyond the brief.** That means:
  - no notifications, prayer tracking, checkmarks, bookmarks, or sync;
  - no chant, audio, or play button;
  - no Mass propers, Rosary, or Angelus.

  This is a breviary in a phone.
- **No explanatory text in the office.** The only non-liturgical text is section headings, the date line, the day title block, and the page footer. Rubrics are shown in red when the rubrics toggle is on.
- **No capability a free Apple ID can't sign.** The user has no paid Apple Developer Program membership and installs by sideloading (see below), so the app must never declare, and no feature may ever need, iCloud, push notifications, App Groups, widgets/extensions, or associated domains — a personal-team free-tier signature can't cover any of them. If a future feature would need one, stop and flag it before building it rather than building it and finding out at sign time.

## Development environment: there is no Mac

The user does not own a Mac and will not buy one. Design every workflow around that constraint.

- **Local work (Windows or Linux)**
  - `BreviariumKit`, the data tool, and all engine tests must build and run with the open-source Swift toolchain (`swift build`, `swift test`) without Xcode.
  - Divinum Officium runs locally in Docker.
  - Milestones M0–M4 must be fully doable locally.
  - **PowerShell scripts (`.ps1`) must be plain ASCII and parse under Windows PowerShell 5.1**, not just PowerShell 7+. 5.1 reads a script without a BOM using the system codepage, not UTF-8, so a multi-byte character (an em dash, a curly quote, an accented letter) gets mangled into something that breaks tokenization — this has already caused a real "string is missing the terminator" parse failure from a stray em dash. Use `-` instead of `—`/`–`, straight quotes only, and no accented letters, even in comments. Also avoid unescaped apostrophes inside single-quoted strings (`'don''t'` or switch to double quotes) — single quotes have no escape character otherwise. Check with a quick parse: `[System.Management.Automation.Language.Parser]::ParseInput((Get-Content -Raw file.ps1), [ref]$null, [ref]$errors)`.
- **App builds**
  - App builds run on **GitHub Actions macOS runners**, using the latest Xcode image that supports the iOS 26.5 SDK. Verify this rather than assuming.
  - The workflow builds the app, runs the Kit tests, runs the UI snapshot tests on a simulator, and uploads the rendered PNGs as artifacts.
- **Installing on the iPhone**
  - No Apple Developer Program membership. Installation is by **sideloading with a free Apple ID**, done entirely from Windows — see `docs/install-on-iphone.md` for the tool, one-time setup, and weekly routine.
  - CI produces an **unsigned** device build (`CODE_SIGNING_ALLOWED=NO`), packaged as a plain `.ipa` (`Payload/Breviarium.app`, zipped), and uploads it as a GitHub Actions workflow artifact — nothing in CI ever signs anything, since CI has no Apple account to sign with. `scripts/get-ipa.ps1` fetches the latest one.
  - The actual signing happens on Windows, in the sideloading tool, with the free Apple ID. Free-tier signatures **expire after 7 days** and must be re-signed; `docs/install-on-iphone.md` covers that routine, including whether it needs a cable.
  - The **bundle identifier stays fixed forever** (`com.epavone.breviarium`) so every re-sign reuses the same App ID instead of burning through the free tier's ~10-new-App-IDs-per-week limit.
  - Design the CI pipeline so that adding TestFlight later, if the Apple Developer Program is ever joined, means adding a signing step on top of the existing unsigned build — not restructuring it.
- **Visual iteration without a simulator on hand**
  - Snapshot tests render each key screen at fixed sizes in the iOS simulator on CI.
  - Download the artifacts and compare them visually against `design/reference/`. Report differences concretely (element, measured value, expected value), fix them, and repeat.
- **Never tell the user to "open Xcode"** or to do anything that requires a local Mac. If something truly cannot be done from CI, say so, explain why, and propose the cheapest workaround (e.g. renting a cloud Mac for a day).

## Liturgical scope

- **Roman office:** Breviarium Romanum under the 1960 rubrics (1962 typical edition), using the Universal Calendar only (no national, diocesan, or order propers) and the **Pius XII (Bea) psalter**.
- **Ambrosian office (pre-conciliar):** selectable in settings in a later milestone.
  - Divinum Officium does **not** contain the Ambrosian office; the user will supply sources and details later.
  - The engine must let a second rite plug in without rewriting the Roman one.
- **Hours:** all eight eventually, Matutinum to Completorium. The alpha is **Roman Vespers only**.
- **Later additions:** Martyrology at Prime (on/off setting), votive offices where the rubrics permit, and possibly the Little Office of Our Lady and the Office of the Dead.

## Settings (Universalis-style toggles)

- **Ritus:** Romanus / Ambrosianus. Ambrosianus stays disabled until it is implemented.
- **Sacerdos vel diaconus adest:** on gives *Dominus vobiscum*; off gives *Domine, exaudi orationem meam*.
- **Rubricæ:** show or hide rubrics.
- **English translation:** on or off (parallel text).
- **Text size.**
- **Later:** Martyrologium ad Primam, and a votive office picker.

## Texts and orthography

- **Primary language: Latin.** The optional English uses the **Douay-Rheims** (as on DRBO) for Scripture and Divinum Officium's English for everything else.
- **Latin orthography:**
  - Keep accents (*Dóminus*) and æ/œ ligatures.
  - Use **I, not J** (*Iesum*, *eius*, *iudicáre*, *Ierúsalem*).
  - Apply J→I to **Latin text only**, at build time, with tests. Never touch English.
- **Latin wording for fixed elements:** section headings, the date line, and the hour titles (*Ad Vesperas* etc.).

## Visual specification

`design/reference/` holds screenshots of Universalis in night mode and is the authority. The first one, `universalis-compline-night.png`, is 1170×2532 px at @3x, so divide by 3 for points. The measurements below were taken from it; re-measure if more screenshots are added. **If a screenshot and this text disagree, ask.**

### Colours

Sampled from the screenshot:

| Element | Colour |
|---|---|
| Background | `#000000` (pure black, OLED) |
| Liturgical text, section headings, day title, separator rules | `#FFFFFF` |
| Rubrics and the date line | `#FF8080` |
| Icons (table-of-contents button) | `#FF4D33` |
| Chrome text (navigation title, page footer) | `#B2B2B2` |

### Typefaces

- **Liturgical content** uses an old-style serif, which appears to be **Hoefler Text** (ships with iOS, so no bundled font is needed).
  - Confirm by rendering it next to the screenshot.
  - If it is not a match, propose an alternative. Bundling an OFL font such as EB Garamond is allowed.
- **Chrome** (navigation title, date line, footer) uses the system sans-serif (SF).

### Page structure, top to bottom

Values are at the default text size.

1. **Navigation title**, centred, small SF, `#B2B2B2`: the hour name (e.g. *Ad Vesperas*).
2. **Date line**, right-aligned, SF *italic*, `#FF8080`, noticeably larger than body text.
   - Format: *Dies 16 septembris 2026*, i.e. `Dies <day> <month genitive> <year>`.
   - Months: ianuarii, februarii, martii, aprilis, maii, iunii, iulii, augusti, septembris, octobris, novembris, decembris.
3. **Day title block**, left-aligned. Wrapped lines take a **hanging indent** of about 38 pt. For 16 September 2026 it reads:
   - `III. classis`: serif, regular weight, body size, just above the name;
   - `Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum`: serif **black/heaviest weight**, about 1.3× body size, as in the screenshot's bold title;
   - `Commemoratio ad Laudes tantum: Ss. Euphemiæ, Luciæ et Geminiani Martyrum`: serif, regular weight, body size, below the name. Omit this line when there is no commemoration.
4. **Table-of-contents button**, right-aligned below the title: a list icon in `#FF4D33`. It opens a list of the hour's sections and jumps to the chosen page.
5. **Hour title**, centred, serif regular, about 1.5× body size (e.g. *Ad Vesperas*). There is no music note and no subtitle.
6. **Opening rubric**, if any: serif *italic*, `#FF8080`, left-aligned. It is hidden when rubrics are off.
7. **Section separator**: a centred white rule about 83 pt wide and 1 pt thick, with roughly 44 pt of space above and below.
8. **Section heading**: serif **bold, all capitals**, slightly larger than body, left-aligned (e.g. INTRODUCTIO, HYMNUS, PSALMODIA, CAPITULUM, CANTICUM, ORATIO, CONCLUSIO).
   - Propose the exact heading set and how it maps onto Divinum Officium's sections in `docs/rubrics-1960-vespers.md`, for approval.
9. **Body**: serif regular, about 19 pt, with a line pitch of about 23 pt, white.
   - **Margins** are about 28 pt left and right.
   - **Versicle/response pairs**: the response is *italic* and indented about 23 pt. No ℣/℟ glyphs are shown.
   - **Psalm verses and doxology**: the first half ends with `*` attached directly to the last word (`Fílio*`); the second half goes on its own line, indented about 23 pt.
   - **Antiphons, hymn stanzas, chapter, and collect** follow the same typographic system. Where the screenshot gives no example, propose a treatment consistent with it.
10. **Footer**, pinned to the bottom, SF, `#B2B2B2`:
    - centre: `Page N of M`;
    - right: short date, e.g. `16-Sep-26`;
    - left: nothing (Universalis's audio button is omitted).

### Behaviour

- **Paging.** An hour is **paginated**, with one page per section group, and the user swipes horizontally between pages. The header elements (items 2–6) appear on page 1 only, as in the screenshot. Propose the page grouping for Vespers.
- **Text size** scales every serif size and the vertical spacing proportionally. The chrome text scales too, but more gently.

### Parallel English

- **With English on:**
  - Verse material (psalms, canticles, antiphons, hymn stanzas, versicles and responses) is shown **side by side**, Latin left and English right, with each column using the same typographic rules.
  - **Prose** (chapter, collect, lessons) is **stacked**, Latin then English, in portrait, and shown side by side in landscape.
- **With English off,** Latin uses the full width.
- **Alignment** is by structural unit:
  - psalms by verse number, merging half-verses where the Bea and Vulgate divisions differ;
  - hymns by stanza;
  - everything else by whole unit.

## Data source

- **[Divinum Officium](https://github.com/DivinumOfficium/divinum-officium)** (MIT licence) is the text and rubrics source for the Roman office.
  - Vendor it as a git submodule pinned to a commit, and record the hash in `data/SOURCE.md`.
  - Include the MIT notice on the About screen.
- **Relevant paths:**
  - `web/www/horas/Latin/` and `web/www/horas/English/`: texts.
  - `web/www/horas/Latin-Bea/`: the Pius XII psalter.
  - `web/www/Tabulae/`: calendars (`Kalendaria/1960.txt`) and version data.
  - `web/cgi-bin/horas/`: the Perl engine, which is the reference for rubrical logic.
  - `docs/how-the-calendar-works.md`.
  - `regress/`: DO's regression date ranges.
- **Options mapping.** The DO version string is `Rubrics 1960 - 1960`. Its "Pius XII Psalter" and "Priest" options correspond to our psalter and priest toggle.
- **File format.** DO files use `[Section]` headers, conditionals such as `(sed rubrica 1960)`, cross-references such as `@Commune/C3:Section`, `$` and `&` macros, and `v.` / `V.` / `R.` / `!` markers. Understand the format fully before writing the parser; do not guess.

## Architecture

- **`BreviariumKit`**
  - A pure-Swift package depending on Foundation only.
  - **Must build and test on Linux and Windows.** No SwiftUI, UIKit, or Apple-only APIs.
  - Contains the calendar, the rubrics and precedence logic, office assembly, and the text model.
- **`BreviariumData`**
  - A build-time command-line tool in the same package.
  - Reads the pinned DO checkout, resolves static conditionals, normalises orthography, and emits a compact bundled data file.
  - Optimise for launch time, lookup speed, and size, and report the size.
  - Conditionals that depend on the day stay in the data for the engine to evaluate.
- **`Breviarium` app target**
  - SwiftUI views only, with no liturgical logic. Every rubrical decision lives in the Kit.
- **Rite abstraction**
  - Roman-1960 and Ambrosian are separate providers behind one interface covering calendar, precedence, and hour assembly.
- **Vespers date semantics**
  - Selecting a date and opening Vespers gives what is prayed on that evening, including first Vespers of the next day where the 1960 rubrics require it.
  - Match Divinum Officium's behaviour, including the title block it shows in those cases.

## Testing

- **Unit tests** (Swift Testing) cover:
  - the computus and temporal cycle;
  - sanctoral lookup;
  - precedence and occurrence/concurrence;
  - orthographic normalisation;
  - the date-line formatter;
  - every DO syntax feature the parser meets.
- **Oracle tests** are the main correctness check.
  - Run Divinum Officium in Docker at the **same pinned commit**.
  - Retrieve its rendered Vespers (`Rubrics 1960 - 1960`, Pius XII psalter) for **every day from 2025-01-01 to 2040-12-31**, with priest on and off, in Latin and English.
  - Normalise the output (strip HTML, collapse whitespace, apply the same J→I rule) and store it compressed as golden fixtures.
  - `swift test` diffs engine output against the fixtures, per date and per section.
  - Discover how DO is invoked by reading its CGI scripts and `regress/` tooling, not by guessing URL parameters.
- **Named edge cases** get their own readable tests:
  - Christmas Eve, Christmas and its octave, 1 January, Epiphany;
  - Sundays after Epiphany resumed after Pentecost;
  - Septuagesima, Ash Wednesday, Passiontide, Holy Week and the Triduum;
  - the Easter octave, Ascension, and the Pentecost octave;
  - Corpus Christi, the Sacred Heart, and Christ the King;
  - All Saints and All Souls;
  - Ember days;
  - Our Lady on Saturday;
  - 8 December on an Advent Sunday;
  - the Annunciation transferred in 2027, 2029 and 2035, and St Joseph transferred in 2035;
  - leap-year February;
  - the latest Easter (2038) and an early one (2035);
  - 16 September 2026, whose title block is given in the visual specification.
- **Snapshot tests** run on CI. They cover the Vespers page 1 and a psalmody page for:
  - a ferial day;
  - a day with a commemoration;
  - a I class feast;
  - a Holy Week day.

  Each is rendered with English off and on, in portrait (plus landscape with English on), at the default and the largest text size.
- **Never "fix" a failing oracle test by editing the fixture.** If you believe DO is wrong on a date, stop and show the evidence: the relevant Codex Rubricarum 1960 section, with DO's output next to ours.

## Working conventions

- Work milestone by milestone. At the end of each one, summarise what was built, show the test results (and snapshot images for UI work), and wait for approval.
- Keep commits small and descriptive.
- Code is in English, except for Latin identifiers where they are the natural domain terms (`Vesperae`, `Commemoratio`).
- When liturgical correctness is uncertain, ask. Do not improvise rubrics.
