import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 1, B1-M4: the English, audited against Divinum Officium's bilingual page
// (`data/oracle-fixtures/bilingual/`, Vulgate Latin + English, one table row per line).
// Three checks, in both directions, as the alpha's retrospective asks:
// - content: every English piece we render appears in DO's English column;
// - coverage: DO's English column, with everything we render removed, has no liturgical
//   text left over (what we fail to show);
// - pairing: a unit's Latin and English sit in the same row of DO's table.
// English is never passed through `LatinOrthography` (`CLAUDE.md`: never touch English).

/// The English text pieces of a unit, shaped like `oracleComparisonTexts` shapes the Latin.
func englishComparisonTexts(_ unit: BreviariumKit.Unit) -> [String] {
    switch unit {
    case .rubric(_, let english): return [english].compactMap { $0 }
    case .versicleResponse(_, _, let versicle, let response): return [versicle, response].compactMap { $0 }
    case .verse(_, _, _, let first, let second):
        guard let first else { return [] }
        guard let second, !second.isEmpty else { return [first] }
        let withoutAsterisk = first.hasSuffix("*") ? String(first.dropLast()) : first
        return ["\(withoutAsterisk) * \(second)"]
    case .antiphon(_, let english): return [english].compactMap { $0 }
    case .prose(_, let english): return [english].compactMap { $0 }
    case .psalmTitle: return []
    case .englishPsalm(let verses):
        return verses.map { verse in
            guard !verse.secondHalf.isEmpty else { return verse.firstHalf }
            let first = verse.firstHalf.hasSuffix("*") ? String(verse.firstHalf.dropLast()) : verse.firstHalf
            return "\(first) * \(verse.secondHalf)"
        }
    }
}

struct EnglishAuditResult {
    /// English pieces we render that DO's English column doesn't contain, by section.
    var missingFromDO: [(Section.Kind, String)] = []
    /// Text left in DO's English column after removing ours and the table's chrome.
    var uncovered: [String] = []
    /// Text left in DO's Latin column the same way: what we fail to show in Latin.
    var uncoveredLatin: [String] = []
    /// Units whose Latin and English DO prints in different rows.
    var mispaired: [String] = []
    /// Units with Latin but no English, by section: a count of what's not wired yet.
    var latinOnly: [(Section.Kind, String)] = []
}

