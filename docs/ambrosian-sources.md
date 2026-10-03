# Ambrosian Rite Source Debrief

**Project:** Breviarium  
**Prepared for:** Claude  
**Updated:** 30 September 2026  
**Status:** Working source assessment; the formats of the three partial sources are now known, but their exact bibliographical metadata and coverage still need to be entered.

## Executive summary

The earlier assumption that a complete pre-Vatican II Ambrosian breviary could be obtained as an online PDF is incorrect. Eduardo has consulted an expert and been told that no complete PDF breviary is available online.

Eduardo has, however, identified three usable partial sources in different formats:

- the Ambrosian **Compline** is a properly typeset, modern-format PDF;
- the Ambrosian **Office of the Dead** is contained in a larger book together with the **Mass of the Dead** and will require OCR; and
- the Ambrosian **Little Office** is available as a LaTeX source file.

These sources make limited, self-contained Ambrosian implementations possible. They do **not** provide enough material to implement or advertise the complete Ambrosian Divine Office across the liturgical year.

The development plan should therefore separate:

1. **Available standalone Ambrosian offices**, which can be implemented after their editions and completeness have been verified; and
2. **The complete Ambrosian breviary**, which remains blocked until a complete primary source can be obtained and digitised.

## Intended historical scope

The eventual full implementation is intended to represent the traditional, preconciliar Milanese Ambrosian Office, with the **1957 recension** as the target baseline.

The complete target source previously identified is:

> *Breviarium Ambrosianum a Carolo Archiepiscopo editum, Andreae C. Card. Ferrari et denuo Joannis Baptistae Montini Archiepiscopi iussu impressum*. Milan: Daverio, 1957.

It comprises four volumes:

1. **Pars hiemalis I:** first Sunday of October to the beginning of Lent;
2. **Pars hiemalis II:** first Sunday of Lent to Holy Saturday;
3. **Pars aestiva I:** Easter to the octave of Pentecost; and
4. **Pars aestiva II:** first Sunday after Pentecost to the first Sunday of October.

A complete implementation would also require the relevant **1957 Ambrosian calendar**, full rubrics, ordinary, Ambrosian psalter, temporale, sanctorale, commons, proper texts and appendices. Contemporary Milanese *Ordines* or directoriums would be highly desirable as independent test oracles for occurrence, concurrence, commemorations and transfers.

None of that wider corpus should be inferred from the three smaller offices now available or expected.

## Current source inventory

| Material | Status | What must still be confirmed |
|---|---|---|
| Complete 1957 four-volume *Breviarium Ambrosianum* | **Unavailable digitally** | Access to a physical set, a private scan or permission to photograph one |
| *Kalendarium Ambrosianum* / authoritative 1957 calendar | **Not yet secured** | Exact edition and complete calendar tables |
| Annual Milanese *Ordo* or directorium | **Not yet secured** | Ideally one or more examples between 1957 and 1962 |
| Ambrosian Compline | **Available as a properly typeset PDF** | Exact title, publisher, year, edition, textual basis, page coverage and whether all daily/seasonal variants are present |
| Ambrosian Office of the Dead | **Available inside a combined Office and Mass of the Dead book; OCR required** | Exact book title, publisher, year, edition, page range of the Office, completeness and relationship to the 1957 usage |
| Ambrosian Little Office | **Available as LaTeX source** | Exact title and edition represented by the transcription, completeness, variants, provenance and redistribution rights |

“Available” means that source material is available to Eduardo; it should not yet be treated as critically verified or implementation-ready until the bibliographical and coverage checks below are complete. File format is not evidence of liturgical authority: the modern PDF and LaTeX transcription must still be tied to identifiable editions.

## Immediate implementation decision

Do **not** implement or expose a general “Ambrosian Rite” option as though the complete daily office were available. That would overstate the app's coverage.

Instead, the recommended near-term scope is:

- **Ambrosian Compline** as a specifically labelled standalone office;
- **Ambrosian Office of the Dead** as a standalone office;
- **Ambrosian Little Office** after the LaTeX source is audited, compiled and tied to an identifiable edition; and
- the underlying Ambrosian rite/provider architecture, kept disabled or marked incomplete for the full temporal and sanctoral cycle.

If the roadmap currently calls a release “Ambrosian Rite,” rename or redefine that milestone as something such as **Ambrosian Foundations** or **Ambrosian Offices**. A full Ambrosian release should remain a separately blocked milestone.

## Rules Claude must observe

