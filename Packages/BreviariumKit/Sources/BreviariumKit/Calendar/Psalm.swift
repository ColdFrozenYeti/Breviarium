/// One verse (or half-verse, where the Bea psalter divides more finely than the older
/// numbering — e.g. `"1:3a"`/`"1:3b"`) of a psalm or canticle.
public struct PsalmVerse: Equatable, Sendable {
    /// E.g. `"114:1"`, `"1:3a"` (canticles use chapter:verse, psalms use psalm:verse).
    public var reference: String
    /// Ends with `*` attached directly to the last word, per `CLAUDE.md`'s psalm-verse
    /// typography (`"...et Fílio*"`) — the renderer places the second half on its own
    /// indented line, never re-deriving the split itself.
    public var firstHalf: String
    public var secondHalf: String

    public init(reference: String, firstHalf: String, secondHalf: String) {
        self.reference = reference
        self.firstHalf = firstHalf
        self.secondHalf = secondHalf
    }
}

/// Parses `Psalterium/Psalmorum/Psalm<N>.txt` — flat, headerless `"ref text"` lines
/// (`RawSectionParser`'s `wholeFileSectionName` fallback), the same format canticles
/// like the Magnificat use (`Psalm232.txt`), just under a different number.
///
/// **Scope limit:** the mid-verse flex mark (`†`/`‡`) is kept as literal text, not
/// treated as a structural split point — `CLAUDE.md`'s typographic spec only calls out
/// the `*` half-verse split. Merging split half-verses (`"1:3a"`/`"1:3b"`) into one
/// aligned unit for the parallel Latin/English layout is explicitly `CLAUDE.md`'s
/// "alignment" concern for the (not yet built) English column — deferred rather than
/// guessed at here, since there's no English content yet to align against.
public enum Psalm {
    /// A Bea-numbering cross-reference to the older Vulgate/Douay-Rheims verse split,
    /// inline in the raw text itself (real example, `Latin-Bea/Psalterium/Psalmorum/
    /// Psalm115.txt:6`: `"...coram omni pópulo ejus. * (15) Pretiósa est..."`). DO's own
    /// `horasscripts.pl:397-407` (`handleverses`) confirms this is DO's own numbering
    /// annotation, not stray source punctuation -- it's wrapped in the same `/:...:/ `
    /// small-font-footnote convention as the verse's own leading reference number, which
    /// this app already never renders (`reference` is kept as structured metadata, never
    /// displayed literally) -- so the consistent treatment is to drop this one from the
    /// displayed text the same way, not to show it inline as ordinary body text.
    private nonisolated(unsafe) static let subVerseAnnotation: Regex<AnyRegexOutput> =
        try! Regex(#"\s*\(\d+[a-z]?\)"#)

    /// `keepingSubVerseLetters` keeps a reference's `a`/`b` letter (`"144:13a"`) for a
    /// caller that still has to filter by a verse range, which is decided on the lettered
    /// reference (`horasscripts.pl:598-614`) before DO removes the letter for display
    /// (`:400-403`); such a caller applies `displayReference` itself afterwards.
    /// DO's display rules for the marks inside a psalm line, applied in every language
    /// (`horasscripts.pl:418-419`, `handleverses`, with its `$noflexa` default on): the
    /// flex `†` is removed, and a `‡` becomes the half-verse break, the line's own later
    /// `*` dropping (`"A ‡ B * C"` → `"A * B C"`). The Latin text has had this applied
    /// when the data was built (`LatinOrthography`); the English hasn't, since nothing
    /// else rewrites English (`CLAUDE.md`), and DO applies these only to psalm lines, not
    /// to other text (`webdia.pl:696` keeps a `†` elsewhere).
    static func displayMarks(_ text: String) -> String {
        var result = text.replacingOccurrences(of: #"†\s*"#, with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: #"‡\s+(.*?)\*\s*"#, with: "* $1", options: .regularExpression)
        return result
    }

    public static func parseVerses(_ lines: [String], keepingSubVerseLetters: Bool = false) -> [PsalmVerse] {
        lines.compactMap { line in
            guard let spaceIndex = line.firstIndex(of: " "), spaceIndex > line.startIndex else { return nil }
            let rawReference = String(line[line.startIndex..<spaceIndex])
            guard rawReference.first?.isNumber == true else { return nil }    // Skips the odd leading "(...)" title line.

            let text = displayMarks(String(line[line.index(after: spaceIndex)...]).replacing(subVerseAnnotation, with: ""))
            let (first, second) = splitHalves(text)
            return PsalmVerse(
                reference: keepingSubVerseLetters ? rawReference : strippingSubVerseLetter(rawReference), firstHalf: first, secondHalf: second
            )
        }
    }

    /// Strips a Bea-only `a`/`b` sub-verse letter from a verse reference for display,
    /// matching DO's own real rendering (`horasscripts.pl:400-401`'s "remove subverse
    /// letter", `s/\d\K[a-z]//`, gated by `$noinnumbers` — confirmed active for this
    /// project's own rendering the same way `$noflexa`'s sibling flag already is):
    /// `"115:16a"` and `"115:16b"` both display as `"115:16"`, matching the real fixture
    /// for 19 January 2026 exactly (`"115:16"` shown twice, not `"115:16a"`/`"115:16b"`).
    /// The two verses stay separate `PsalmVerse`s — DO still renders them as two distinct
    /// lines, each with its own `*` split — only the visible label merges.
    ///
    /// **Not attempted**: reconstructing a true per-half-verse Latin/English alignment
    /// across this divergence (`pairedVerses`'s own doc comment has the full story on
    /// why — it would need treating `†`/`‡` as structural split points too, which
    /// `Psalm.swift`'s own scope note above deliberately doesn't).
    /// `verse` with its reference's sub-verse letter removed: the form DO displays.
    public static func displayReference(_ verse: PsalmVerse) -> PsalmVerse {
        PsalmVerse(reference: strippingSubVerseLetter(verse.reference), firstHalf: verse.firstHalf, secondHalf: verse.secondHalf)
    }

    private static func strippingSubVerseLetter(_ reference: String) -> String {
        guard let last = reference.last, last.isLowercase,
            let secondToLast = reference.dropLast().last, secondToLast.isNumber
        else { return reference }
        return String(reference.dropLast())
    }

    /// Splits one already-de-referenced line of text at its `*` half-verse marker,
    /// producing the two halves `CLAUDE.md`'s typography wants (also used for the
    /// `&Gloria` doxology, which follows the identical `* `-split convention).
    public static func splitHalves(_ text: String) -> (first: String, second: String) {
        guard let range = text.range(of: " * ") else { return (text, "") }
        return (String(text[text.startIndex..<range.lowerBound]) + "*", String(text[range.upperBound...]))
    }
}
