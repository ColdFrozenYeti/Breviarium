import Foundation

/// One leaf of assembled Vespers content — formatting-free (`CLAUDE.md`: "No colours,
/// fonts, or spacing live in this model"). Latin-only for now; `CLAUDE.md`'s parallel
/// Latin/English layout is a separate, not-yet-built pass this shape is designed not to
/// need re-architecting for (each case's associated text is a natural place to add an
/// optional English counterpart alongside).
public enum Unit: Equatable, Sendable {
    /// A red italic rubric (do-format.md's `!text` marker, already stripped of the `!`).
    case rubric(String)
    /// do-format.md: DO's own `V.`/`R.` line-prefix labels are dropped entirely here
    /// (not carried as text) — indentation and italics alone convey versicle vs.
    /// response, a presentation decision `CLAUDE.md`'s visual spec already settles.
    case versicleResponse(versicle: String, response: String)
    /// A psalm or canticle verse, or a `&Gloria` doxology line — same typographic
    /// treatment (`Psalm.swift`).
    case verse(reference: String, firstHalf: String, secondHalf: String)
    case antiphon(String)
    /// A hymn stanza, capitulum, collect, or other running prose the visual spec treats
    /// uniformly (§ "Antiphons, hymn stanzas, chapter, and collect follow the same
    /// typographic system").
    case prose(String)
}

/// One named group of `Unit`s — `docs/rubrics-1960-vespers.md` §5's proposed heading
/// set (INTRODUCTIO, PSALMODIA, CAPITULUM, HYMNUS, VERSUS, CANTICUM, ORATIO, CONCLUSIO).
/// `kind` is a stable identifier for the App to style/caption — the Kit never decides
/// display casing or wording.
public struct Section: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable, CaseIterable {
        case introductio, psalmodia, capitulum, hymnus, versus, canticum, oratio, conclusio
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

    public init(sections: [Section]) {
        self.sections = sections
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
