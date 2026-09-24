import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: a bare `_`-only line is DO's own general
// block-break marker (the same convention `hymnStanzas` already treats as a stanza
// boundary, dropped rather than shown), but `unitsFromResolvedText` (used for the
// Oratio/Commemoratio text) only ever filtered *empty* lines, not this one -- real
// example, `Sancti/02-22`'s own `[Oratio]`, where a lone `_` line separates the main
// collect's own `$Qui vivis` ending from the `@...:Commemoratio4` cross-reference that
// follows it.

@Test func oratioDropsABareUnderscoreBlockBreakLine() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 22, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 22, month: 2, year: 2025, priest: false))

    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    #expect(!oratio.units.contains { unit in
        if case .prose(let text, _) = unit { return text == "_" } else { return false }
    })
    #expect(oratio.units.contains { unit in
        if case .rubric(let text, _) = unit { return text == "Commemoratio S. Pauli Apostoli" } else { return false }
    })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-22"))
    #expect(fixture.contains("Commemoratio S. Pauli Apostoli"))
}
