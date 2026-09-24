import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the All Souls cluster, the last remaining
// Conclusio mismatch): horascommon.pl's own "Office of All Souls' day ends after None"
// rule removes All Souls from sanctoral candidacy entirely when 2 November falls on a
// Saturday -- this project's engine had no such exclusion, so it kept All Souls (and its
// own Special Conclusio) as the day's winner regardless of the date.

@Test func allSoulsIsSuppressedWhenNovemberSecondIsASaturday() async throws {
    // 2 November 2030 (a Saturday). The real fixture's own Vespers is the ordinary
    // "Dominica XXI Post Pentecosten... Vespera de sequenti" with a plain ferial
    // Conclusio ending -- not All Souls' own "Conclusio specialis".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 2, month: 11, year: 2030, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 2, month: 11, year: 2030, priest: false))
    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })

    let rubrics = conclusio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(!rubrics.contains { $0.contains("Conclusio specialis") })
    let versicleResponses = conclusio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versicleResponses.contains { $0.0.contains("Benedicámus Dómino") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2030, date: "2030-11-02"))
    #expect(!fixture.contains("Conclusio specialis"))
    #expect(fixture.contains("Benedicámus Dómino"))
}

@Test func allSoulsStillWinsItsOwnDayOnAnOrdinaryWeekday() async throws {
    // 3 November 2025 (transferred All Souls, a Monday). Confirms the Saturday-only
    // guard doesn't disturb the ordinary case: All Souls still wins and still uses its
    // own Special Conclusio.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 3, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 3, month: 11, year: 2025, priest: false))
    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })

    let rubrics = conclusio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.contains { $0.contains("Conclusio specialis") })
}
