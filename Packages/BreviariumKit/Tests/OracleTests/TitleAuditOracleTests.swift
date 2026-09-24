import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 1, B1-M5 carry-over: the day title's name line, which neither the content nor the
// commemoration audit compares. Its baseline showed two causes: the title followed the
// day's own office, not the one whose Vespers is prayed (tomorrow's on first Vespers), and
// it lacked the monthday suffix. `LiturgicalCalendarEngine.vespersDay` fixes both. DO prints it at the top of the page, before " ~ " and the
// rank (`horas.pl`'s headline), e.g. "Feria Tertia infra Hebdomadam XII post Octavam
// Pentecostes III. Augusti ~ IV. classis".

/// DO's title for the page: the fixture's text before " ~ ".
func fixtureTitle(_ fixtureText: String) -> String? {
    guard let range = fixtureText.range(of: " ~ ") else { return nil }
    return collapsedWhitespace(LatinOrthography.normalize(String(fixtureText[..<range.lowerBound])))
}

/// Every date 2025-2040 (Vulgate): our name line is DO's title.
@Test func vespersFullRangeTitleAudit() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()

    var byProblem: [String: [String]] = [:]
    var daysChecked = 0
    var (day, month, year) = (1, 1, 2025)
    while true {
        let dateLabel = String(format: "%04d-%02d-%02d", year, month, day)
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
        )
        let engine = LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar)
        if let liturgicalDay = engine.vespersDay(day: day, month: month, year: year),
            let fixtureText = try await OracleFixture.shared.range(psalter: .vulgate, year: year, date: dateLabel),
            let expected = fixtureTitle(fixtureText)
        {
            daysChecked += 1
            let actual = collapsedWhitespace(liturgicalDay.titleBlock.nameLine)
            if actual != expected { byProblem["DO \(expected) | engine \(actual)", default: []].append(dateLabel) }
        }
        if (day, month, year) == (31, 12, 2040) { break }
        (day, month, year) = Computus.addDays(auditStride, day: day, month: month, year: year)
        if year > 2040 { break }
    }

    let dateCount = byProblem.values.reduce(0) { $0 + $1.count }
    let report = byProblem.sorted { $0.value.count > $1.value.count }.prefix(40).map { problem, dates in
        "\(dates.count) date(s), e.g. \(dates.prefix(3).joined(separator: ", ")): \(problem.prefix(300))"
    }.joined(separator: "\n")
    #expect(daysChecked > 5_800 / auditStride, "expected the full 2025-2040 range, checked \(daysChecked)")
    #expect(byProblem.isEmpty, "\n\(dateCount) date(s) differ in \(byProblem.count) way(s):\n\(report)")
}

private func vespersTitle(day: Int, month: Int, year: Int) -> String? {
    guard let bundle = RealCorpus.bundle else { return nil }
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    return LiturgicalCalendarEngine(corpus: corpus, context: context, sanctoralCalendar: calendar)
        .vespersDay(day: day, month: month, year: year)?.titleBlock.nameLine
}

@Test func augustFeriaTitleHasItsMonthdaySuffix() throws {
    guard RealCorpus.bundle != nil else { return }
    #expect(vespersTitle(day: 18, month: 8, year: 2026) == "Feria Tertia infra Hebdomadam XII post Octavam Pentecostes III. Augusti")
}

@Test func saturdayEveningTitleIsTheSundaysFirstVespers() throws {
    guard RealCorpus.bundle != nil else { return }
    #expect(vespersTitle(day: 19, month: 9, year: 2026) == "Dominica XVII Post Pentecosten III. Septembris")
    #expect(vespersTitle(day: 24, month: 12, year: 2026) == "In Nativitate Domini")
}