/// Structural text in DO's English cells that isn't liturgical content, removed before
/// looking for uncovered English. Section headings and psalm titles are fixed elements
/// the app shows in Latin only (`CLAUDE.md`; `psalters-and-english.md` question 3), and
/// "Ant." and the ℣/℟ glyphs are labels the app replaces with typography. Anything else
/// left over is reported.
private nonisolated(unsafe) let englishChrome: [Regex<AnyRegexOutput>] = [
    try! Regex(#"^\d+ "#),                // the row counter DO prints in the English cell
    try! Regex(#"Top Next"#),
    try! Regex(#"\{[^}]*\}"#),            // DO's source notes, "{from the Proper of Saints}", "{omit}"
    try! Regex(#"Psalm \d+(\([^)]*\))?( —[^\[]*)? \[\d\]"#),
    try! Regex(#"\b\d{1,3}:\d{1,3}\b"#),  // verse references
    try! Regex(#"[℣℟]\."#),
    try! Regex(#"\bAnt\."#),
    try! Regex(#"‡"#),
    try! Regex(#"^\s*(Start|Psalms|Chapter Hymn Verse|Canticle: Magnificat|Weekday Intercessions|Prayer|Conclusion)\b"#),
    try! Regex(#"^\s*Hymn\b"#),    // the hymn label, left at the start once the heading is gone
    try! Regex(#"^\s*Verse \(taking the place of the Chapter\)"#),    // DO's group heading in the Easter Octave
    try! Regex(#"Canticle of the Blessed Virgin Luke\s*-?\d*"#),
    // Beta 2's day hours: their own group headings and the canticle title.
    try! Regex(#"^\s*(Chapter Responsory Verse|Chapter Verse|Short Lesson|Short reading|Special Completorium|Suffrage|The Capitular Office|Canticle: Benedictus|Lectio brevis|Canticle: Nunc dimittis|Final Antiphon of the Blessed Virgin Mary|Final Antiphon)\b"#),
    try! Regex(#"Canticle of Simeon Luke\s*-?[\d:-]*"#),
    try! Regex(#"Canticle of Zachary Luke\s*-?[\d:-]*"#),
    try! Regex(#"Canticle of [\p{L} .]+? \[\d+\] [\p{L}.]+\s*-?\d*(, ?\d+)?"#),
    try! Regex(#"Canticle of [\p{L} .]+? [\p{L}.]+\s*-?\d*(, ?\d+)?"#),
]

/// The same for DO's Latin cells: headings and titles the app sets as its own fixed
/// elements, and labels.
private nonisolated(unsafe) let latinChrome: [Regex<AnyRegexOutput>] = [
    try! Regex(#"Top Next"#),
    try! Regex(#"\{[^}]*\}"#),
    try! Regex(#"Psalmus \d+(\([^)]*\))?( —[^\[]*)? \[\d\]"#),
    try! Regex(#"\b\d{1,3}:\d{1,3}\b"#),
    try! Regex(#"[℣℟]\."#),
    try! Regex(#"\bAnt\."#),
    try! Regex(#"‡"#),
    try! Regex(#"^\s*(Incipit|Psalmi|Capitulum Hymnus Versus|Canticum: Magnificat|Preces Feriales|Oratio|Conclusio)\b"#),
    try! Regex(#"Canticum B\. Mariæ Virginis Luc\.\s*-?\d*"#),
    try! Regex(#"^\s*Hymnus\b"#),
    try! Regex(#"^\s*Versus \(In loco Capituli\)"#),
    try! Regex(#"^\s*(Capitulum Responsorium Versus|Capitulum Versus|Lectio brevis|Completorium singulare|Suffragium|Canticum: Benedictus|De Officio Capituli|Canticum: Nunc dimittis|Antiphona finalis B\. ?M\. ?V\.|Antiphona finalis)\b"#),
    try! Regex(#"Canticum Simeonis Luc\.\s*-?[\d:-]*"#),
    try! Regex(#"Canticum Zachariæ Luc\.\s*-?[\d:-]*"#),
    // Lauds' Old Testament canticle titles ("Canticum Iudith [4] Iudith 16:15-22"),
    // once the verse numbers are gone.
    try! Regex(#"Canticum [\p{L} .]+? \[\d+\] [\p{L}.]+\s*-?\d*(, ?\d+)?"#),
]

/// What's left of each cell once every piece we render, and the chrome, is removed:
/// text DO shows that we don't.
private func leftovers(cells: [String], ours: [String], chrome: [Regex<AnyRegexOutput>]) -> [String] {
    let longestFirst = ours.sorted { $0.count > $1.count }
    return cells.compactMap { cell in
        var rest = cell
        for piece in longestFirst { rest = rest.replacingOccurrences(of: piece, with: " ") }
        for pattern in chrome { rest = collapsedWhitespace(rest.replacing(pattern, with: " ")) }
        return rest.contains(where: \.isLetter) ? rest : nil
    }
}

/// Every `n`th day instead of every day, from `BREVIARIUM_AUDIT_STRIDE` (default 1): a quick
/// sample while iterating. Commits are gated on the full range (stride 1).
let auditStride = max(1, Int(ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_STRIDE"] ?? "") ?? 1)

func englishAudit(hour: Hour, rows: [BilingualRow]) -> EnglishAuditResult {
    var result = EnglishAuditResult()
    let latinRows = rows.map { collapsedWhitespace(LatinOrthography.normalize($0.latin)) }
    let englishRows = rows.map { collapsedWhitespace($0.english) }
    let englishColumn = englishRows.joined(separator: " ")
    let normalizedEnglishColumn = collapsedWhitespace(LatinOrthography.normalize(englishColumn))

    var ours: [String] = []
    var oursLatin: [String] = []
    var rowCursor = 0    // units come in page order, so each is looked for from the last one's row on
    for section in [Section(kind: .introductio, units: hour.prelude)] + hour.sections {
        for unit in section.units {
            let english = englishComparisonTexts(unit).map(collapsedWhitespace).filter { !$0.isEmpty }
            let latin = oracleComparisonTexts(unit).map(collapsedWhitespace).filter { !$0.isEmpty }
            oursLatin.append(contentsOf: latin)
            if english.isEmpty {
                if let first = latin.first { result.latinOnly.append((section.kind, first)) }
                continue
            }
            // Where DO has no English it prints the Latin in the English column (raw, with
            // J); we print that Latin in I spelling, as all our Latin (`CLAUDE.md`).
            for piece in english
            where !englishColumn.contains(piece) && !normalizedEnglishColumn.contains(piece)
                && !normalizedEnglishColumn.contains(collapsedWhitespace(LatinOrthography.normalize(piece)))
            {
                result.missingFromDO.append((section.kind, piece))
            }
            ours.append(contentsOf: english)
            if let latinPiece = latin.first, let englishPiece = english.first,
                let latinRow = latinRows[rowCursor...].firstIndex(where: { $0.contains(latinPiece) }),
                let englishRow = englishRows[rowCursor...].firstIndex(where: { $0.contains(englishPiece) })
            {
                if latinRow != englishRow {
                    result.mispaired.append("[\(section.kind)] Latin row \(latinRow), English row \(englishRow): \(englishPiece.prefix(80))")
                }
                rowCursor = min(latinRow, englishRow)
            }
        }
    }

    // Removed from the raw cells first, then again from the J-to-I-normalised rest, for
    // the Latin fallback text above.
    // Our pieces are J-to-I normalised too for that second pass: a Latin fallback with an
    // English name spliced in ("…tuórum Januarius and companions…", `Sancti/09-19`) is
    // mixed text that neither spelling of the cell matches as it stands.
    let oursNormalized = ours + ours.map { collapsedWhitespace(LatinOrthography.normalize($0)) }
    result.uncovered = leftovers(cells: englishRows, ours: ours, chrome: [])
        .compactMap { leftovers(cells: [collapsedWhitespace(LatinOrthography.normalize($0))], ours: oursNormalized, chrome: englishChrome).first }
    // The first row is the day title above DO's table: the app's title block, checked
    // elsewhere, so the Latin coverage starts at the table.
    result.uncoveredLatin = leftovers(cells: Array(latinRows.dropFirst()), ours: oursLatin, chrome: latinChrome)
    return result
}

/// Every date 2025-2040 (Vulgate, priest off): content, coverage and pairing of the
/// English. Reported by frequency, so one root cause shows as one line.
@Test func vespersFullRangeEnglishAudit() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let englishCorpus = bundle.makeEnglishCorpus()
    let calendar = bundle.makeSanctoralCalendar()

    var missing: [String: [String]] = [:]
    var uncovered: [String: [String]] = [:]
    var uncoveredLatin: [String: [String]] = [:]
    var mispaired: [String: [String]] = [:]
    var latinOnly: [String: Int] = [:]
    var daysChecked = 0
    var (day, month, year) = (1, 1, 2025)
    while true {
        let dateLabel = String(format: "%04d-%02d-%02d", year, month, day)
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
        )
        let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar, englishCorpus: englishCorpus)
        if let hour = assembler.assembleVespers(day: day, month: month, year: year, priest: false),
            let rows = try await OracleFixture.shared.bilingual(year: year, date: dateLabel)
        {
            daysChecked += 1
            let result = englishAudit(hour: hour, rows: rows)
            for (kind, text) in result.missingFromDO { missing["[\(kind)] \(text.prefix(140))", default: []].append(dateLabel) }
            for text in result.uncovered { uncovered[String(text.prefix(140)), default: []].append(dateLabel) }
            for text in result.uncoveredLatin { uncoveredLatin[String(text.prefix(140)), default: []].append(dateLabel) }
            for text in result.mispaired { mispaired[text, default: []].append(dateLabel) }
            for (kind, _) in result.latinOnly { latinOnly["\(kind)", default: 0] += 1 }
        }
        if (day, month, year) == (31, 12, 2040) { break }
        (day, month, year) = Computus.addDays(auditStride, day: day, month: month, year: year)
        if year > 2040 { break }
    }

    func report(_ title: String, _ problems: [String: [String]]) -> String {
        guard !problems.isEmpty else { return "" }
        let dates = Set(problems.values.flatMap { $0 })
        let lines = problems.sorted { $0.value.count > $1.value.count }.prefix(30).map { text, dates in
            "  \(dates.count)x, e.g. \(dates.first!): \(text)"
        }
        return "-- \(title): \(problems.count) distinct, on \(dates.count) date(s) --\n" + lines.joined(separator: "\n")
    }
    let latinOnlyReport = latinOnly.isEmpty ? "" : "-- Latin-only units (no English yet), by section --\n  "
        + latinOnly.sorted { $0.value > $1.value }.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
    let full = [
        report("English we render that DO doesn't show", missing),
        report("DO English we don't render", uncovered),
        report("DO Latin we don't render", uncoveredLatin),
        report("Latin and English in different rows", mispaired),
        latinOnlyReport,
    ].filter { !$0.isEmpty }.joined(separator: "\n\n")

    #expect(daysChecked > 5_800 / auditStride, "expected the full 2025-2040 range, checked \(daysChecked)")
    #expect(full.isEmpty, "\n\(full)")
}
