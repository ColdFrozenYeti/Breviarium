import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `specials.pl:378-383`'s own "Special
// conclusions, e.g. on All Souls' day" -- when the winning office's own [Rule] says
// "Special Conclusio", the whole Conclusio group's content is the winning office's own
// [Conclusio] section verbatim, replacing the ordinary skeleton's generic one entirely.
// Not implemented at all before this fix, so the ordinary skeleton always rendered
// instead.

@Test func allSoulsUsesItsOwnConclusioNotTheOrdinarySkeletonOne() async throws {
    // 3 November 2025 (All Souls' Day proper, transferred here since 2 November is a
    // Sunday that year). Sancti/11-02's own [Rule] has "Special Conclusio"; its own
    // [Conclusio] is "Conclusio specialis" / "&Gloria" / "V. Requiéscant in pace. R.
    // Amen." -- not the ordinary "Dómine, exáudi... Benedicámus Dómino..." skeleton.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 3, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 3, month: 11, year: 2025, priest: false))
    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })

    let versicleResponses = conclusio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versicleResponses.contains { $0.0.contains("Requiéscant in pace") })
    #expect(!versicleResponses.contains { $0.0.contains("Benedicámus Dómino") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-03"))
    #expect(fixture.contains("Conclusio specialis"))
    #expect(fixture.contains("Requiéscant in pace"))
}
