# Roadmap to 1.0

Agreed on 25 September 2026, after Beta 2's release. Beta 3 was released on 26
September, Beta 4 on 27 September and Beta 5, the Dominican rite
([`Beta_5_plan.md`](Beta_5_plan.md)), on 3 October; Beta 6 is next, once its sources are
confirmed. The picture in the README is
[`images/roadmap.svg`](images/roadmap.svg), drawn by `scripts/roadmap-svg.py`. Each beta
still gets its own plan document (`Beta_N_plan.md`) and approval before any work starts.

![Roadmap](images/roadmap.svg)

## The order, and why

What Divinum Officium (DO) contains decides most of it. DO gives us an oracle: the engine
is checked against DO's own output for every day from 2025 to 2040. Whatever DO contains
can be checked that way, and whatever it lacks cannot.

| Beta | Contents | In DO? | Depends on |
|---|---|---|---|
| **Beta 3** | **Matins**: the three nocturns, lessons and responsories, the *Te Deum*, and the 1960 rules for shortening Matins. **The new app icon**, designed by the user (specs in [`icon-spec.md`](icon-spec.md)). **The title block's commemoration line** (*Commemoratio ad Laudes tantum: …*), carried over from Beta 2. | Yes | Nothing |
| **Beta 4** | **The Little Office of Our Lady** (Roman), **the Office of the Dead**, and **the Martyrology** as an "hour" of its own in the picker; a small dot of the day's **liturgical colour** in the calendar. | Yes, with English | Matins, for their Matins |
| **Beta 5** | **The Dominican rite**: DO's *Ordo Prædicatorum - 1962*, with its own calendar, saints and commons. *Ritus: Dominicanus* becomes selectable. | Yes | Matins; the rite plug-in, built here for the first time on a rite that can be checked |
| **Beta 6** | **Ambrosian Compline** (revised 8 October 2026), a standalone, precisely named office from Church of Ambrose's 1957 Compline and the *Kalendarium Ambrosianum*, with the provenance model ([`ambrosian-sources.md`](ambrosian-sources.md), plan [`Beta_6_plan.md`](Beta_6_plan.md)). Also: English side by side throughout but for the Matins lessons, and rubrics that weren't red. | **No** | The sources (received 8–9 October); the rite plug-in, proven in Beta 5 |
| Blocked | **The full Ambrosian office** (the 1957 *Breviarium Ambrosianum*, four volumes, with its calendar). | No | A complete primary source, which isn't available digitally |
| **1.0** | A release pass: check every hour and rite on the phone, verify landscape, add hyphenation at the largest text size, then freeze. Then the App Store release (planned since 6 October 2026; its prerequisites are in `CLAUDE.md`). | | Everything above; the paid Apple Developer Program |
| After 1.0 | Possible: the Monastic office (DO's *Monastic - 1963*), votive offices where the 1960 rubrics allow them, and the Ambrosian Office of the Dead and Little Office (deferred 8 October 2026, once their sources can be prepared). | Partly | |

- **Matins first:** it completes the Roman office, and both the Little Office and the
  Dominican rite reuse it.
- **The Dominican rite before the Ambrosian:** DO lets us check that the second-rite
  plug-in really works (`CLAUDE.md`, *Rite abstraction*) before we build the rite that can't be
  checked against DO.
- **The Ambrosian rite** can't be checked against DO. Beta 6's plan will set out how it is
  checked instead: sample days checked by hand against the source, with tests that
  record them.

## Decisions (25 September 2026)

1. **Order:** as above. This replaces the earlier order (Beta 3 for the Ambrosian and
   Dominican rites, Beta 4 for Matins) in `Beta_1_plan.md` and `PLAN.md`.
2. **The Martyrology and the Office of the Dead** come with the Little Office in Beta 4.
3. **Ambrosian source:** not chosen yet. It will probably be an online website or text
   source. It is bundled at build time like DO's texts, so the app stays fully offline.
4. **Dominican English:** use DO's Dominican English where DO has it. Where it doesn't
   (DO has English for the Dominican seasonal texts but none for its saints), use the
   Roman English for texts that match the Roman ones. Anything still untranslated shows
   in Latin only.
5. **The next release is 1.0**, at the end of the table above.
6. **The icon** is designed by the user, to the specs in [`icon-spec.md`](icon-spec.md).
7. **The liturgical colour in the calendar** (added 26 September 2026, for Beta 4): each
   day in the *Jump to date* calendar gets a small dot of its liturgical colour. The
   engine already classifies the colour (`LiturgicalColorClassifier`); Beta 4's plan
   settles the exact colours on black and which office's colour a day shows.

## Open questions for later plans

- **Beta 5:** does DO's Dominican office have its own psalter distribution and hymn
  texts, or does it borrow the Roman ones? *Partly answered (27 September):* it has its
  own calendar (`Kalendaria/OP1962.txt`) and its own Tempora, Sancti and Commune
  (579 Latin files), but it reads the Roman psalter files, choosing `…OP` sections where
  they exist, and DO runs it through the Roman engine with about 30 Dominican branches.
  *Answered in Beta 5:* see [`rubrics-op1962.md`](rubrics-op1962.md).
- **Beta 6:** answered in part by the user's research (1 October 2026,
  [`ambrosian-sources.md`](ambrosian-sources.md)). There is no complete pre-conciliar
  Ambrosian breviary online. Three partial sources exist: Compline (a typeset PDF), the
  Office of the Dead (inside a book with the Mass of the Dead; it needs OCR) and the Little
  Office (LaTeX). Each one's edition, completeness and redistribution rights are still to
  be confirmed. The repository is public, so no source is committed until its rights are
  clear.
- **Beta 7:** whether the Ambrosian source includes the Little Office, or it needs a
  second source.
