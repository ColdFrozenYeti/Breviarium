import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit, initially mistaken for a missing "Office of
// the Dead" feature: when 2 November falls on a Sunday (a dominical-letter-"e" year,
// e.g. 2025), the real DO engine transfers All Souls' Day away entirely -- 2 November is
// instead "Secunda die infra Octavam Omnium Sanctorum" (rank 2, Semiduplex), which
// naturally loses to the Sunday (rank ~5) through completely ordinary occurrence rules,
// no special-casing needed once the transfer table entry itself is read correctly
// (`TransferResolver.parseEntriesTreatsATrailingEmptyVersionListAsUniversal`'s own real
// root cause). Confirmed real for 2 November 2025: the real fixture's own winner is
// "Dominica XXI Post Pentecosten", with a plain Sunday Oratio ("Famíliam tuam,
// quǽsumus, Dómine..."), not any Requiem/Office-of-the-Dead text at all.

@Test func allSoulsIsTransferredAwayWhenTwoNovemberFallsOnASunday() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()

    let candidates = calendar.candidates(day: 2, month: 11, year: 2025)
    #expect(candidates == ["11-02oct"])

    let context = ConditionalContextBuilder.build(
        day: 2, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let occurrence = Occurrence(corpus: corpus, context: context, calendar: calendar)
    let result = try #require(occurrence.resolve(day: 2, month: 11, year: 2025))
    #expect(!result.sanctoralWins)

    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 2, month: 11, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Famíliam tuam") })
    #expect(!prose.contains { $0.contains("fidélium defunctórum") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-02"))
    #expect(fixture.contains("Dominica XXI Post Pentecosten"))
    #expect(fixture.contains("Famíliam tuam"))
}
