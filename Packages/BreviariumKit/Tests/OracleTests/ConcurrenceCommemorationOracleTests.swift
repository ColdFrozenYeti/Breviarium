import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a real device test, not a synthetic fixture: `Commemorations` was wrongly
// commemorating *any* office displaced by tomorrow's first Vespers, when the real rule
// (`horascommon.pl`, see `Commemorations.resolve`'s own citation) only does that when
// tomorrow pre-empted by outright numeric rank superiority -- not when it won via the
// Sunday/Festum-Domini-specific threshold. Three real dates confirm the distinction.

@Test func stJanuariusIsNotCommemoratedWhenSundaysFirstVespersPreEmptsIt() async throws {
    // 19 September 2026 (Saturday): S. Ianuarii (Duplex, rank 3) loses its own second
    // Vespers to Sunday XVII post Pentecosten's first Vespers -- the real fixture shows
    // no commemoration at all ("Vespera de sequenti; nihil de præcedenti").
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 9, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let result = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: 19, month: 9, year: 2026)
    #expect(result.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-09-19"))
    #expect(fixture.contains("nihil de præcedenti"))
    #expect(!fixture.contains("Commemoratio"))
}

@Test func adventEmberSaturdayIsNotCommemoratedDespiteItsHighRank() async throws {
    // 20 December 2025 (Saturday, Ember Saturday in Advent): rank 4.9 under 1960 --
    // well above the old ranklimit of 2 this bug used -- yet the real fixture still
    // shows no commemoration at all when the 4th Sunday of Advent's first Vespers
    // pre-empts it, confirming the exclusion isn't about rank, but about *why* tomorrow
    // won (a Major Sunday, not an outright numeric win).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 20, month: 12, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let result = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: 20, month: 12, year: 2025)
    #expect(result.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-12-20"))
    #expect(!fixture.contains("Commemoratio"))
}

@Test func aNonSundayFeastPreEmptingASundayDoesCommemorateIt() async throws {
    // 28 June 2026 (an ordinary Sunday): its own second Vespers is pre-empted by
    // SS. Petri et Pauli's first Vespers (29 June, I. classis, titled neither
    // "Dominica" nor tagged Festum Domini) -- the real fixture *does* commemorate the
    // displaced Sunday directly ("Commemoratio: Dominica V Post Pentecosten"),
    // confirming the distinction is genuinely about why tomorrow won.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 28, month: 6, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let result = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: 28, month: 6, year: 2026)
    #expect(result.contains { $0.path.hasPrefix("Tempora/") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-06-28"))
    #expect(fixture.contains("Commemoratio: Dominica V Post Pentecosten"))
}
