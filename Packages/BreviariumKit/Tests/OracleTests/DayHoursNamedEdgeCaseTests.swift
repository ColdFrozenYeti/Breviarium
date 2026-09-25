import Foundation
import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Beta 2: `CLAUDE.md`'s named edge cases, per day hour where they apply, each against
// Divinum Officium's bilingual page for that date (`hours/<Hour>/`): content, coverage,
// pairing and title, as `dayHoursFullRangeAudit` checks them over the whole range. Each
// case is one readable line; a failure names the hour and the date.

struct DayHourCase: CustomStringConvertible, Sendable {
    var hour: CanonicalHour
    var date: String
    var what: String
    var description: String { "\(hour.doName) \(date): \(what)" }
}

let dayHourNamedCases: [DayHourCase] = [
    // Christmas Eve, Christmas and its octave, 1 January, Epiphany.
    DayHourCase(hour: .laudes, date: "2026-12-24", what: "Christmas Eve"),
    DayHourCase(hour: .prima, date: "2026-12-25", what: "Christmas, Prime"),
    DayHourCase(hour: .tertia, date: "2026-12-25", what: "Christmas, Terce"),
    DayHourCase(hour: .laudes, date: "2026-12-28", what: "Holy Innocents in the octave"),
    DayHourCase(hour: .laudes, date: "2027-01-01", what: "Octave day of Christmas"),
    DayHourCase(hour: .sexta, date: "2027-01-06", what: "Epiphany, Sext"),
    // Septuagesima, Ash Wednesday, Passiontide, Holy Week and the Triduum.
    DayHourCase(hour: .completorium, date: "2025-02-15", what: "Compline before Septuagesima: no Alleluia"),
    DayHourCase(hour: .laudes, date: "2025-03-05", what: "Ash Wednesday, the preces"),
    DayHourCase(hour: .laudes, date: "2025-04-11", what: "Passion Friday: the Seven Sorrows from the winner"),
    DayHourCase(hour: .completorium, date: "2026-04-02", what: "Holy Thursday, Compline in its own form"),
    DayHourCase(hour: .tertia, date: "2026-04-03", what: "Good Friday, Terce"),
    DayHourCase(hour: .completorium, date: "2026-04-04", what: "Holy Saturday, Compline"),
    // The Easter octave, Ascension, the Pentecost octave.
    DayHourCase(hour: .laudes, date: "2025-04-23", what: "Easter octave: no saint commemorated"),
    DayHourCase(hour: .laudes, date: "2025-04-25", what: "St Mark: the Greater Litanies"),
    DayHourCase(hour: .nona, date: "2025-05-29", what: "Ascension, None"),
    DayHourCase(hour: .laudes, date: "2025-06-08", what: "Pentecost: the English hymn's extra stanza"),
    DayHourCase(hour: .prima, date: "2025-06-15", what: "Trinity Sunday: the Athanasian Creed"),
    // Corpus Christi, the Sacred Heart, Christ the King.
    DayHourCase(hour: .laudes, date: "2025-06-19", what: "Corpus Christi"),
    DayHourCase(hour: .tertia, date: "2025-06-27", what: "Sacred Heart"),
    DayHourCase(hour: .laudes, date: "2025-10-26", what: "Christ the King"),
    // All Saints and All Souls.
    DayHourCase(hour: .laudes, date: "2025-11-01", what: "All Saints"),
    DayHourCase(hour: .tertia, date: "2025-11-03", what: "All Souls (transferred): its own Terce"),
    DayHourCase(hour: .completorium, date: "2025-11-03", what: "All Souls: its own Compline"),
    DayHourCase(hour: .prima, date: "2030-11-02", what: "All Souls on a Saturday keeps the day hours"),
    // Ember days, Our Lady on Saturday.
    DayHourCase(hour: .laudes, date: "2026-09-16", what: "Ember Wednesday of September, the title-block example"),
    DayHourCase(hour: .prima, date: "2026-09-16", what: "16 September 2026, Prime"),
    DayHourCase(hour: .laudes, date: "2025-05-03", what: "Our Lady on Saturday in Paschaltide"),
    DayHourCase(hour: .tertia, date: "2025-01-18", what: "Our Lady on Saturday"),
    // 8 December on an Advent Sunday, transfers, leap-year February, early and late Easter.
    DayHourCase(hour: .laudes, date: "2030-12-08", what: "Immaculate Conception on an Advent Sunday"),
    DayHourCase(hour: .laudes, date: "2027-04-05", what: "Annunciation transferred, St Vincent commemorated"),
    DayHourCase(hour: .sexta, date: "2035-03-19", what: "Holy Monday 2035: St Joseph impeded"),
    DayHourCase(hour: .laudes, date: "2028-02-29", what: "Leap-year February"),
    DayHourCase(hour: .laudes, date: "2038-04-25", what: "The latest Easter"),
    DayHourCase(hour: .completorium, date: "2035-03-25", what: "An early Easter"),
    DayHourCase(hour: .laudes, date: "2033-06-23", what: "The Baptist's vigil suppressed by the Sacred Heart"),
]

@Test(arguments: dayHourNamedCases)
func dayHourNamedEdgeCase(_ testCase: DayHourCase) async throws {
    let bundle = try #require(RealCorpus.bundle)
    let parts = testCase.date.split(separator: "-").compactMap { Int($0) }
    let archive = try #require(try await OracleFixture.shared.hourYear(hour: testCase.hour, year: parts[0]))
    let text = try #require(archive["\(parts[0])/\(testCase.date)_priestN_bilingual.tsv"])
    let (assembled, title) = assembleDayHour(
        testCase.hour, day: parts[2], month: parts[1], year: parts[0], priest: false, bundle: bundle,
        corpus: bundle.makeLatinCorpus(psalter: .vulgate), english: bundle.makeEnglishCorpus(), calendar: bundle.makeSanctoralCalendar()
    )
    let hour = try #require(assembled)
    var report = DayHourAuditReport()
    report.add(hour: hour, rows: withoutMartyrology(OracleFixture.rows(text)), title: title, date: testCase.date)
    #expect(report.text.isEmpty, "\n\(testCase):\n\(report.text)")
}
