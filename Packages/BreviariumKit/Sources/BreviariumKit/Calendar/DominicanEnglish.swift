import Foundation

/// The Latin lines Dominican substitutions changed the wording of, gathered while an hour
/// is assembled (`SectionResolver.alterations`).
public final class DominicanAlterations: @unchecked Sendable {
    private var keys: Set<String> = []
    private let lock = NSLock()

    public init() {}

    func record(original: String, substituted: String) {
        guard DominicanEnglish.wording(original) != DominicanEnglish.wording(substituted) else { return }
        let before = Set(original.split(separator: "\n").map { DominicanEnglish.key(String($0)) })
        let changed = substituted.split(separator: "\n").map { DominicanEnglish.key(String($0)) }
            .filter { $0.count >= 20 && !before.contains($0) && !$0.hasPrefix("@") }
        lock.lock()
        keys.formUnion(changed)
        lock.unlock()
    }

    func contains(_ latin: String) -> Bool {
        let key = DominicanEnglish.key(latin)
        guard key.count >= 20 else { return false }
        lock.lock()
        defer { lock.unlock() }
        return keys.contains { $0 == key || $0.contains(key) || key.contains($0) }
    }
}

/// Beta 5, decisions 5 and 6 of `docs/Beta_5_plan.md`, applied to an assembled Dominican
/// hour: an English that is only the Latin again (DO's fallback, where the Order's text
/// has no English) is dropped, so the Latin stands alone; a Roman English kept for Latin a
/// Dominican substitution reworded is followed by the grey note.
public enum DominicanEnglish {
    public static let note = "Roman text; the Dominican Latin differs."

    /// A line's text for matching: no `Ant.`/`R.`/`V.` labels, asterisks or daggers, lower case,
    /// whitespace collapsed.
    static func key(_ line: String) -> String {
        var text = line.trimmingCharacters(in: .whitespaces)
        if let range = text.range(of: #"^(Ant\.|[RrVv]\.(br\.)?)\s*"#, options: .regularExpression) { text.removeSubrange(range) }
        text = text.replacingOccurrences(of: #"[*†‡]"#, with: " ", options: .regularExpression)
        return text.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    /// The words alone: what a substitution that only moves an asterisk or a label leaves.
    static func wording(_ text: String) -> String {
        text.split(separator: "\n").map { key(String($0)) }.joined(separator: " ")
            .unicodeScalars.filter { CharacterSet.letters.contains($0) }.map(String.init).joined()
    }

    public static func apply(to hour: Hour, alterations: DominicanAlterations?) -> Hour {
        var hour = hour
        hour.sections = hour.sections.map { section in
            var section = section
            var units: [Unit] = []
            var pendingNote = false
            // A chapter whose English is another passage's (`Minor Special`'s `[Adv Nona]`:
            // the Order's Isaiah 2:2 has its own Latin section but the Roman English of
            // Isaiah 14:1) is said in Latin alone.
            var foreignChapter = false
            for var unit in section.units {
                if case .psalmTitle(let latin, let english?) = unit {
                    foreignChapter = Self.citation(latin) != nil && Self.citation(english) != nil && Self.citation(latin) != Self.citation(english)
                    if foreignChapter { unit = .psalmTitle(latin) }
                } else if foreignChapter, case .prose(let latin, _) = unit {
                    unit = .prose(latin)
                } else {
                    foreignChapter = false
                }
                let (cleaned, latin, hasEnglish) = withoutRepeatedLatin(unit)
                let altered = hasEnglish && (alterations?.contains(latin) ?? false)
                if pendingNote, !altered { units.append(.englishNote(note)) }
                pendingNote = altered
                units.append(cleaned)
            }
            if pendingNote { units.append(.englishNote(note)) }
            section.units = units
            return section
        }
        return hour
    }

    /// A Scripture reference's chapter and verses ("2:2", "14:1"), whatever the book's name.
    static func citation(_ reference: String) -> String? {
        reference.firstMatch(of: /\d+:[\d,\-]+/).map { String($0.output) }
    }

    /// The unit without an English that repeats its Latin; its Latin; and whether it still
    /// has English.
    static func withoutRepeatedLatin(_ unit: Unit) -> (Unit, String, Bool) {
        func same(_ latin: String, _ english: String?) -> Bool { english.map { key($0) == key(latin) } ?? false }
        switch unit {
        case .rubric(let text, let english):
            let keep = same(text, english) ? nil : english
            return (.rubric(text, english: keep), text, keep != nil)
        case .versicleResponse(let v, let r, let ve, let re):
            if same(v, ve), same(r, re) || re == nil { return (.versicleResponse(versicle: v, response: r), v + " " + r, false) }
            // An English versicle over a response DO leaves in Latin (a responsory's
            // *Glória Patri*): the response stands in Latin alone.
            if let ve, same(r, re), r.count >= 12 { return (.versicleResponse(versicle: v, response: r, versicleEnglish: ve, responseEnglish: nil), v + " " + r, true) }
            return (unit, v + " " + r, ve != nil)
        case .verse(let reference, let first, let second, let fe, let se):
            if same(first, fe), same(second, se) || se == nil { return (.verse(reference: reference, firstHalf: first, secondHalf: second), first + " " + second, false) }
            return (unit, first + " " + second, fe != nil)
        case .antiphon(let text, let english):
            let keep = same(text, english) ? nil : english
            return (.antiphon(text, english: keep), text, keep != nil)
        case .prose(let text, let english):
            let keep = same(text, english) ? nil : english
            return (.prose(text, english: keep), text, keep != nil)
        case .psalmTitle(let text, let english):
            // A Scripture reference is the same in both columns; a title isn't.
            let keep = same(text, english) && text.rangeOfCharacter(from: .decimalDigits) == nil ? nil : english
            return (.psalmTitle(text, english: keep), text, keep != nil)
        case .lesson(let paragraph):
            // Line by line: a verse the Dominican file writes out in Latin has no English.
            let latin = paragraph.lines.joined(separator: " ")
            let latinKeys = Set(paragraph.lines.map(key))
            let english = paragraph.english?.filter { !latinKeys.contains(key($0)) }
            let kept = english.flatMap { $0.isEmpty ? nil : $0 }
            return (.lesson(LessonParagraph(lines: paragraph.lines, english: kept)), latin, kept != nil)
        case .englishPsalm, .englishNote:
            return (unit, "", false)
        }
    }
}
