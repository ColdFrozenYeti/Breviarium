import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `oratioLocation` had no final fallback for
// an ordinary low-rank `Tempora/` feria whose own winning [Rank] variant carries no
// Commune reference at all and defines no [Oratio] of its own -- 24 real dates rendered
// with no Oratio section at all before this fix. `orationes.pl:115-120`'s own real
// final catch-all (distinct from -- and more general than -- the existing
// `oratioDominicaOffice`'s literal "Oratio Dominica" rule trigger) defaults any such
// Tempora-won day to that same week's own Sunday file's plain Oratio.

@Test func ordinaryFeriaWithNoOratioOfItsOwnFallsBackToItsOwnWeeksSunday() async throws {
    // 8 June 2026 (Monday, "Feria II infra Hebdomadam II post Octavam Pentecostes"):
    // Tempora/Pent02-1's own winning [Rank] variant under 1960 is plain ";;Feria;;1"
    // -- no Commune reference, no [Oratio] anywhere in the file. The real fixture's
    // own Oratio is Tempora/Pent02-0's own [Oratio] ("Sancti nóminis tui, Dómine...").
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 8, month: 6, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 8, month: 6, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    #expect(!oratio.units.isEmpty)
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Sancti nóminis tui") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-06-08"))
    #expect(fixture.contains("Sancti nóminis tui"))
}
