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
                    foreignChapter = Self.passage(latin) != nil && Self.passage(english) != nil && Self.passage(latin) != Self.passage(english)
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

    /// The verses a Scripture reference names, whatever the book's name ("2:2", "14:1"),, and however it writes them: "21:10-11; 21:23" and
    /// "21:10-11,23" are the same passage (the Transfiguration's chapter at None).
    static func passage(_ reference: String) -> Set<String>? {
        guard let whole = reference.firstMatch(of: /\d+:[\d,\-]+(?:\s*;\s*\d+:[\d,\-]+)*/) else { return nil }
        var verses: Set<String> = []
        for part in whole.output.split(separator: ";") {
            let pieces = part.trimmingCharacters(in: .whitespaces).split(separator: ":")
            guard pieces.count == 2 else { continue }
            let chapter = pieces[0]
            for item in pieces[1].split(separator: ",") {
                let bounds = item.split(separator: "-").compactMap { Int($0) }
                if bounds.count == 2, bounds[0] <= bounds[1], bounds[1] - bounds[0] < 500 {
                    for verse in bounds[0]...bounds[1] { verses.insert("\(chapter):\(verse)") }
                } else if let first = bounds.first {
                    verses.insert("\(chapter):\(first)")
                }
            }
        }
        return verses.isEmpty ? nil : verses
    }

    /// The unit without an English that repeats its Latin; its Latin; and whether it still
    /// has English.
    static func withoutRepeatedLatin(_ unit: Unit) -> (Unit, String, Bool) {
        // The English column's Latin with its Paschal "alleluia" unaccented (St Mark's
        // *Vos estis lux mundi… possidébitis ánimas vestras, alleluia*, 25 April 2033); a
        // bare *Allelúia* stays a translation.
        func same(_ latin: String, _ english: String?) -> Bool {
            guard let english else { return false }
            if key(english) == key(latin) { return true }
            func unaccented(_ text: String) -> String { key(text).replacingOccurrences(of: #"allel[uú][ij]a"#, with: "alleluia", options: [.regularExpression, .caseInsensitive]) }
            let words = latin.split(whereSeparator: \.isWhitespace).filter { $0.range(of: #"(?i)allel[uú][ij]a"#, options: .regularExpression) == nil }
            return words.count >= 3 && unaccented(english) == unaccented(latin)
        }
        // An English half that the Order's substitution, meant for the Latin, has left
        // as bare punctuation (".", the Advent Ember Friday's *Præcúrsor pro nobis*) is none.
        func text(_ english: String?) -> String? { english.flatMap { $0.contains(where: \.isLetter) ? $0 : nil } }
        var unit = unit
        switch unit {
        case .versicleResponse(let v, let r, let ve, let re?) where text(re) == nil:
            unit = .versicleResponse(versicle: v, response: r, versicleEnglish: ve, responseEnglish: nil)
        case .verse(let reference, let first, let second, let fe, let se?) where text(se) == nil:
            let whole = fe.map { $0.replacingOccurrences(of: #"\s*\*\s*$"#, with: "", options: .regularExpression) }
            unit = .verse(reference: reference, firstHalf: first, secondHalf: second, firstHalfEnglish: whole, secondHalfEnglish: nil)
        default:
            break
        }
        switch unit {
        case .rubric(let text, let english):
            let keep = same(text, english) ? nil : english
            return (.rubric(text, english: keep), text, keep != nil)
        case .versicleResponse(let v, let r, let ve, let re):
            if same(v, ve), same(r, re) || re == nil { return (.versicleResponse(versicle: v, response: r), v + " " + r, false) }
            // An English versicle over a response DO leaves in Latin (a responsory's
            // *Glória Patri*): the response stands in Latin alone.
            if let ve, same(r, re), r.count >= 12 { return (.versicleResponse(versicle: v, response: r, versicleEnglish: ve, responseEnglish: nil), v + " " + r, true) }
            // And the other way: the Order's own versicle over a Roman response (Easter
            // Monday's *Cito euntes*) stands in Latin alone.
            if let re, same(v, ve), v.count >= 12 { return (.versicleResponse(versicle: v, response: r, versicleEnglish: nil, responseEnglish: re), v + " " + r, true) }
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
