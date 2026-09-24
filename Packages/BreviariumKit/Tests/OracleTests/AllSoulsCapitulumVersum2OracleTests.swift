import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the All Souls cluster): the "Capitulum
// Versum 2" replacement (specials.pl:60-81) always built a single `.antiphon` unit from
// the office's own [Versum 2], correct for Easter Sunday's own antiphon-formatted
// replacement ("Ant. Haec dies...") but wrong for All Souls, whose own [Versum 2] (->
// [Versum 1] via Commune/C9's own cross-reference) is a genuine "V. .../R. ..." pair.
// The engine joined it into one prose-like string with a literal "R." embedded instead
// of a real .versicleResponse unit.

@Test func allSoulsCapitulumVersum2IsAGenuineVersicleResponsePair() async throws {
    // 3 November 2025 (transferred All Souls' Day, since 2 November is a Sunday that
    // year). Sancti/11-02's own [Rule] has "Capitulum Versum 2 ad Laudes et Vesperas";
    // its own [Versum 2] chain (-> Commune/C9's [Versum 2] -> [Versum 1]) is "V. Audivi
    // vocem de caelo dicentem mihi. / R. Beati mortui qui in Domino moriuntur." -- the
    // real fixture's own "Versus (In loco Capituli)" heading shows these as a genuine
    // versicle/response pair, not a single joined antiphon line.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 3, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 3, month: 11, year: 2025, priest: false))
    let versus = try #require(hour.sections.first { $0.kind == .versus })

    let versicleResponses = versus.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versicleResponses.contains {
        $0.0.contains("Audívi vocem de cælo") && $0.1.contains("Beáti mórtui")
    })
    #expect(!versus.units.contains { if case .antiphon = $0 { true } else { false } })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-03"))
    #expect(fixture.contains("Audívi vocem de cælo dicéntem mihi"))
    #expect(fixture.contains("Beáti mórtui qui in Dómino moriúntur"))
}

@Test func easterStillUsesItsOwnAntiphonFormattedCapitulumVersum2() async throws {
    // 20 April 2025 (Easter Sunday). Tempora/Pasc0-0's own [Versum 2] is "Ant. Haec
    // dies * quam fecit Dominus: exsultemus et laetemur in ea." -- a genuine antiphon,
    // not a versicle/response pair. Confirms the fix's own first-line detection keeps
    // this case rendering as a single .antiphon unit, not wrongly parsed as V./R.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 20, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 20, month: 4, year: 2025, priest: false))
    let versus = try #require(hour.sections.first { $0.kind == .versus })

    let antiphons = versus.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Hæc dies") && $0.contains("exsultémus") })
    #expect(!versus.units.contains { if case .versicleResponse = $0 { true } else { false } })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-20"))
    #expect(fixture.contains("Hæc dies"))
}
