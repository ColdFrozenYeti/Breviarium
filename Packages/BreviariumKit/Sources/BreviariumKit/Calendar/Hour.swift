import Foundation

/// One leaf of assembled Vespers content — formatting-free (`CLAUDE.md`: "No colours,
/// fonts, or spacing live in this model"). Each case carries an optional English
/// counterpart alongside its Latin text, matching this project's finding that DO's own
/// bundled `English/` tree already *is* Douay-Rheims wording for Scripture and DO's own
/// translation for everything else (`CLAUDE.md`'s "Douay-Rheims... for Scripture and
/// Divinum Officium's English for everything else" turned out to be one source, not two
/// to reconcile — see `DataBundle.english`'s doc comment). `nil` means no English is
/// available for this unit yet (English toggled off, or a not-yet-wired section) — the
/// app falls back to Latin-only width in that case, per `CLAUDE.md`'s visual spec.
///
/// English is wired per-case at the "whole unit" granularity `CLAUDE.md`'s alignment
/// rules call for on non-verse content (a rubric, a versicle/response pair, an
/// antiphon, a line of running prose). Psalm/canticle **verses** are a separate,
/// harder alignment problem — DO's Pius XII (Bea) Latin psalter divides some psalms
/// differently from the plain Vulgate/Douay-Rheims numbering English uses (confirmed
/// real: Bea's own `Psalm114.txt` is headed "pars prima," covering only what
/// Vulgate/Douay numbers as its *separate* Psalms 114 and 115) — the per-verse
/// `english` fields on `.verse` exist for when that's solved, not populated yet.
public enum Unit: Equatable, Sendable {
    /// A red italic rubric (do-format.md's `!text` marker, already stripped of the `!`).
    case rubric(String, english: String? = nil)
    /// do-format.md: DO's own `V.`/`R.` line-prefix labels are dropped entirely here
    /// (not carried as text) — indentation and italics alone convey versicle vs.
    /// response, a presentation decision `CLAUDE.md`'s visual spec already settles.
    case versicleResponse(versicle: String, response: String, versicleEnglish: String? = nil, responseEnglish: String? = nil)
    /// A psalm or canticle verse, or a `&Gloria` doxology line — same typographic
    /// treatment (`Psalm.swift`). See this type's own doc comment for why the English
    /// fields aren't populated yet even when the surrounding hour has English wired.
    case verse(reference: String, firstHalf: String, secondHalf: String, firstHalfEnglish: String? = nil, secondHalfEnglish: String? = nil)
    case antiphon(String, english: String? = nil)
    /// A hymn stanza, capitulum, collect, or other running prose the visual spec treats
    /// uniformly (§ "Antiphons, hymn stanzas, chapter, and collect follow the same
    /// typographic system").
    case prose(String, english: String? = nil)
    /// A psalm/canticle's own title within Psalmodia, e.g. `"Psalmus 132 [1]"` -- the
    /// psalm number and its 1-based position among the hour's five psalms. Direct
    /// feedback, comparing a real rendering against real DO output.
    case psalmTitle(String)
    /// A psalm's English as one block, paired with the psalm's Latin as a whole rather
    /// than verse by verse: with the Pius XII psalter, whose verse division doesn't match
    /// the English (Vulgate-numbered) one, as Divinum Officium does (`CLAUDE.md`,
    /// Alignment; `docs/psalters-and-english.md` question 1). Follows the psalm's Latin
    /// `.verse` units, which then carry no English of their own.
    case englishPsalm([PsalmVerse])
}

/// One named group of `Unit`s — `docs/rubrics-1960-vespers.md` §5's proposed heading
/// set (INTRODUCTIO, PSALMODIA, CAPITULUM, HYMNUS, VERSUS, CANTICUM, ORATIO, CONCLUSIO).
/// `kind` is a stable identifier for the App to style/caption — the Kit never decides
/// display casing or wording.
public struct Section: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        case introductio, psalmodia, capitulum, hymnus, versus, canticum, precesFeriales, oratio, conclusio
        // Beta 2: Compline's short lesson and the final Marian antiphon; Prime's Martyrology slot
        // stays empty (a separate "hour" in a later beta).
        case lectioBrevis, antiphonaFinalis
        // Prime's *Pretiosa* and "De Officio Capituli".
        case officiumCapituli
    }

    public var kind: Kind
    public var units: [Unit]

    public init(kind: Kind, units: [Unit]) {
        self.kind = kind
        self.units = units
    }
}

/// The fully assembled hour — what `HourAssembler` produces and the app renders
/// directly, with zero further liturgical decisions (`CLAUDE.md`: "no liturgical logic
/// in the app target").
public struct Hour: Equatable, Sendable {
    public var sections: [Section]
    /// The winning office's `[Prelude Vespera]`, shown before the hour itself: DO puts it
    /// at the top of the page (`horas.pl:599-600`, `specials.pl:123-125`). Under 1960 only
    /// Holy Thursday and Good Friday have one, a rubric ("Vesperæ ab iis qui … hodie non
    /// dicuntur"): the visual specification's opening rubric (`CLAUDE.md`, item 6).
    public var prelude: [Unit]

    public init(sections: [Section], prelude: [Unit] = []) {
        self.sections = sections
        self.prelude = prelude
    }
}

/// Strips DO's own presentational line-prefix markers (do-format.md's "Typographic/
/// rubric markers") so `Unit`s carry only real liturgical content — this project
/// deliberately renders versicle/response and rubric distinctions through layout alone,
/// per `CLAUDE.md`'s visual spec, not through DO's inline text labels.
enum DOMarkers {
    /// True for a line that is *itself* a rubric in DO's `!text`/`!!text`/`!!!text`
    /// convention (`do-format.md`) — the caller strips the leading `!`s before display.
    static func isRubricLine(_ line: String) -> Bool {
        line.hasPrefix("!")
    }

    static func stripRubricMarkers(_ line: String) -> String {
        var s = Substring(line)
        while s.first == "!" { s.removeFirst() }
        return String(s)
    }

    /// DO's own generic "render in a smaller font" wrapper (`horas.pl:190`'s
    /// `s{/:(.*?):/}{setfont($smallfont, $1)}eg`) — unlike `!`, this doesn't change
    /// colour (no rubric red), so it isn't a `.rubric` marker; the real rendered page
    /// just shows the wrapped text plainly, in a font size this project's `Unit` model
    /// has no per-run equivalent for. Stripping the delimiters and keeping the inner
    /// text is the closest faithful match. Real example: `Commune/C11.txt`'s own
    /// `[Hymnus Vespera]` ("Ave maris stella") opens with `/:Prima stropha sequentis
    /// hymni dicitur flexis genibus.:/`, a genuine printed-Breviary stage direction
    /// that the real fixture shows as a plain, undecorated line.
    static func stripSmallFontMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: #"/:(.*?):/"#, with: "$1", options: .regularExpression)
    }

    /// Strips a leading `V.`/`R.`/`v.`/`r.`/`Ant.` label (with its following
    /// whitespace), if the line starts with one — used when building `Unit`s directly
    /// from resolved text rather than from a macro that already returns clean text.
    static func stripLineLabel(_ line: String) -> String {
        for label in ["V.", "R.", "v.", "r.", "Ant."] {
            if line.hasPrefix(label) {
                return String(line.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
            }
        }
        return line
    }
}
