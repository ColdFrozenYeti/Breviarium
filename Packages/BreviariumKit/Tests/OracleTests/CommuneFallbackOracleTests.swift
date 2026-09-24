import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// `HourAssemblerTests.anExCommunesIndexedAntVesperaIsUsedForPsalmody`'s own doc comment
// flagged the "ex"-type Commune psalm-antiphon fallback as traced from source
// (`psalmi.pl`'s `getproprium('Ant Vespera 3', ...)`, gated to `$communetype =~ /ex/`)
// but not confirmed against a real fixture -- this closes that gap.

@Test func exTypeCommuneReferenceReachesThePlainAntVesperaFor22February2025() async throws {
    // In Cathedra S. Petri Apostoli (`Sancti/02-22`, `;;Duplex majus;;4;;ex C4`) defines
    // no `[Ant Vespera]` of its own -- the real fixture's first psalm antiphon is
    // `Commune/C4.txt`'s own plain `[Ant Vespera]` ("Ecce sacérdos magnus..."),
    // confirming the "ex" gate really does let a psalm antiphon reach the Commune for a
    // real date, not just the already-confirmed Oratio/Magnificat-antiphon cases.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 22, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 22, month: 2, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let antiphonTexts = psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
    #expect(antiphonTexts.contains { $0.contains("Ecce sacérdos magnus") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-22"))
    #expect(fixture.contains("In Cathedra S. Petri Apostoli"))
    #expect(fixture.contains("Ecce sacérdos magnus"))
}
