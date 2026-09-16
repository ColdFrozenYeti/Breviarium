/// One `[SectionName]` block from a Divinum Officium office file, with its header
/// condition (if any) preserved but **not evaluated** — see `RawSectionParser`.
public struct RawSection: Codable, Equatable, Sendable {
    /// The section name, e.g. `"Oratio"`, `"Ant 1"`, `"Capitulum Hymnus Versus"`.
    public var name: String
    /// The raw condition text from `[Name] (condition)`, unevaluated. Empty when the
    /// header was unconditioned.
    public var condition: String
    /// The raw body lines, unresolved: may still contain `(sed ...)` conditionals and
    /// `@`/`$`/`&` references, for `ConditionalLineProcessor` and the resolution engine
    /// to process at render time.
    public var body: [String]

    public init(name: String, condition: String, body: [String]) {
        self.name = name
        self.condition = condition
        self.body = body
    }
}

/// One parsed office file: every section variant, in file order. Multiple entries can
/// share the same `name` when the source has competing `[Name] (condA)` / `[Name]
/// (condB)` blocks — DO's own loader (`setupstring_parse_file`) picks a winner at load
/// time by evaluating each condition against the current context and keeping the last
/// one that holds; `BreviariumData` preserves every variant instead, since it never has
/// a context to evaluate against (see `docs/PLAN.md`'s 2026-09-16 amendment).
public struct RawOfficeFile: Codable, Equatable, Sendable {
    /// Path relative to the DO `Latin`/`Latin-Bea`/`English` root, e.g.
    /// `"Sancti/01-18r.txt"`.
    public var path: String
    public var sections: [RawSection]

    public init(path: String, sections: [RawSection]) {
        self.path = path
        self.sections = sections
    }
}

/// Ports the section-splitting phase of `setupstring_parse_file`
/// (`SetupString.pl:318-371`) — stopping short of evaluating any condition (that's
/// `vero()`'s job, run later by `BreviariumKit`'s resolution engine against a complete
/// render-time context) or running `process_conditional_lines` on the body (also
/// deferred to render time).
public enum RawSectionParser {

    /// The synthetic section name a headerless file's entire content is stored under —
    /// see the note on `Ordinarium/` skeleton files below.
    public static let wholeFileSectionName = "__skeleton"

    /// Splits one file's text into its raw section variants.
    ///
    /// `path` is used to fill in bare `@` self-references (`@:SectionName`,
    /// `@SomeKeyword` with no filename) with this file's own name — a purely mechanical,
    /// context-free normalisation DO's own parser also does at this stage
    /// (`SetupString.pl:353-358`), so every `@` reference in the bundle ends up fully
    /// qualified rather than relying on "current file" context at resolution time.
    ///
    /// `Ordinarium/*.txt` skeleton files (e.g. `Vespera.txt`) have **no** `[Header]`
    /// lines at all — DO's own `getordinarium()` reads them as a flat line list straight
    /// into `process_conditional_lines`, with `#Name` lines surviving as literal content
    /// that mark section/page boundaries (`horas.pl:579-601`), not as a parse-time
    /// header syntax. A file with zero `[Header]`s is stored as one section named
    /// `wholeFileSectionName` holding every line, instead of being silently discarded as
    /// pure preamble — `HourAssembler` is what actually interprets the `#Name` markers.
    public static func parse(fileText: String, path: String) -> RawOfficeFile {
        let fileNameWithoutExtension = fileNameStem(path)
        var sections: [RawSection] = []
        var wholeFileBody: [String] = []

        var currentName = "__preamble"
        var currentBody: [String] = []
        var inPreamble = true

        func flush() {
            guard !inPreamble else { return }
            sections.append(RawSection(name: currentName, condition: currentCondition, body: currentBody))
        }

        var currentCondition = ""

        for rawLine in fileText.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)

            if line.first == "[", let header = matchSectionHeader(line) {
                flush()
                currentName = header.name
                currentCondition = header.condition
                currentBody = []
                inPreamble = false
                continue
            }

            wholeFileBody.append(qualifySelfReferences(line, fileName: fileNameWithoutExtension, currentSection: currentName))
            guard !inPreamble else { continue }    // Preamble content isn't a section body we bundle.

            currentBody.append(qualifySelfReferences(line, fileName: fileNameWithoutExtension, currentSection: currentName))
        }
        flush()

        if sections.isEmpty {
            sections.append(RawSection(name: wholeFileSectionName, condition: "", body: wholeFileBody))
        }

        return RawOfficeFile(path: path, sections: sections)
    }

    // MARK: - Section header matching

    private struct HeaderMatch {
        var name: String
        var condition: String
    }

    /// Ports `$sectionregex` (`SetupString.pl:324`) plus the trailing
    /// `(?:\s*$conditional_regex)?` DO attaches when checking for a header
    /// (`SetupString.pl:335`).
    private static func matchSectionHeader(_ line: String) -> HeaderMatch? {
        guard let nameMatch = try? sectionNameRegex.firstMatch(in: line),
            nameMatch.range.lowerBound == line.startIndex,
            let name = nameMatch.output[1].substring
        else { return nil }

        let afterName = line[nameMatch.range.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
        guard let (clause, _) = ConditionalGrammar.matchLeadingClause(in: afterName) else {
            return HeaderMatch(name: String(name), condition: "")
        }
        return HeaderMatch(name: String(name), condition: clause.condition)
    }

    /// Ports `$sectionregex = qr/^\s*\[([\pL\pN_ #,:-]+)\]/i` (`SetupString.pl:324`).
    private nonisolated(unsafe) static let sectionNameRegex: Regex<AnyRegexOutput> = {
        // swiftlint:disable:next force_try
        try! Regex(#"(?i)^\s*\[([\p{L}\p{N}_ #,:-]+)\]"#)
    }()

    // MARK: - `@` self-reference qualification

    /// Fills in a bare `@` reference's missing filename/keyword with the current
    /// file/section, mirroring `SetupString.pl:353-358`'s `$InclusionRegex` substitution.
    /// Only applies to lines that are themselves a `@`-reference; everything else is
    /// returned unchanged.
    private static func qualifySelfReferences(_ line: String, fileName: String, currentSection: String) -> String {
        guard line.first == "@", let match = try? inclusionRegex.firstMatch(in: line) else { return line }

        let capturedFile = match.output[1].substring.map(String.init)
        let capturedKeyword = match.output[2].substring.map(String.init)
        let capturedSubs = match.output[3].substring.map(String.init)

        var result = "@"
        result += (capturedFile?.isEmpty == false ? capturedFile! : fileName) + ":"
        result += (capturedKeyword?.isEmpty == false ? capturedKeyword! : currentSection)
        if let subs = capturedSubs { result += ":\(subs)" }
        return result
    }

    /// Ports `$InclusionRegex` (`SetupString.pl:305-312`):
    /// `^\s*\@([^\n:]+)?(?::([^\n:]+?))?[^\S\n\r]*(?::(.*))?$`.
    private nonisolated(unsafe) static let inclusionRegex: Regex<AnyRegexOutput> = {
        // swiftlint:disable:next force_try
        try! Regex(#"^\s*@([^\n:]+)?(?::([^\n:]+?))?[^\S\n\r]*(?::(.*))?$"#)
    }()

    private static func fileNameStem(_ path: String) -> String {
        path.hasSuffix(".txt") ? String(path.dropLast(4)) : path
    }
}
