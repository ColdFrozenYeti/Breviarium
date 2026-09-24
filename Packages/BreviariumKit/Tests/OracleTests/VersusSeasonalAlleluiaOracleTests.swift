import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: a `Versum` can carry its own literal
// "(Allelúja.)" in the source text (real example: the Annunciation's own `[Versum 1]`,
// `Sancti/03-25.txt`, shared as-is between its ordinary occurrence and the far rarer
// occasion it falls within Paschaltide) rather than an inline `(sed tempore paschali)`
// conditional -- the same seasonal add/strip `applyingSeasonalAlleluia` already applies
// to antiphons never ran for `Versus` at all. Confirmed real for 24 March 2025 (first
// Vespers of the Annunciation, still Lent): the real fixture's own versicle/response
// reads "Ave, María, grátia plena." / "Dóminus tecum." with no "(Allelúja.)" at all.

@Test func versusStripsALiteralAllelujaOutsidePaschaltide() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 24, month: 3, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 3, year: 2025, priest: false))
    let versus = try #require(hour.sections.first { $0.kind == .versus })

    let versicleResponses = versus.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versicleResponses.contains { $0.0.contains("Ave, María, grátia plena") && !$0.0.contains("Allel") })
    #expect(versicleResponses.contains { $0.1.contains("Dóminus tecum") && !$0.1.contains("Allel") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-03-24"))
    #expect(fixture.contains("Ave, María, grátia plena."))
    #expect(!fixture.contains("Ave, María, grátia plena. (Allel"))
}
