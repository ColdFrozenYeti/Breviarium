import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `getcommemoratio`'s own "No Commemoratio"
// rule check (`orationes.pl:655-660`) was never ported -- `$rule` there is the *winning*
// office's own [Rule] text, and several very high-rank proper offices (Corpus Christi,
// Christmas, Circumcision) carry a bare "No Commemoratio" directive in their own [Rule]
// that suppresses any commemoration outright, regardless of what would otherwise be a
// perfectly eligible candidate. This project's engine had no equivalent check at all, so
// any date where one of these offices wins and something is nominally commemorated
// (per the title line DO still generates) wrongly rendered that commemoration's content
// anyway.

@Test func corpusChristiSuppressesStJohnBaptistsCommemoration() async throws {
    // 24 June 2038: Corpus Christi's own first Vespers, commemorating St John Baptist's
    // Nativity "de sequenti". Tempora/Pent01-4.txt's own [Rule] includes bare "No
    // Commemoratio". Real fixture shows no commemoration at all -- straight from Oratio
    // to Conclusio -- despite the title's own header still naming it.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 24, month: 6, year: 2038, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 6, year: 2038, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2038, date: "2038-06-24"))
    #expect(fixture.contains("Festum Sanctissimi Corporis Christi"))
    #expect(!fixture.contains("Ingrésso Zacharía"))
}

@Test func christmasSuppressesTheNativityOctaveSundayCommemoration() async throws {
    // 25 December 2027 (Christmas Day itself). Sancti/12-25.txt's own [Rule] includes
    // bare "No commemoratio". Real fixture shows no commemoration at all.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 25, month: 12, year: 2027, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 25, month: 12, year: 2027, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-12-25"))
    #expect(!fixture.contains("Dum médium siléntium"))
}

@Test func circumcisionSuppressesTheHolyNameCommemoration() async throws {
    // 1 January 2028. Sancti/01-01.txt's own [Rule] includes bare "no commemoratio".
    // Real fixture shows no commemoration at all.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 1, month: 1, year: 2028, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 1, month: 1, year: 2028, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.isEmpty)

    // Note: "Sit nomen Dómini benedíctum" is *not* a safe negative assertion here -- it's
    // Psalm 112:2, part of the ordinary Vespers psalmody every day, real or not. The
    // rubric heading text itself is the reliable signal of no commemoration.
    let fixture = try #require(try await OracleFixture.shared.main(year: 2028, date: "2028-01-01"))
    #expect(!fixture.contains("Commemoratio Sanctissimi Nominis Iesu"))
}

@Test func stJosephStillCommemoratesInAnOrdinaryTransferYearRegardlessOfThisRule() async throws {
    // 19 March 2028: confirms the new suppression doesn't wrongly catch an ordinary
    // commemoration -- "Dominica III in Quadragesima" (Tempora/Quad3-0) carries no "No
    // Commemoratio" directive of its own, so St Joseph's own commemoration still renders.
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
