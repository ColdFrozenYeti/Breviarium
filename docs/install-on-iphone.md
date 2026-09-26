# Installing Breviarium on your iPhone (free Apple ID, from Windows)

No Apple Developer Program membership, no App Store Connect, no TestFlight. CI produces
an **unsigned** `.ipa`; a sideloading tool on Windows signs it with your free Apple ID and
puts it on your iPhone. This is the M0 exit criterion and the routine for every install
after that.

This was researched fresh rather than from memory (see Sources at the end) since
sideloading tools change quickly.

## Which tool: AltStore/AltServer, not Sideloadly

Both are free, both currently support iOS 26, and both work from Windows with a free
Apple ID. The difference that matters most for the weekly re-sign chore is how each one
does *unattended* re-signing:

- **AltServer's wireless refresh is the mature, clearly documented mechanism.** As long
  as AltServer and the iCloud-for-Windows app are running on your PC (system tray icon
  visible; iCloud handles the Bonjour service AltServer advertises over) and your iPhone
  is on the **same Wi-Fi network**, the AltStore app on your phone can refresh itself over
  Wi-Fi with no cable. This is a well-established, several-years-old feature with clear
  official documentation of exactly what's required for it to work.
- **Sideloadly's equivalent is murkier.** Its FAQ says it supports Wi-Fi installs and
  mentions an "auto-refresh daemon," but the official documentation doesn't clearly spell
  out whether unattended refresh actually works without you opening the desktop app and
  clicking something. Sideloadly's real strength is its UI: drag an `.ipa` in, type your
  Apple ID, click Start — which is arguably simpler for a one-off install than AltStore's
  "app store" model built around browsing/adding "sources." But for the recurring
  every-7-days chore this project actually needs, the clearer mechanism wins.

**Recommendation: AltStore/AltServer.** Both need the same non-Microsoft-Store iTunes +
iCloud installed on Windows first, so that's not a differentiator.

If, later, keeping a Windows PC on and reachable every week becomes annoying, look at
**SideStore** — a fork of AltStore that, after a heavier one-time setup (it needs a
device "pairing file," generated with a separate tool), refreshes apps directly from the
iPhone with no computer involved at all, even over cellular. Not needed for the alpha;
noted here so you know the upgrade path exists.

## 1. Install on Windows

From Apple's own site (**not** the Microsoft Store versions — those aren't compatible
and must be uninstalled first if present):

1. iTunes for Windows
2. iCloud for Windows

(Apple Mobile Device Support and the USB drivers your PC needs to recognize the iPhone
come bundled with iTunes — no separate driver download.) AltStore's own install guide
(linked in Sources) has the current direct download links for both, since Apple moves
these around.

Then install **AltServer for Windows** from AltStore's site and run its installer.

## 2. One-time setup

1. Plug the iPhone in via USB, unlock it, and tap "Trust This Computer" if prompted.
2. In iTunes, sign in with your Apple ID and turn on **Wi-Fi sync** for the device — this
   is what lets AltServer reach it wirelessly later.
3. Launch AltServer as Administrator (Windows search → AltServer → Run as administrator).
   It sits in the system tray.
