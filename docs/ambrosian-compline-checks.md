# Ambrosian Compline: the user's checks

`docs/Beta_6_plan.md` §8: the work went ahead on Claude's reading of the sources, and every
judgement is collected here, to check in one sitting at the end of B6-M5, before Church of
Ambrose's review. A misreading found here is a data edit and a test, not a redesign.

Each check says what to look at and, in **bold**, what needs an answer.

## 1. The reading order of the two-column pages

`docs/rubrics-ambrosian-compline.md` §2 gives the order step by step, with the pages. Two
places were a judgement, as the pages set them in two columns (HI.5–6 and the same pages of
the other parts):

- **The short responsory** (HI.5): *R. br. Pax multa diligentibus.* — *Iterum:* — *Pax multa
  diligentibus \* Legem tuam, Domine.* — ℣. *Et non est illis scandalum.* ℟. *Legem tuam,
  Domine.* — ℣. *Gloria Patri…* ℟. *Pax multa diligentibus \* Legem tuam, Domine.*
  **Is this the order?**
- **The canticle** (HI.5–6): *Ant. Salva nos.* (incipit) — *Nunc dimittis* with *Gloria
  Patri… Sicut erat…* — *Iterum:* its first verse — *Ant. Salva nos, Domine, vigilantes:*
  ℟. *Custodi nos dormientes:* ℣. *Ut vigilemus in Christo,* ℟. *Et requiescamus in pace.*
  **Is this the order, and is the full antiphon after the repeated first verse?**

## 2. The corrections

`data/ambrosian/corrections.txt`: 36 misprints corrected, each with its page and, where it
isn't obvious, the reason. Read the `misprint` lines and **strike any that aren't
misprints.** The longest is in the *æstiva secunda* festal rubric (AII.6), where a line was
dropped in typesetting (*sed clesiis Divina tunc peragenie*): it is restored from *hiemalis
prima*'s reading.

Four readings look wrong but may be the Ambrosian text, so they are **shown as printed**
until you decide:

| Where | Printed | Perhaps | **Correct it?** |
|---|---|---|---|
| *Lux alma, Christe*, HII.2 | *Ne fraude mentes óbruat.* (full stop mid-sentence) | a comma | |
| Psalm 30, HI.3 | *Educes me laqueo hoc* | *de laqueo* (Vulgate) | |
| Psalm 90, HI.4 | *et dena millia a dextris tuis* | *decem millia* (Vulgate) | |
| Psalm 90, HI.4 | *Quoniam ipse liberabit me* | *liberavit* (Vulgate) | |

Two more, seen in the screenshots, now settled (10 October 2026):
- ℟. *Amen* without a full stop (after *Benedicat et exaudiat nos Deus*, *Fidelium
  animæ*, *Indulgentiam*): corrected as misprints, with the full stop the other *Amen*s
  have.
- *a Nativitate **Dòmini*** (the rubric over *Alma Redemptoris*): no longer shown, as the
  rubrics on when each antiphon is said aren't (the user's ruling).

## 3. The expansions and rulings

Editorial, each marked in `corrections.txt`:

