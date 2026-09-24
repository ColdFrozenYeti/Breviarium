import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the last four dates of the "Epiphany/Holy-
// Family" deferred cluster). In 2030 and 2036, 13 January -- the Baptism of the Lord
// (`Sancti/01-13`, "Duplex II. classis", rank 5, "Festum Domini") -- is a Sunday, so Holy
// Family (`Tempora/Epi1-0`, rank 5) is kept the same day. `occurrence()`'s 1960 rule
// "II. cl. feasts of the Lord and all I. cl. feasts beat II. cl. Sundays"
// (`horascommon.pl:487-493`) sits inside `elsif ($trank[0] =~ /Dominica/i && $dayname[0]
// !~ /Nat1/i)` -- the temporal office's *title*, not the weekday. Holy Family's title,
// "Sanctæ Familiæ Iesu Mariæ Ioseph", has no "Dominica", so the Baptism doesn't outrank
// it (5 is not > 5) and Holy Family wins. This project tested the weekday, so the Baptism
// won both 13 January and the first Vespers the evening before. Earlier attempts at this
// cluster (Phase 2, both reverted) went at the concurrence cascade; the real gap was in
// occurrence.

private func holyFamilyVespers(day: Int, month: Int, year: Int) throws -> (ConcurrenceResult, Hour) {
    let bundle = try #require(RealCorpus.bundle)
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let result = try #require(Concurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year))
    let hour = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(day: day, month: month, year: year, priest: false))
    return (result, hour)
}

private func holyFamilyCapitulumMatches(_ hour: Hour) -> Bool {
    guard let capitulum = hour.sections.first(where: { $0.kind == .capitulum }) else { return false }
    return capitulum.units.contains { unit in
        if case .prose(let text, _) = unit { return text.hasPrefix("Luc 2:51 Descéndit Iesus cum María et Ioseph") }
        return false
    }
}

@Test func holyFamilyBeatsTheBaptismOnSundayThirteenthJanuary() async throws {
    // 13 January 2030 (Sunday). Real fixture: "Sanctæ Familiæ Jesu Mariæ Joseph ~ II.
    // classis Ad Vesperas ... Luc 2:51 Descéndit Iesus cum María et Ioseph...".
    guard RealCorpus.bundle != nil else { return }
    let (result, hour) = try holyFamilyVespers(day: 13, month: 1, year: 2030)
    #expect(!result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Epi1-0")
    #expect(holyFamilyCapitulumMatches(hour))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2030, date: "2030-01-13"))
    #expect(fixture.hasPrefix("Sanctæ Familiæ Jesu Mariæ Joseph ~ II. classis Ad Vesperas"))
    #expect(fixture.contains("Luc 2:51 Descéndit Iesus cum María et Ioseph"))
}

@Test func holyFamilyHasFirstVespersBeforeSundayThirteenthJanuary() async throws {
    // 12 January 2036 (Saturday). Real fixture: "Sanctæ Familiæ Jesu Mariæ Joseph ~ II.
    // classis Commemoratio ad Laudes tantum: Commemoratio Baptismatis Domini Nostri Jesu
    // Christi Vespera de sequenti; nihil de præcedenti".
    guard RealCorpus.bundle != nil else { return }
    let (result, hour) = try holyFamilyVespers(day: 12, month: 1, year: 2036)
    #expect(result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Epi1-0")
    #expect(holyFamilyCapitulumMatches(hour))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2036, date: "2036-01-12"))
    #expect(fixture.hasPrefix("Sanctæ Familiæ Jesu Mariæ Joseph ~ II. classis Commemoratio ad Laudes tantum"))
    #expect(fixture.contains("Vespera de sequenti; nihil de præcedenti"))
}
