import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `festalFifthPsalmNumber` (the `[Rule]`'s
// own `Psalm5 Vespera(3)=` override) was only ever consulted for the *unnumbered*
// antiphon case -- but the real Perl (`psalmi.pl:560-586`) checks it unconditionally
// for the 5th psalm slot, overriding even an antiphon that already carries its own
// explicit `;;N` tag.

@Test func explicitlyNumberedFifthAntiphonStillGetsOverriddenByItsOwnRuleTag() async throws {
    // 15 June 2025 (Trinity Sunday, second Vespers): Tempora/Pent01-0's own
    // [Ant Vespera] has five explicitly-numbered antiphons, the fifth tagged ";;116"
    // directly -- but its own [Rule] has "Psalm5 Vespera3=113" (second Vespers'
    // own override, distinct from "Psalm5 Vespera=116" for first Vespers), so the
    // real fifth psalm is 113, not the antiphon's own literal tag.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 15, month: 6, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 15, month: 6, year: 2025, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles == ["Psalmus 109 [1]", "Psalmus 110 [2]", "Psalmus 111 [3]", "Psalmus 112 [4]", "Psalmus 113 [5]"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-06-15"))
    #expect(fixture.contains("Psalmus 113"))
    #expect(!fixture.contains("Psalmus 116"))
}
