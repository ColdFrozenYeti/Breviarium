/// Directions printed inside a text, *(Fit reverentia)* in the *Te Deum* or
/// *(genuflectitur)* in the invitatory: DO sets them in small print (`/:(…):/`, or plain
/// brackets in a psalm's own text). Beta 4 shows them as rubrics (decided 2026-09-26), so
/// the Kit marks them with `start`/`end` and the app draws them in rubric red, or drops
/// them with rubrics off. Everything else about the text is unchanged.
public enum InlineRubrics {
    /// Private-use characters, which no DO text contains.
    public static let start: Character = "\u{E000}"
    public static let end: Character = "\u{E001}"

    /// Every inline direction in the Roman texts at the pinned commit, Latin and English.
    nonisolated(unsafe) private static let direction = #/\((Fit reverentia(?:, secundum consuetudinem)?:?|genuflectitur|percutit sibi pectus|Sequens versus dicitur flexis genibus|genuflect|Bow head)\)/#

    public static func marking(_ text: String) -> String {
        guard !text.contains(start) else { return text }    // already marked where it was built
        return text.replacing(direction) { "\(start)\($0.output.0)\(end)" }
    }

    /// The text without its markers (as DO's page shows it).
    public static func unmarked(_ text: String) -> String {
        text.filter { $0 != start && $0 != end }
    }

    /// The text without its inline rubrics at all (rubrics off).
    public static func withoutRubrics(_ text: String) -> String {
        guard text.contains(start) else { return text }
        let stripped = text.replacing(#/\s*\u{E000}[^\u{E001}]*\u{E001}/#, with: "")
        return stripped.trimmingCharacters(in: .whitespaces)
    }

    static func marking(_ hour: Hour) -> Hour {
        Hour(sections: hour.sections.map { Section(kind: $0.kind, units: $0.units.map(marking)) }, prelude: hour.prelude.map(marking))
    }

    static func marking(_ unit: Unit) -> Unit {
        let m: (String) -> String = marking
        switch unit {
        case .rubric(let text, let english): return .rubric(text, english: english)
        case .versicleResponse(let v, let r, let ve, let re):
            return .versicleResponse(versicle: m(v), response: m(r), versicleEnglish: ve.map(m), responseEnglish: re.map(m))
        case .verse(let reference, let first, let second, let firstEnglish, let secondEnglish):
            return .verse(reference: reference, firstHalf: m(first), secondHalf: m(second), firstHalfEnglish: firstEnglish.map(m), secondHalfEnglish: secondEnglish.map(m))
        case .antiphon(let text, let english): return .antiphon(m(text), english: english.map(m))
        case .prose(let text, let english): return .prose(m(text), english: english.map(m))
        case .psalmTitle: return unit
        case .englishPsalm(let verses):
            return .englishPsalm(verses.map { verse in
                var verse = verse
                verse.firstHalf = m(verse.firstHalf)
                verse.secondHalf = m(verse.secondHalf)
                return verse
            })
        case .lesson(let paragraph):
            return .lesson(LessonParagraph(lines: paragraph.lines.map(m), english: paragraph.english.map { $0.map(m) }))
        }
    }
}
