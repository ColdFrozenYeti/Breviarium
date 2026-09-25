import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the third deferred concurrence cluster,
// "Dec-29 Christmas-Octave-Sunday"): in the years Christmas falls on a Sunday (2033,
// 2039), no Sunday falls between 26 and 31 December, and "Dominica Infra Octavam
// Nativitatis" is kept on Friday 30 December instead (`Tabulae/Transfer/b.txt`/`g.txt`,
// `12-30=Tempora/Nat1-0;;... 1960 ...`, already applied by `SanctoralCalendar`). Its
// first Vespers should then pre-empt 29 December's own.
//
// `concurrence()`'s first-Vespers threshold (`horascommon.pl:974-977`) is
// `$cwrank[2] < (($cwrank[0] =~ /Dominica/i || ($cwinner{Rule} =~ /Festum Domini/i &&
// $dayofweek == 6)) ? 5 : 6)` -- keyed off tomorrow's *title*, not its weekday. This
// project used `tomorrow.isSunday`, so the Friday-kept Sunday (rank 5.4) met the I.
// classis threshold of 6 and lost. With the title-based threshold of 5 it clears, and
// `Nat1-0` (5.4) outranks `Nat29` (5).

private func christmasOctaveConcurrence(day: Int, month: Int, year: Int) throws -> (ConcurrenceResult, Hour) {
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

@Test func christmasOctaveSundayKeptOnFridayHasFirstVespers() async throws {
    // 29 December 2033 (Thursday; Christmas 2033 was a Sunday). Real fixture: "Dominica
    // Infra Octavam Nativitatis ~ II. classis Vespera de sequenti." with the Sunday's own
    // chapter "Gal 4:1-2 Fratres: Quanto témpore heres párvulus est..." and collect
    // "Omnípotens sempitérne Deus, dírige actus nostros in beneplácito tuo...".
    guard RealCorpus.bundle != nil else { return }
    let (result, hour) = try christmasOctaveConcurrence(day: 29, month: 12, year: 2033)
    #expect(result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Nat1-0")
    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })
    #expect(capitulumReading(capitulum).hasPrefix("Gal 4:1-2 Fratres: Quanto témpore heres párvulus est"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2033, date: "2033-12-29"))
    #expect(fixture.hasPrefix("Dominica Infra Octavam Nativitatis ~ II. classis Vespera de sequenti."))
    #expect(fixture.contains("Gal 4:1-2 Fratres: Quanto témpore heres párvulus est"))
}

@Test func twentyNinthDecemberKeepsItsOwnVespersWhenTheOctaveSundayIsOnSunday() async throws {
    // 29 December 2026 (Tuesday; the Octave Sunday was 27 December). Real fixture: "Diei
    // V infra Octavam Nativitatis ~ II. classis Ad Vesperas" -- 29 December's own Vespers.
    guard RealCorpus.bundle != nil else { return }
    let (result, _) = try christmasOctaveConcurrence(day: 29, month: 12, year: 2026)
    #expect(!result.isFirstVespersOfTomorrow)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-12-29"))
    #expect(fixture.hasPrefix("Diei V infra Octavam Nativitatis ~ II. classis Ad Vesperas"))
}
