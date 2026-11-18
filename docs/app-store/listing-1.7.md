# App Store Connect: version 1.7

Drafted 2026-11-17 for App Store Connect → Breviarium → iOS App → 1.7, every field on the
version page and on *App Information*. Each block is ready to paste; its length is checked
against Apple's limit in the table at the end. The app is not on the App Store yet (1.3
was rejected under 4.2 on 2026-10-28), so 1.7 is its first release.

Rules this follows (`CLAUDE.md`, *Before the App Store release*):
- the name is *Breviarium 1962: Divine Office*; the name on the phone stays *Breviarium*;
- the description says plainly, at the start, that this is the 1962 office and not the
  current Liturgy of the Hours (Universalis's request, 2026-10-16). It doesn't name
  Universalis: App Review's guideline 2.3.7 keeps other apps' names out of the metadata.
  The support page points people looking for the current office there;
- non-trader under the EU Digital Services Act; privacy label *Data Not Collected*.

## App Information (shared by every version)

| Field | Value |
|---|---|
| Name (30) | Breviarium 1962: Divine Office |
| Subtitle (30) | see below |
| Primary category | Reference (unchanged, if already set) |
| Secondary category | Books (optional) |
| Content rights | Contains third-party content, and you have the rights to use it: **Yes** |
| Age rating | 4+ (no change: no objectionable content, no web access, no user content) |
| Privacy Policy URL | https://breviarium.eduardopavone.eu/privacy/ |

### Subtitle (30)

```
The traditional Latin office
```

## Version 1.7

### Promotional text (170)

```
The 1962 Divine Office, all eight hours in Latin with English beside it. Now on iPhone Duo: open it on its side and the office opens like a book. Free and fully offline.
```

### Description (4,000)

```
Breviarium is the traditional Divine Office as it was prayed before the reform of 1970: the Breviarium Romanum under the 1960 rubrics, in its 1962 edition. It is not the current Liturgy of the Hours.

The app computes the office itself for any date, on your device. There is no account, no internet connection and no expiry date: any day, in any year, from Matins to Compline.

THE OFFICE
• All eight hours: Matins with every lesson, Lauds, Prime, Terce, Sext, None, Vespers and Compline.
• The Roman Martyrology, read on the eve as tradition has it, after Prime.
• The Little Office of Our Lady and the Office of the Dead.
• The Roman office under the 1960 rubrics with the Universal Calendar, the Dominican office of 1962 (Ordo Prædicatorum), and Ambrosian Compline from the Ambrosian breviary of 1957.
• The Vulgate psalter, or the Pius XII psalter as an option.
• The proper versicle, with or without a priest or deacon present.

LATIN AND ENGLISH
• The Latin text with its accents and ligatures, as in a printed breviary.
• An optional English translation side by side: the Douay-Rheims for Scripture, and Divinum Officium's English for the rest.
• Rubrics in red, which you can hide.

A BOOK, NOT A WEB PAGE
• The text is set like a printed book and turns page by page, with a page curl or a slide, or scrolls if you prefer.
• On iPad, the pages lie side by side like an open book, with the Latin on the left page and the English on the right.
• On iPhone Duo, the office fills the open screen. Hold it on its side and it opens into two pages too. Folded, it is the iPhone app.
• The Kalendarium shows a month at a time, each day with its class, its name and its liturgical colour, and opens any day's office.

MADE TO BE PRAYED
• It opens on the hour for the time of day.
• Home Screen and Lock Screen widgets show the day, its colour and the hour, and open it.
• Optional reminders for each hour and the Martyrology, at the times you choose, scheduled on the device itself. They are off until you turn one on.
• Keep screen awake, so the screen doesn't dim while you pray.
• Eight colour themes, dark and light, six typefaces, ten app icons, and a text size that scales the whole page.

FREE, OFFLINE, PRIVATE
Breviarium is free, with no ads, no subscriptions and no in-app purchases. It collects no data at all: no analytics, no tracking, nothing sent anywhere. It is free software under the GNU General Public License, and its source is public.

The Roman and Dominican texts come from Divinum Officium, and the app's office is checked against it for every day from 2025 to 2040. Ambrosian Compline is used with the permission of Church of Ambrose.

Made by one person, for the Church's prayer. Corrections are welcome through the support page.
```

### Keywords (100, commas, no spaces)

The name's words (Breviarium, 1962, Divine, Office) are indexed already, so they aren't repeated.

```
breviary,latin,catholic,traditional,hours,prayer,vespers,compline,matins,psalter,dominican,ambrosian
```

### Support URL

```
https://breviarium.eduardopavone.eu/support/
```

### Marketing URL

```
https://breviarium.eduardopavone.eu/
```

### Version, copyright

| Field | Value |
|---|---|
| Version | 1.7 (build 9 + 100 on TestFlight, i.e. the build `testflight.yml` uploads) |
| Copyright | 2026 Eduardo Pavone |
| What's New | not shown for an app's first version; for 1.8, from `docs/releases/` |

### Media (from `promo-1.7/`)

| Slot | Files |
|---|---|
| iPhone 6.9" | `Breviarium-1.7-iphone.zip` (10, 1320x2868); app preview `app-preview.mp4` (886x1920) |
| iPhone 6.3" | `Breviarium-1.7-iphone-6.3.zip` (10, 1206x2622), or let it scale from 6.9" |
| iPad 13" | `Breviarium-1.7-ipad.zip` (9, 2752x2064); app preview `app-preview-ipad.mp4` (1600x1200) |
| iPhone Duo, outer | `Breviarium-1.7-duo-outer.zip` (10, 1398x2034) |
| iPhone Duo, inner | `Breviarium-1.7-duo-inner.zip` (10, 2007x2853) and `Breviarium-1.7-duo-inner-side.zip` (4, 2853x2007); if they share one slot of 10, keep the 4 on its side and 6 upright |
| Product page header | `creative/header.png` (3840x1646) |
| Search results | `creative/search.png` (3840x2560) |

## App Review Information

| Field | Value |
|---|---|
| Sign-in required | No |
| Contact | your name, phone and email (filled in App Store Connect; not kept in the repository) |
| Attachment | `app-preview-ipad.mp4`, the iPad's app preview (attached 2026-11-18): the spread turning, the Kalendarium, the hours and the themes, the screen recording asked for under 2.1 last time |

### Notes (4,000)

```
Thank you for reviewing Breviarium again. Version 1.3 was rejected under Guideline 4.2 (Minimum Functionality) on 28 October, on an iPad Air running the iPhone-only app. This version answers it.

WHAT THE APP IS
Breviarium is the Divine Office, the Catholic Church's daily cycle of prayer, in its traditional form of 1962, before the reform of 1970: the Roman office, the Dominican office and Ambrosian Compline, in Latin with an optional English translation. The office changes every day with the calendar, the feasts and their precedence; the app computes it on the device for any date, rather than shipping a fixed text or a dated ordo. That computation is the app's core: the result is checked against Divinum Officium, the reference implementation, for every day from 2025 to 2040.

SINCE 1.3
• Native iPad support. On iPad in landscape, the office is an open book of two facing pages; with English on, the Latin is on the left page and the English on the right.
• Visible menus: a settings button, the hour's title as a menu of the hours, a calendar button and day arrows.
• The Kalendarium: a month of days, each with its class, its name and its liturgical colour; any day opens its office.
• Home Screen and Lock Screen widgets, opening the hour shown.
• Optional reminders for each hour, local notifications scheduled on the device.
• iPhone Duo: the app fills the open screen, and on its side shows two facing pages.
• Keep screen awake, ten app icons, eight themes and six typefaces.

HOW TO TRY IT
1. The app opens on the hour for the time of day. Swipe sideways to turn pages.
2. Tap the hour's title (for example "Ad Vesperas") to choose another hour.
3. Tap the calendar button to open the Kalendarium and choose any day.
4. Tap the gear for Settings: Ritus (the rite and the office), English translation, theme, font, text size, reminders.
5. On iPad, turn it to landscape for the two-page spread, and turn on English translation for Latin and English on facing pages.
6. Widgets: add Breviarium from the Home Screen's widget gallery.
7. Reminders: Settings → Notifications; the app asks for permission only when a reminder is turned on.

EXTERNAL SERVICES
None. The app makes no network connections at all: no account, no analytics, no advertising, no crash reporting. All texts are inside the app. The privacy label is Data Not Collected. The widgets share the app's settings through an App Group on the device.

REGIONAL DIFFERENCES
None. The app is the same in every country and is in English and Latin only.

THIRD-PARTY CONTENT AND RIGHTS
• Latin and English texts of the Roman and Dominican offices: Divinum Officium, under the MIT licence; the notice is on the app's About screen.
• Scripture in English: the Douay-Rheims Bible, in the public domain.
• Ambrosian Compline and its calendar: Church of Ambrose, used with the owners' written permission (11 October 2026); credited on the About screen.
• Bundled fonts: SIL Open Font License. App icons: drawn by the developer from public-domain images, one under CC BY 2.0 and one under CC BY-SA 4.0, credited on the About screen.
• The design of the reading view resembles the Universalis app, which publishes the current Liturgy of the Hours; Universalis Publishing confirmed in writing (16 October 2026) that they are happy with it, as this app gives a different liturgy and doesn't present itself as theirs.
• The app itself is free software under GPL-3.0; the source is public at https://github.com/ColdFrozenYeti/Breviarium

Contact: epavone06+breviarium@gmail.com
```

## Lengths

Counted with Python's `len` on each block above (2026-11-17).

| Field | Limit | Length |
|---|---|---|
| Name | 30 | 30 |
| Subtitle | 30 | 28 |
| Promotional text | 170 | 169 |
| Description | 4,000 | 2,754 |
| Keywords | 100 | 100 |
| Review notes | 4,000 | 3,541 |
