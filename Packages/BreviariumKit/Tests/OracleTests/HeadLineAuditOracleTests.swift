import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

/// The title block's third line as DO prints it in the page head: what follows the rank
/// (`… ~ III. classis <line> Ad Laudes`), `nil` when nothing does.
func fixtureHeadLine(_ fixtureText: String, hour: CanonicalHour) -> String? {
    guard let tilde = fixtureText.range(of: " ~ "),
        let classis = fixtureText.range(of: "classis", range: tilde.upperBound..<fixtureText.endIndex)
    else { return nil }
    var rest = String(fixtureText[classis.upperBound...])
    if let title = rest.range(of: " \(hour.title)", options: .backwards) { rest = String(rest[..<title.lowerBound]) }
    let line = collapsedWhitespace(LatinOrthography.normalize(rest))
    return line.isEmpty ? nil : line
}

/// Every date 2025-2040, the hours from Matins to None: our title block's third line is
/// DO's (`LiturgicalCalendarEngine.headLine`).
@Test(arguments: [CanonicalHour.matutinum, .laudes, .prima, .tertia, .sexta, .nona])
func dayHoursFullRangeHeadLineAudit(hour: CanonicalHour) async throws {
    guard let bundle = RealCorpus.bundle, try await OracleFixture.shared.hourYear(hour: hour, year: 2040) != nil else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    let onlyYear = ProcessInfo.processInfo.environment["BREVIARIUM_AUDIT_YEAR"].flatMap(Int.init)

    var byProblem: [String: [String]] = [:]
    var daysChecked = 0
    for year in 2025...2040 where onlyYear == nil || onlyYear == year {
        guard let archive = try await OracleFixture.shared.hourYear(hour: hour, year: year) else { continue }
        var (day, month, y) = (1, 1, year)
        while y == year {
            let date = String(format: "%04d-%02d-%02d", y, month, day)
            if let text = archive["\(year)/\(date)_priestN_bilingual.tsv"], let head = OracleFixture.rows(text).first {
                daysChecked += 1
                let expected = fixtureHeadLine(head.latin, hour: hour)
                let context = ConditionalContextBuilder.build(
                    day: day, month: month, year: y, ad: hour.doName, rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
                )
                let actual = LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar)
                    .headLine(for: hour, day: day, month: month, year: y)
                    .map { collapsedWhitespace(LatinOrthography.normalize($0)) }
                if actual != expected {
                    byProblem["DO \(expected ?? "-") | engine \(actual ?? "-")", default: []].append(date)
                }
            }
            (day, month, y) = Computus.addDays(1, day: day, month: month, year: y)
        }
    }
    let report = byProblem.sorted { $0.value.count > $1.value.count }.prefix(40)
        .map { "  \($0.value.count)x, e.g. \($0.value[0]): \($0.key)" }.joined(separator: "\n")
    #expect(daysChecked > (onlyYear == nil ? 5_800 : 360), "\(hour): checked \(daysChecked)")
    #expect(byProblem.isEmpty, "\n\(hour): \(byProblem.values.map(\.count).reduce(0, +)) dates\n\(report)")
}
