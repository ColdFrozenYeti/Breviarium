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
// Each case runs, for both psalters (Pius XII from `2044.tar.gz`, the Vulgate from the
// Latin column of `2044-bilingual.tar.gz`), the same checks as the full-range audits:
// `vespersFullRangeContentAudit` (every rendered text piece appears in the fixture) and
// `vespersFullRangeCommemorationAudit` (the same number of commemoration blocks, with
// matching titles, in the Oratio section), plus `vespersFullRangePsalmodyAudit`'s
// psalm-by-psalm titles and verse lists.

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
    let calendar = bundle.makeSanctoralCalendar()

    for psalter in Psalter.allCases {
        let label = "\(date) priest=\(priest) \(psalter)"
        let fixture = try #require(
            try await OracleFixture.shared.holdout(psalter: psalter, year: year, date: date, priest: priest),
            "missing hold-out fixture for \(label); run scripts/generate-holdout-fixtures.sh \(year) (Pius XII) or scripts/generate-fixture-set.sh holdout \(year) \(year) (Vulgate)"
        )

        let corpus = bundle.makeLatinCorpus(psalter: psalter)
        let context = ConditionalContextBuilder.build(
            day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
        )
        let hour = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(
            day: day, month: month, year: year, priest: priest
        ))

        let present = Set(hour.sections.filter { !$0.units.isEmpty }.map(\.kind))
        for kind in [Section.Kind.psalmodia, .canticum, .oratio] {
            #expect(present.contains(kind), "\(label): no \(kind) section")
        }

        let contentMismatches = mismatches(hour: hour, fixtureText: fixture)
        #expect(contentMismatches.isEmpty, "\(label): \(contentMismatches.joined(separator: " | "))")

        let psalmody = psalmodyMismatches(hour: hour, fixtureText: fixture)
        #expect(psalmody.isEmpty, "\(label): \(psalmody.joined(separator: " | "))")

        let oratioSection = fixtureOratioSection(fixture) ?? ""
        let expectedCount = oratioSection.components(separatedBy: "Commemoratio ").count - 1
        let ours = renderedCommemorationRubrics(hour)
        #expect(ours.count == expectedCount, "\(label): fixture has \(expectedCount) commemoration(s), engine has \(ours)")
        for title in ours {
            #expect(oratioSection.contains(title), "\(label): \(title) not in the fixture's Oratio section")
        }
    }

    // The English, against the Vulgate + English hold-out (`EnglishAuditOracleTests`).
    let rows = try #require(try await OracleFixture.shared.bilingualHoldout(year: year, date: date, priest: priest))
    let corpus = bundle.makeLatinCorpus(psalter: .vulgate)
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let bilingual = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar, englishCorpus: bundle.makeEnglishCorpus())
        .assembleVespers(day: day, month: month, year: year, priest: priest))
    let english = englishAudit(hour: bilingual, rows: rows)
    let label = "\(date) priest=\(priest) English"
    #expect(english.missingFromDO.isEmpty, "\(label): ours, not DO's: \(english.missingFromDO.map { "[\($0.0)] \($0.1)" })")
    #expect(english.uncovered.isEmpty, "\(label): DO's, not ours: \(english.uncovered)")
    #expect(english.uncoveredLatin.isEmpty, "\(label): DO's Latin, not ours: \(english.uncoveredLatin)")
    #expect(english.mispaired.isEmpty, "\(label): \(english.mispaired)")
    #expect(english.latinOnly.isEmpty, "\(label): Latin only: \(english.latinOnly.map { "[\($0.0)] \($0.1)" })")
}
