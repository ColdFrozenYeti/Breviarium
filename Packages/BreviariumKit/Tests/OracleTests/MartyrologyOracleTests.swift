import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 4: the Martyrology against the one DO prints at Prime, in every Prime fixture
// (2025-2040 and the 2044 hold-out). Latin only (decision 3 of `docs/Beta_4_plan.md`).

/// The Martyrology in a Prime fixture's Latin: from its heading to *Deo grátias*, as the
/// audit compares it (headings, `℣.`/`℟.` and whitespace gone); `""` when DO omits it;
/// `nil` when the page has none.
func fixtureMartyrology(_ text: String) -> String? {
    for row in OracleFixture.rows(text) {
        if row.latin.contains("Martyrologium{omittitur}") { return "" }
        guard let start = row.latin.range(of: "Martyrologium {anticipatur}") else { continue }
        var body = String(row.latin[start.upperBound...])
        if let end = body.range(of: "℟. Deo grátias.") { body = String(body[..<end.upperBound]) }
        return martyrologyComparable(body)
    }
    return nil
}

func martyrologyComparable(_ text: String) -> String {
    collapsedWhitespace(text.replacingOccurrences(of: "℣.", with: " ").replacingOccurrences(of: "℟.", with: " "))
}

/// The engine's Martyrology as the same flat text.
func renderedMartyrology(_ hour: Hour) -> String {
    let units = hour.sections.flatMap(\.units)
    if units == [.rubric("Martyrologium omittitur.", english: nil)] { return "" }
    return martyrologyComparable(units.flatMap(oracleComparisonTexts).joined(separator: " "))
}

private func martyrologyProblems(archive: [String: String], prefix: String, year: Int, bundle: DataBundle) -> (checked: Int, problems: [String]) {
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    var checked = 0
    var problems: [String] = []
    var (day, month, y) = (1, 1, year)
    while y == year {
        let date = String(format: "%04d-%02d-%02d", y, month, day)
        if let text = archive["\(prefix)/\(date)_priestN_bilingual.tsv"], let expected = fixtureMartyrology(text) {
            let context = ConditionalContextBuilder.build(
                day: day, month: month, year: y, ad: "Prima", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
            )
            let actual = MartyrologyAssembler(corpus: corpus, context: context, calendar: calendar)
                .assemble(day: day, month: month, year: y).map(renderedMartyrology)
            checked += 1
            if actual != expected {
                let a = Array(actual ?? "<nil>"), e = Array(expected)
                let at = zip(a, e).prefix { $0 == $1 }.count
                problems.append("\(date): at \(at): DO «\(String(e.dropFirst(max(0, at - 30)).prefix(120)))» | engine «\(String(a.dropFirst(max(0, at - 30)).prefix(120)))»")
            }
        }
        (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
    }
    return (checked, problems)
}

@Test func martyrologyMatchesDivinumOfficium() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    var checked = 0
    var problems: [String] = []
    for year in auditYears {
        guard let archive = try await OracleFixture.shared.hourYear(hour: .prima, year: year) else { continue }
        let result = martyrologyProblems(archive: archive, prefix: "\(year)", year: year, bundle: bundle)
        checked += result.checked
        problems += result.problems
    }
    #expect(checked >= 365, "checked \(checked)")
    #expect(problems.isEmpty, "\n\(problems.count) dates:\n\(problems.prefix(30).joined(separator: "\n"))")
}

@Test func martyrologyHoldout2044() async throws {
    guard let bundle = RealCorpus.bundle, let archive = try await OracleFixture.shared.hourHoldout(hour: .prima, year: 2044) else { return }
    let result = martyrologyProblems(archive: archive, prefix: "2044", year: 2044, bundle: bundle)
    #expect(result.checked == 366, "checked \(result.checked)")
    #expect(result.problems.isEmpty, "\n\(result.problems.prefix(30).joined(separator: "\n"))")
}

@Test func martyrologyMoonAge() {
    // 17 September 2026, read on the 16th: "Luna quinta" (DO's page).
    #expect(MartyrologyAssembler.luna(month: 9, day: 17, year: 2026) == "Luna quinta. Anno Dómini 2026")
    // 6 April 2026, read on Easter Sunday: "Luna duodevicésima".
    #expect(MartyrologyAssembler.lunaDay(month: 4, day: 6, year: 2026) == 18)
}