1. **No Roman fallback for missing Ambrosian content.** Do not fill absent texts, psalms, antiphons, hymns, chapters, versicles or rubrics from the Roman breviary unless a primary Ambrosian source explicitly directs their use.
2. **Do not assume the Roman psalter.** The traditional Ambrosian psalter and its distribution are distinct. Existing Roman Vulgate and Pius XII psalter settings must not silently govern Ambrosian offices.
3. **Do not use the modern Ambrosian Liturgy of the Hours** to reconstruct a preconciliar office.
4. **Do not extrapolate a complete rite from Compline.** A complete Compline source proves only the contents and rules of Compline.
5. **Do not infer calendar rules from the Little Office or Office of the Dead.** These are self-contained offices, not substitutes for the temporal and sanctoral cycles.
6. **Do not advertise completeness prematurely.** The UI and documentation must distinguish “Ambrosian Compline” or another named office from “the Ambrosian Divine Office.”
7. **Preserve provenance.** Every transcribed unit should remain traceable to an edition and page or folio.
8. **Preserve the source text.** Normalisation for search or display should not overwrite the diplomatic transcription. Editorial expansions and corrections must be recorded separately.

## Source intake requirements

For each of the three offices, Eduardo should provide:

- scans or photographs of the **title page**, publication information, imprimatur and table of contents;
- every page containing rubrics or liturgical text, including introductory and concluding material;
- the cover and any page showing an edition, date or diocesan approval;
- colour images at approximately **300–400 dpi** for any scanned source, photographed or scanned flat and square where possible;
- an explicit note identifying any missing, illegible or duplicated pages;
- the source's ownership and copyright/licensing position;
- any OCR or transcription as a separate derivative, never as a replacement for the page images; and
- the file's provenance: where it was found, who supplied it and whether redistribution is permitted.

Before transcription begins, record the following metadata:

```yaml
title: ""
short_title: ""
office: "compline | office_of_the_dead | little_office"
rite: "ambrosian"
language: "la"
source_format: "typeset_pdf | scanned_book | latex"
extraction_method: "embedded_text | ocr_then_proofread | latex_source"
source_scope: ""
publication_place: ""
publisher: ""
year: null
edition_statement: ""
ecclesiastical_approval: ""
physical_or_digital_source: ""
page_count: null
missing_pages: []
coverage_notes: ""
rights_status: "unknown"
redistribution_allowed: false
```

Raw source images should not be committed to the public repository until their redistribution status is clear. Derived structured data also needs an explicit source entry in the repository's source manifest.

### Compline: typeset PDF workflow

- Preserve the original PDF unchanged as the source artifact.
- Check whether it contains a valid embedded text layer before attempting OCR. Prefer direct text extraction when the encoding is sound.
- Inspect copied text for broken ligatures, accents, symbols, rubrical markers and font-encoding substitutions.
- Retain PDF page numbers in the structured data so every passage can be checked against the rendered page.
- Record whether the PDF is itself an authorised edition or a modern re-typesetting of an older source. If it is a re-typesetting, identify the edition from which it was prepared.

### Office of the Dead: combined-book OCR workflow

- Preserve the entire combined book, including the title page, publication details, contents, rubrics, the Office of the Dead and the Mass of the Dead. The Mass need not be implemented in this app, but it belongs to the source's identity and may contain shared introductory rubrics.
- Record the exact page range containing the Office before extraction.
- OCR the relevant pages and then proofread them manually against the page images. OCR output is a working transcription, not the authority.
- Expect Latin-specific errors involving `æ/œ`, `I/J`, `u/v`, ligatures, abbreviations, punctuation, versicle and response signs, rubric colours, and words divided across lines.
- Keep at least three layers distinct: immutable page images, raw OCR and corrected transcription.
- Mark text belonging only to the Mass of the Dead so that it cannot enter the Office data accidentally.

### Little Office: LaTeX workflow

- Preserve the original `.tex` file and any included assets, custom style files, bibliographical notes and build instructions.
- Compile it once to a reference PDF and compare the compiled result with the source structure.
- Inspect macros and conditional commands before extracting content; liturgical variants may be encoded in commands rather than visible as continuous prose.
- Prefer parsing or manually mapping the semantic LaTeX source over OCRing the compiled PDF.
- Determine whether the LaTeX is an original authorised edition or a modern transcription. Record the printed source and edition behind it.
- Keep editorial commands and layout markup separate from the liturgical text when converting it into app data.

## Recommended data and product structure