4. Click the AltServer tray icon → **Install AltStore** → choose your device → enter your
   Apple ID and password. (This goes to Apple only, to request a signing certificate —
   not to AltStore's developers.)
5. On the iPhone: **Settings → General → VPN & Device Management** (older iOS calls this
   "Profiles & Device Management") → tap your Apple ID under "Developer App" → **Trust**.
6. **Settings → Privacy & Security → Developer Mode** → turn it on → the phone restarts →
   confirm **Turn On** in the alert that appears after unlocking. (This menu item stays
   hidden until you've installed a development-signed app at least once, so it should
   appear right after step 4.)

## 3. First install of Breviarium

(Corrected from an earlier draft of this doc, which described a right-click/drag
interaction on the AltServer tray icon that doesn't exist — verified against the
official FAQ and AltServer's own release notes instead.)

1. On Windows: `gh workflow run build-ipa.yml` (or the Actions tab → Build IPA → Run
   workflow) to produce a fresh `.ipa`, then `.\scripts\get-ipa.ps1` to download it —
   it lands in `%USERPROFILE%\Downloads\BreviariumIPA\Breviarium.ipa` and the script
   prints the exact path.
2. Get that file onto the iPhone somewhere the Files app can see it. The easiest way,
   since iCloud for Windows is already installed (step 1): open the iCloud app on
   Windows, make sure **iCloud Drive** is turned on, then copy `Breviarium.ipa` into
   the iCloud Drive folder it adds to File Explorer. Give it a minute to sync.
   (Emailing the file to yourself and opening the attachment on the iPhone works too,
   if you'd rather not use iCloud Drive.)
3. On the iPhone, open the **AltStore** app (installed during one-time setup above) →
   **My Apps** → the **+** button in the top-left → browse to **iCloud Drive** → pick
   `Breviarium.ipa`. This is the method confirmed to register the app under AltStore's
   management, so it's included in **Refresh All** later (step 4) — that's the reason
   to go through AltStore's own file picker rather than AltServer's separate
   "Sideload .ipa…" tray shortcut (hold **Shift** while clicking the AltServer tray
   icon, if you ever want it for a one-off install): that shortcut installs the app
   directly to a connected device without necessarily adding it to AltStore's tracked
   list, and it wasn't possible to confirm from the official docs whether apps
   installed that way get picked up by Refresh All too.
4. AltStore signs and installs it; the icon appears on the home screen like any other
   app once it's done.

## 4. The weekly 7-day re-sign routine

A free Apple ID's signature is only valid for **7 days**; after that the app refuses to
launch until it's re-signed. There's no reminder from Apple or from AltStore — it's on
you to keep it current.

**Over Wi-Fi, no cable, as long as your PC is on:** open the **AltStore** app on your
iPhone (on the same Wi-Fi network as your PC, AltServer running) → **My Apps** →
**Refresh All**. That's it — no new `.ipa` needed unless you actually changed the app.
This can also happen automatically in the background once a day if AltStore gets a
chance to run, but treat that as a bonus, not something to rely on; make **Refresh All**
a weekly habit.

If your PC was off or off-network past the 7-day mark, the app just won't open — plug in,
get AltServer running and reachable again, refresh, and it comes back (see below on data).

## 5. What expiry looks like, and your data is safe

When the signature lapses, tapping the app icon shows an "Unable to Verify App" /
"Untrusted App" style alert instead of launching. **Nothing is uninstalled and nothing is
deleted** — the app bundle and everything it stored locally (settings, any future local
data) stay exactly where they are on the device. Re-signing (the Refresh All step above,
or a fresh install of the same `.ipa` through AltStore/AltServer with the same Apple ID
and the same bundle identifier) makes it launch again with all of that intact. This is
exactly why `CLAUDE.md` fixes the bundle identifier (`com.epavone.breviarium`) forever —
changing it would make AltStore treat a "re-sign" as a brand new app instead, losing
continuity (and burning a new App ID besides).

## 6. Free Apple ID limits, and how this setup avoids them

A personal-team (free) Apple ID is capped at:

- **3 apps signed at once** (AltStore itself counts as one, so effectively 2 more
  alongside it — plenty for a single personal app).
- **Roughly 10 new App IDs per rolling 7 days.**
- Signatures **expire after 7 days** (vs. a year for a paid account).
- No push notifications, no in-app purchases — both already excluded by `CLAUDE.md`
  regardless of signing tier.

The App-ID-per-week cap is the one worth actively avoiding, and the fixed bundle
identifier does that automatically: every re-sign and every rebuilt `.ipa` reuses the
*same* App ID (`com.epavone.breviarium`), so ordinary weekly use never registers a new
one. It would only matter if the bundle ID ever changed, which `CLAUDE.md` now rules out.

## 7. After installing: the on-device check (alpha M6, Betas 1 to 3)

A few minutes on the phone after each fresh install, to confirm the build works end to end.
Every item has a matching automated UI test on CI; this is the on-device confirmation.

1. **Today opens.** The date line on page 1 reads today's date (*Dies ...*), and the
   footer shows today's short date on the right.
2. **Pages flow like a book.** Swipe left: the footer's *Page N of M* counts up, and a
   paragraph cut at the bottom of one page continues at the top of the next.
3. **Table of contents.** Tap the red list icon under the day title, pick a section, and
   it opens on the page where that section starts.
4. **Settings, gear icon, top left:**
   - *Sacerdos vel diaconus adest* switches *Domine, exaudi orationem meam* to *Dominus
     vobiscum* (Oratio and Conclusio).
   - *Rubricae* off hides the red rubrics.
   - *Text size* XXL: the text re-flows onto more pages and you stay at the same place.
   - *Scrolling* Vertical: one continuous scroll. Back to Horizontal afterwards.
   - *Page turn* Page curl: pages turn like a book's.
   - *Psalterium* Pii XII: the psalms change to the Pius XII translation, with their
     titles. Back to Vulgata afterwards.
5. **Dates.** The chevrons (top right) move a day back and forward. Tapping the date line
   or the footer date opens *Jump to date*; pick e.g. Palm Sunday and check the title.
6. **Offline.** Turn on Airplane Mode and relaunch: everything still works.
7. **Landscape.** Rotate the phone: the pages re-flow to the wider layout.
8. **English (Beta 1).** Turn on *English translation*:
   - Portrait: psalms, antiphons, hymn stanzas, versicles and responses show Latin left and
     English right; the chapter and collect show Latin, then English below.
   - Landscape: the chapter and collect are side by side too.
   - Swipe through the whole hour, with *Page turn* slide and then page curl: both columns
     continue from page to page, and no heading or psalm title is left alone at the
     bottom of a page.
   - *Scrolling* Vertical: the same two columns in one scroll.
   - *Psalterium* Pii XII: each psalm's English is shown whole beside its Latin.
   - Turn English off again: Latin alone, full width.
9. **The hours (Beta 2).**
   - **Launch hour.** The app opens on the hour for the time of day: Lauds until 09:00,
     Terce until 12:00, Sext until 15:00, None until 17:00, Vespers until 20:00, and
     Compline after that.
   - **Hour picker.** Tap the hour name at the top. The list shows *Ad Laudes* to *Ad
     Completorium*, with a red check mark on the current hour. Pick each hour in turn and
     check that its title (e.g. *Ad Primam*) appears in the top bar and on page 1.
   - **Lauds:** the psalms, the Benedictus with its antiphon, and any commemorations after
     the collect.
   - **Prime:** the Athanasian Creed on Trinity Sunday, and *Pretiosa* and *De Officio
     Capituli*. There is no Martyrology; it becomes an hour of its own in a later beta.
   - **Terce, Sext and None:** the hymn, three psalms under one antiphon, the chapter with
     its short responsory, and the collect.
   - **Compline:** the short lesson, the psalms, the Nunc dimittis, the collect *Visita*
     and the Marian antiphon of the season. On Holy Saturday it takes its own short form.
   - **Dates with the picker:** move a day on with the chevrons; the hour you picked stays.
   - **Settings still apply** to every hour: English, the psalter, priest, rubrics, text
     size, scrolling and page turn.
10. **Matins (Beta 3).**
   - **The icon.** The Home Screen shows the illuminated B.
   - **Launch hour.** Between midnight and 05:00 the app opens on *Ad Matutinum*; it heads
     the hour picker.
   - **The shape.** The invitatory (the antiphon repeated through Psalm 94), the hymn,
     then *Nocturnus I*, *II* and *III* on a I or II class day (e.g. 1 November), or one
     *Ad Nocturnum* on a feria or III class day, and the *Te Deum* when said.
   - **Lessons.** Each starts with a small grey *Lectio i* line and its source, then the
     text as one paragraph; the responsory follows. The table of contents jumps to each
     nocturn, and no *Lectio* line or reference is left alone at the foot of a page.
   - **English.** Portrait: the lessons show Latin, then English below; landscape: side
     by side. The responsories are paired.
   - **Tenebræ.** Holy Thursday to Holy Saturday: no invitatory or hymn, and the collect
     alone at the end, *sub silentio*.
   - **The line under the title.** On a day with a commemoration, Lauds shows e.g.
     *Commemoratio ad Laudes tantum: …* and Matins *Tempora: …*; Vespers and Compline
     show none.

## Sources

Researched 2026-09-16, not from memory, since this space moves fast. Section 3 was
re-researched the same day after the first draft's tray-icon instructions turned out to
be wrong (see the note at the top of that section):

- [Sideloadly](https://sideloadly.io/index.html) and its [FAQ](https://sideloadly.io/faq.html)
- [AltStore: How to Install (Windows)](https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows)
- [AltServer release notes](https://faq.altstore.io/release-notes/altserver) (confirms
  current iOS 26.x compatibility, and the Shift-click "Sideload .ipa…" tray shortcut
  added in AltServer 1.5)
- [AltStore/AltServer#989](https://github.com/rileytestut/AltStore/issues/989) — the FAQ
  itself had this wrong at one point (said "Start", not "Shift"); cross-checked against
  the release notes above before trusting it
- [SideStore FAQ](https://docs.sidestore.io/docs/faq)
- Apple developer forum threads on free-account App ID/app-count limits
