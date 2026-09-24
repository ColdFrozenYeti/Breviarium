import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (re-diagnosing a case the transferred-office
// commemoration dedup fix earlier this session didn't cover): `horascommon.pl:229-232`'s
// own `transfered()` check runs immediately after fetching a day's own Kalendaria
// candidate, *before* any rank comparison -- an office that's itself been transferred to
// a different date this year (`SanctoralCalendar.isTransferredAwayThisYear`) never
// becomes a commemoration candidate on its own natural date at all, regardless of rank.
// `Commemorations.runnersUp` only ever checked whether a same-day candidate *lost*
// occurrence, never whether it had already been excluded from candidacy entirely.

@Test func transferredAwayOfficeIsNotCommemoratedOnItsOwnDate() async throws {
    // 19 March 2035: Easter falls unusually early (25 March) that year, pushing 19
    // March into Holy Week itself ("Feria Secunda Hebdomadæ Sanctæ ~ I. classis").
    // St Joseph is transferred to 3 April that year (`Transfer/325.txt`'s own
    // "04-03=03-19"). Real DO instrumentation confirms St Joseph never even reaches
    // the ordinary same-day-loser commemoration path -- the real fixture shows no
    // commemoration at all, just the plain ferial Oratio straight into the Conclusio.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 3, year: 2035, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 3, year: 2035, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(!rubrics.contains { $0.contains("Ioseph") })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon = unit { return "antiphon" } else { return nil }
    }
    #expect(antiphons.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-03-19"))
    #expect(fixture.contains("Feria Secunda Hebdomadæ Sanctæ"))
    #expect(!fixture.contains("Commemoratio"))
}

@Test func stJosephStillCommemoratesInAnOrdinaryTransferYear() async throws {
    // 19 March 2028 (an ordinary year -- St Joseph naturally loses same-day occurrence
    // to "Dominica III in Quadragesima" and is transferred to 20 March that year,
    // via the ordinary same-day-loser path, not excluded entirely). Confirms the new
    // isTransferredAwayThisYear exclusion doesn't wrongly suppress this case.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 3, year: 2028, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 3, year: 2028, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Exsúrgens Ioseph a somno") })
}