The code should represent **rite**, **office family**, **edition** and **coverage** separately. “Ambrosian” alone is not a sufficient completeness claim.

A useful conceptual shape would be:

```text
Rite: Ambrosian
Edition baseline: 1957 traditional usage
Available modules:
  - Compline [typeset PDF; audit pending]
  - Office of the Dead [combined scanned book; OCR required]
  - Little Office [LaTeX source; audit pending]
Full office of the day:
  - unavailable
Coverage status:
  - partial
```

Each module should declare:

- its primary source edition;
- which hours or sections it contains;
- whether it varies by weekday, season or feast;
- what rubrical decisions it can make from the available source;
- what remains unsupported; and
- whether the module is safe to expose in production.

The UI should use precise names such as **Ambrosian Compline** rather than presenting a rite selector that leads users to expect Matins through Compline for every day of the year.

## Recommended delivery sequence

### 1. Audit the located sources

Do not begin by transcribing the first visible prayer. First establish whether each item is complete, traditional, Ambrosian, and compatible with the intended 1957 baseline.

### 2. Build the provenance and coverage model

Add edition metadata, page-level citations and explicit coverage flags before introducing Ambrosian text into the production data bundle.

### 3. Implement Ambrosian Compline

Extract from the PDF's embedded text layer if it is reliable; use OCR only if necessary. Proceed only after determining whether the source includes:

- every weekday form;
- Sunday and festal differences;
- seasonal variants;
- antiphons, psalms, hymn, chapter, responsory, canticle and concluding prayers;
- rubrics governing substitutions or omissions; and
- any interaction with the calendar.

If it contains only one form, label and implement that form narrowly rather than generalising it.

### 4. Implement the Office of the Dead

Treat it as an independent office, while preserving its provenance within the combined Office and Mass of the Dead book. OCR and manually proofread the Office pages, retain page-level references, and exclude Mass-only material from the app's Office data. Confirm exactly which hours are included and whether there are alternative forms, anniversary distinctions or rubrical dependencies.

### 5. Audit and implement the Little Office

Audit and compile the LaTeX source, then identify the underlying edition before converting its content into app data. Do not assume its distribution or seasonal changes match the Roman Little Office, and do not treat a clean LaTeX transcription as primary-source verification by itself.

### 6. Keep the full Ambrosian office blocked

The complete rite remains blocked until the four-volume breviary, calendar and rubrical material can be accessed. The architecture may be prepared, but missing liturgical content must not be invented.

## Testing expectations

Divinum Officium cannot serve as the oracle for these Ambrosian modules. Testing should instead use:

- direct page-by-page fixtures derived from the primary editions;
- hand-verified sample outputs for every documented variant;
- checks that every rendered text carries a valid source reference;
- negative tests ensuring Roman texts are not silently substituted; and
- review by someone competent in the traditional Ambrosian Rite before declaring a module complete.

For each module, create a finite coverage matrix before coding. For example:

| Variant dimension | Values evidenced by source | Tested |
|---|---|---|
| Weekday | To be determined | No |
| Liturgical season | To be determined | No |
| Feast/Sunday | To be determined | No |
| Commemoration or special rubric | To be determined | No |

## Open questions for Eduardo or the source expert

1. What is the exact title, date and textual basis of the modern-format Compline PDF?
2. What is the exact title, date and edition of the combined Office and Mass of the Dead book, and which pages contain the Office?
3. Do they represent the usage in force in 1957, or an earlier/later recension?
4. Are all rubrics and variants included, or only the ordinary text?
5. May the scans and/or transcriptions legally be bundled in a public application and repository?
6. Which printed edition was used to create the Little Office LaTeX file, and does the LaTeX include all dependencies and variants?
7. Can the expert provide access to, or identify a library holding, the complete 1957 breviary and calendar?
8. Would a physical copy be available for systematic photography or scanning?
9. Can one or more Milanese annual *Ordines* from approximately 1957–1962 be obtained for validation?

## Definition of completion

An individual Ambrosian module is complete only when:

- its precise edition and scope are documented;
- all relevant pages have been captured;
- every rubric affecting output has been encoded or explicitly declared unsupported;
- every text is traceable to its page or folio;
- all source-evidenced variants have fixtures and tests;
- no Roman or modern Ambrosian material is being used as an undocumented substitute; and
- the interface describes the module's coverage accurately.

The complete Ambrosian Rite is **not** complete merely because Compline, the Office of the Dead and the Little Office are available. It requires the full annual office corpus and its governing calendar and rubrics.
