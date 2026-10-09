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
the title block). **Compare it with the photographs** (pp. XV–XVIII).

Choices the sources don't make (`rubrics-ambrosian-compline.md` §3). **Confirm or correct
each:**

1. The **Monday to Saturday after Pentecost** take *Regina cæli* (neither antiphon's
   rubric names them) and *æstiva prima*'s festal form.
2. The ***Triduum Litaniarum*** is the Monday to Wednesday after the Sunday after the
   Ascension (in 2026, 18–20 May), with the ferial form.
3. **Corpus Christi** takes the festal form, as a Solemnity of the Lord.
4. **St Joseph and the Annunciation in Holy Week** take the ferial form. (Are they
   transferred in the Ambrosian rite? Not in these sources.)
5. On a **Sunday**, the title block names the *Kalendarium*'s feast only if it is a
   Solemnity of the Lord or of the I or II class; otherwise *Dominica*.
6. The **octave of Christmas** (26–31 December) and **1 January** take the festal form;
   the Epiphany's days are *Sol. Dom.* in the calendar already.
7. **Our Lady's feasts** for the festal form are 2 February, 25 March, 2 July, 16 July,
   5 August, 15 August, 8 September, 12 September, 15 September, 21 November and
   8 December: not St Anne, St Joachim or St Joseph.
8. **The weekdays of Easter week and Pentecost week** show the *Kalendarium*'s saint in
   the title block (Friday 10 April 2026: *Privil. / S. Anselmi Episc. et Conf.*), since
   the sources don't say how the octaves take precedence. The hour itself is the same
   (all of *æstiva prima* is festal). **What should these days be called?**

The same file has every day of 2026 (part, form, antiphon, title), to read through.

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
