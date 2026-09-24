import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Hold-out year: every date of 2044, priest off and on, against Divinum Officium's own
// render at the pinned commit (`data/oracle-fixtures/holdout/2044.tar.gz`,
// `scripts/generate-holdout-fixtures.sh`). 2044 lies outside the 2025-2040 range every
// engine fix so far was traced and measured against, so this is an out-of-sample check,
// and the only full-year check of the priest form ("Dóminus vobíscum" in place of
// "Dómine, exáudi oratiónem meam"). A leap year, with Easter on 17 April.
//
// Each date and priest setting is its own test case, so a failure names the exact day.
// Each case runs the same two checks as the full-range audits:
// `vespersFullRangeContentAudit` (every rendered text piece appears in the fixture) and
// `vespersFullRangeCommemorationAudit` (the same number of commemoration blocks, with
// matching titles, in the Oratio section).

private let holdoutYear = 2044

private let holdoutDates: [String] = {
    var dates: [String] = []
    var (day, month, year) = (1, 1, holdoutYear)
    while year == holdoutYear {
        dates.append(String(format: "%04d-%02d-%02d", year, month, day))
        (day, month, year) = Computus.addDays(1, day: day, month: month, year: year)
    }
    return dates
}()

@Test func holdout2044CoversEveryDayOfTheLeapYear() {
    #expect(holdoutDates.count == 366)
}

@Test(arguments: holdoutDates, [false, true])
func holdout2044VespersMatchesDivinumOfficium(date: String, priest: Bool) async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let parts = date.split(separator: "-").compactMap { Int($0) }
    let (year, month, day) = (parts[0], parts[1], parts[2])
    let fixture = try #require(
        try await OracleFixture.shared.holdout(year: year, date: date, priest: priest),
        "missing hold-out fixture for \(date) priest=\(priest); run scripts/generate-holdout-fixtures.sh \(year)"
    )

    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let hour = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(
        day: day, month: month, year: year, priest: priest
    ))

    let present = Set(hour.sections.filter { !$0.units.isEmpty }.map(\.kind))
    for kind in [Section.Kind.psalmodia, .canticum, .oratio] {
        #expect(present.contains(kind), "\(date) priest=\(priest): no \(kind) section")
    }

    let contentMismatches = mismatches(hour: hour, fixtureText: fixture)
    #expect(contentMismatches.isEmpty, "\(date) priest=\(priest): \(contentMismatches.joined(separator: " | "))")

    let oratioSection = fixtureOratioSection(fixture) ?? ""
    let expectedCount = oratioSection.components(separatedBy: "Commemoratio ").count - 1
    let ours = renderedCommemorationRubrics(hour)
    #expect(ours.count == expectedCount, "\(date) priest=\(priest): fixture has \(expectedCount) commemoration(s), engine has \(ours)")
    for title in ours {
        #expect(oratioSection.contains(title), "\(date) priest=\(priest): \(title) not in the fixture's Oratio section")
    }
}
