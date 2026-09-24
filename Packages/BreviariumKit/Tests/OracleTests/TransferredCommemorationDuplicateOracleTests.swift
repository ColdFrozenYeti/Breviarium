import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Oratio category pass): when a high-rank
// office loses same-day occurrence to a Sunday/Festum-Domini and is annually transferred
// (by `SanctoralCalendar`'s own transfer table -- the mechanism that moves a displaced
// Annunciation or St Joseph onto a later free day) onto the very next day, the same
// office qualified as a commemoration candidate through two independent mechanisms at
// once: `runnersUp` found it as an ordinary same-day loser on its own natural date
// (`ind: 3`), and `tomorrowsTiedFirstVespersCandidate` separately found it again as
// tomorrow's own occurrence winner once transferred (`ind: 1`). Real DO calls
// `getcommemoratio` exactly once for such a night, always with the transferred `ind: 1`
// (confirmed by live Perl instrumentation) -- this project's engine had been showing the
// office's commemoration *twice*, once correctly (its own `[Ant 1]`/`[Versum 1]`) and once
// wrongly (its own separate `[Ant 3]`/`[Versum 3]`, a different antiphon/versicle pairing
// the same office file also happens to define for other contexts).

@Test func transferredStJosephCommemoratesOnceNotTwice() async throws {
    // 19 March 2028: St Joseph (Duplex I classis) loses occurrence to "Dominica III in
    // Quadragesima" on its own natural date and is transferred to 20 March that year.
    // The real fixture's single commemoration antiphon/versicle: "Exsúrgens Ioseph a
    // somno..." / "Constítuit eum dóminum domus suæ. / Et príncipem omnis possessiónis
    // suæ." -- not also the office's own separate "Ecce fidélis servus..." / "Glória et
    // divítiæ in domo eius..." pairing.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 3, year: 2028, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 3, year: 2028, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.filter { $0.contains("Ioseph") }.count == 1)

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Exsúrgens Ioseph a somno") })
    #expect(!antiphons.contains { $0.contains("Ecce fidélis servus") })

    let pairs = oratio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Constítuit eum dóminum domus suæ") })
    #expect(!pairs.contains { $0.0.contains("Glória et divítiæ") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2028, date: "2028-03-19"))
    #expect(fixture.contains("Exsúrgens Ioseph a somno"))
    #expect(fixture.contains("Constítuit eum dóminum domus suæ"))
}
