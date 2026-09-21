import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `specials.pl:60-81`'s own "Capitulum Versum
// 2" rule replaces the whole Capitulum/Hymnus/Versus group with a single `Versus (In
// loco Capituli)` section built from the office's own `[Versum 2]`, whose content is
// itself an antiphon-formatted line, not a genuine versicle/response pair. An earlier
// pass assumed no Vespers-relevant date had an *unqualified* "Capitulum Versum 2" rule
// (Holy Saturday's own is qualified "ad Laudes tantum", so it never reaches Vespers) --
// wrong: the whole Easter Octave (Easter Sunday through Low Sunday) chain-extends
// Tempora/Pasc0-0's own plain, unqualified "Capitulum Versum 2;" via "Rule: ex Pasc0-0",
// so it applies at Vespers throughout the Octave. Confirmed real for 20 April 2025
// (Easter Sunday): the real fixture's own `[Versum 2]`, "Ant. Hæc dies * quam fecit
// Dóminus: exsultémus et lætémur in ea.", replaces the normal triad entirely.

@Test func easterSundayReplacesCapitulumHymnusVersusWithVersum2() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 20, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 20, month: 4, year: 2025, priest: false))

    #expect(!hour.sections.contains { $0.kind == .capitulum })
    #expect(!hour.sections.contains { $0.kind == .hymnus })
    let versus = try #require(hour.sections.first { $0.kind == .versus })
    let antiphons = versus.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Hæc dies") && $0.contains("quam fecit Dóminus") })
    #expect(!antiphons.contains { $0.hasPrefix("Ant.") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-20"))
    #expect(fixture.contains("Hæc dies"))
    #expect(fixture.contains("quam fecit Dóminus"))
}
