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

    public static func parseVerses(_ lines: [String]) -> [PsalmVerse] {
        lines.compactMap { line in
            guard let spaceIndex = line.firstIndex(of: " "), spaceIndex > line.startIndex else { return nil }
            let reference = String(line[line.startIndex..<spaceIndex])
            guard reference.first?.isNumber == true else { return nil }    // Skips the odd leading "(...)" title line.

            let text = String(line[line.index(after: spaceIndex)...]).replacing(subVerseAnnotation, with: "")
            let (first, second) = splitHalves(text)
            return PsalmVerse(reference: reference, firstHalf: first, secondHalf: second)
        }
    }

    /// Splits one already-de-referenced line of text at its `*` half-verse marker,
    /// producing the two halves `CLAUDE.md`'s typography wants (also used for the
    /// `&Gloria` doxology, which follows the identical `* `-split convention).
    public static func splitHalves(_ text: String) -> (first: String, second: String) {
        guard let range = text.range(of: " * ") else { return (text, "") }
        return (String(text[text.startIndex..<range.lowerBound]) + "*", String(text[range.upperBound...]))
    }
}
