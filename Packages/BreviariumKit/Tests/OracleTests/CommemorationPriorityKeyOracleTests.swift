import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `orationes.pl:585-594`'s "1960: at most one
// commemoration on a high-ranked day" rule picks the survivor via a real numeric
// priority key (`orationes.pl:551-561`), under which a Sunday-titled candidate always
// outranks a non-Sunday one regardless of rank. This project previously just kept the
// first candidate `Commemorations.resolve` returned (an approximation flagged in
// `HourAssembler`'s own doc comment), which on a day with two candidates picked whichever
// happened to come first in that array, not necessarily the real survivor.

@Test func sundayCommemorationOutranksSameDayTemporalRunnerUp() async throws {
    // 27 December 2025 (S. Ioannis Apostoli et Evangelistæ, II. classis, rank 5, winning
    // outright). The candidate pool has two entries: today's own runner-up
    // (`Tempora/Nat27`, "Dies III infra Octavam Nativitatis", rank 5) and the
    // tied-tomorrow Sunday ("Dominica Infra Octavam Nativitatis"). The real fixture
    // commemorates the Sunday, using its own "Dum médium siléntium..." antiphon and its
    // own collect ("Omnípotens sempitérne Deus, dírige actus nostros...").
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 27, month: 12, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 27, month: 12, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.contains { $0.contains("Dominica Infra Octavam Nativitatis") })
    #expect(!rubrics.contains { $0.contains("Diei III infra Octavam Nativitatis") || $0.contains("Dies III infra Octavam Nativitatis") })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Dum médium siléntium") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-12-27"))
    #expect(fixture.contains("Dominica Infra Octavam Nativitatis"))
    #expect(fixture.contains("Dum médium siléntium"))
}
