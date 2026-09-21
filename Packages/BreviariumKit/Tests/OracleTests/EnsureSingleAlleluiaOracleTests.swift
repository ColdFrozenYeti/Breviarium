import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `ensure_single_alleluia`
// (`LanguageTextTools.pm:78-96`, called from `postprocess_ant`/`postprocess_vr` for
// every antiphon and versicle/response throughout Paschaltide) *adds* a trailing
// ", allelúia." during Paschaltide whenever the text doesn't already end with one --
// the far more common case, since most proper antiphons carry no alleluia annotation of
// their own at all. `applyingSeasonalAlleluia` only ever handled *removing or
// unbracketing* an alleluia the source text already carried, never adding a missing
// one. Confirmed real for 28 April 2025 (S. Pauli a Cruce, within the weeks following
// the Easter Octave): the real fixture's own Magnificat antiphon reads "...cælo
// cóndidit ore, manu, allelúia.", where `Sancti/04-28.txt`'s own antiphon text ends
// plainly "...ore, manu." with no alleluia at all.

@Test func magnificatAntiphonGetsATrailingAllelujaDuringPaschaltideWhenMissingOne() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 28, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 28, month: 4, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("cælo cóndidit ore, manu, allelúia.") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-28"))
    #expect(fixture.contains("cælo cóndidit ore, manu, allelúia."))
}