- *Kyr. kyr. kyr.* is written out *Kyrie, eleison.* three times (no accents added, the
  source's rule).
- *Gloria Patri… Sicut erat…* after the *Nunc dimittis* is written out as after the psalms.
- *Ant. Salva nos.* before the canticle stays an incipit, as printed.
- Priest off (your rulings): ℣. *Domine, exaudi orationem meam* ℟. *Et clamor meus ad te
  veniat* for *Dominus vobiscum*; one *Confiteor* (the hebdomadary's, with St Ambrose,
  without *et vobis, fratres* and *et vos, fratres*), then *Misereatur nostri omnipotens
  Deus: et, dimissis peccatis nostris, perducat nos ad vitam æternam.* ℟. *Amen.* and
  *Indulgentiam* as printed.
- The movable feasts' names in the title block, written out from the *Tabula*'s headings:
  *Dominica in Septuagesima*, *Dominica I Quadragesimæ*, *Ascensio Domini*, *Corpus
  Christi*, *Dominica I Adventus*.
- By the J→I rule, *Hallelujah* becomes ***Halleluiah***. **Keep it, or keep
  *Hallelujah* as an exception?**

## 4. The calendar

`docs/ambrosian-compline-checks-tables.md`, *Check 4*: every *Kalendarium* entry, with its
page, as transcribed, and what the app does with it in 2026 (the part, festal or ferial,
the title block). **Compare it with the scans** (pp. XV–XVIII).

**The calendar is the Missal's.** The whole scan (10 October) shows that the calendar,
the paschal tables and the general rubrics are the front matter of the 1954 *Missale
Ambrosianum*, not of the 1957 breviary. The docs, `NOTICE.md` and About now say so. **Is
there any difference you know of between the 1954 Missal's calendar and the 1957
breviary's?**

Settled by the Missal's *Series Missarum* and *Rubricæ generales*
(`rubrics-ambrosian-compline.md` §3.5), and no longer questions:
- the ***Triduum Litaniarum*** is the Monday to Wednesday after the Sunday after the
  Ascension;
- **Corpus Christi** is a *Solemnitas*, so festal, and so is its octave;
- **St Joseph and the Annunciation in Holy Week** are not kept (Holy Week is privileged);
- **Sundays**: every Sunday has its name, gives way only to a Solemnity of the Lord (with
  the Sunday commemorated), and a saint falling on it moves to the Monday; St Joseph on a
  Sunday of Lent is kept;
- the **colours**, now shown in *Jump to date* (§3.7).

Choices the sources still don't make. **Confirm or correct each:**

1. The **Monday to Saturday after Pentecost** take *Regina cæli* (neither antiphon's
   rubric names them) and *æstiva prima*'s festal form.
2. **Easter week** keeps no saint (Friday 10 April 2026 is *Feria VI in Albis*, not
   St Anselm): § 3 doesn't list it among the privileged days. **Pentecost week** and
   **Corpus Christi's octave** do keep their saints.
3. The **Sacred Heart** and the **Holy Family** take the ferial form: the *Series* calls
   them *Festum*, not *Solemnitas*.
4. **A literal § 3 impedes I class feasts.** On a privileged day no saint is kept, so the
   Immaculate Conception on the Friday of the 4th week of Advent (8 December 2023 and
   2028) is not kept, and its Compline is ferial. **Is it kept, or moved?**
5. **A literal § 2 moves every saint off a Sunday**, even when the Monday impedes it.
   Examples: All Saints on Sunday 1 November 2026 moves to Monday 2 November, and All Souls
   becomes its commemoration; St John on Sunday 27 December 2026 is impeded by the Holy
   Innocents and not said; the Conversion of St Paul on Sunday 25 January 2026 is impeded
   by the Holy Family. **Are these right?**
6. A **lower feast** on that Monday is commemorated; an impeded saint is dropped.
7. A **Sunday from 2 to 5 January** is named *Dominica post Nativitatem Domini*.
8. The **octave of Christmas** (26–31 December) and **1 January** take the festal form;
   the Epiphany's days are *Sol. Dom.* in the calendar already.
9. **Our Lady's feasts** for the festal form are 2 February, 25 March, 2 July, 16 July,
   5 August, 15 August, 8 September, 12 September, 15 September, 21 November and
   8 December: not St Anne, St Joachim or St Joseph. St Anne and St Joachim are white.

The same file has every day of 2026 (part, form, colour, antiphon, title), to read
through.

## 5. The movable feasts

`docs/ambrosian-compline-checks-tables.md`, *Check 5*: the computed Septuagesima, Lent,
Easter, Ascension, Pentecost, Corpus Christi and Advent for 1955–2000 against the
*Tabella*, and for 2025–2040 and 2044. They match in every year but one: 1995's Advent is
printed **19** November; the rule (*Dominica prima post Festum sancti Martini*) gives
**12** November, since 11 November 1995 was a Saturday. **Is it a misprint?**

## 6. Screenshots of every form

From App CI's `snapshots` artifact, `testAmbrosianComplineForms`, every page of:

| Capture | Date | What it shows |
|---|---|---|
| `b6-aestiva2-ferial` | Tuesday 2 June 2026 | *æstiva secunda*, ferial: the *preces*, *Inviolata* |
| `b6-aestiva2-sunday` | Sunday 7 June 2026 | festal: straight from the *Capitulum* to *Dominus vobiscum* |
| `b6-hiemalis2-lent` | Tuesday 24 February 2026 | Lent: *Lux alma* and *Te lucis*, *Laus tibi*, *Amen.*, *Salve, Regina* |
| `b6-hiemalis2-goodfriday` | Good Friday, 3 April 2026 | no Marian antiphon |
| `b6-aestiva1-easter` | Tuesday 7 April 2026 | *æstiva prima*, festal, *Regina cæli* |
| `b6-hiemalis1-nopriest` | Thursday 15 January 2026 | priest off: *Domine, exaudi*, one *Confiteor*; *Alma Redemptoris* |
| `b6-hiemalis1-bvm` | Saturday 21 November 2026 | the Presentation of Our Lady, festal; *Ave, Regina cælorum* |
| `b6-ambrosianus-setting` | | Settings: *Ritus → Ambrosianus*, *Completorium Ambrosianum* |

**Check each against the PDFs** of its part.
