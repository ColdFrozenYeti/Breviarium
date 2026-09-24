import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the All Souls cluster): `assembleMagnificat`
// had no equivalent of `getantvers`'s own `$ind > 1` fallback (specials.pl:575-596),
// which tries the *swapped* index ([Ant (4-$ind)]) -- office then Commune -- before ever
// falling to the Major Special seasonal default. Without it, an office whose Magnificat
// antiphon lives at the *other* natural index (real for All Souls: reached via ind=3,
// but Commune/C9 only defines [Ant 1]) silently fell through to a wrong generic default.

@Test func allSoulsMagnificatAntiphonUsesTheSwappedIndexFallback() async throws {
    // 3 November 2025 (transferred All Souls' Day). Neither Sancti/11-02 nor its own
    // Commune (C9, via "ex C9") defines [Ant 3] (ind == 3, since All Souls' own Vespers
    // is reached as an ordinary second Vespers) -- but Commune/C9 does define [Ant 1],
    // "Omne quod dat mihi Pater, ad me veniet; et eum qui venit ad me, non eiciam
    // foras.", which the real fixture's own Magnificat antiphon matches exactly.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 3, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 3, month: 11, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })

    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Omne") && $0.contains("quod dat mihi Pater") })
    #expect(!antiphons.contains { $0.contains("quia respéxit Deus humilitátem meam") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-03"))
    #expect(fixture.contains("Omne") && fixture.contains("quod dat mihi Pater"))
}
