import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: on "Vespera de sequenti" (first Vespers of
// tomorrow's office wins, e.g. Saturday evening before a Sunday), DO's own whole
// rendering pass re-derives every date-dependent global from *tomorrow's* date, not the
// queried one -- `get_tempus_id()` (this project's `TemporalCycle.tempusID`, `tempore`'s
// own source) is one of them. `HourAssembler.assembleVespers` already made this swap for
// `weekName` (used by the Major Special season fallback), but not for `context.tempore`
// itself, which `ConditionalLineProcessor` uses to resolve inline `(sed tempore ...)`
// conditionals *inside* the winning office's own content. Confirmed real for 5 April
// 2025 (Saturday before Passion Sunday, "Dominica I Passionis ~ Vespera de sequenti"):
// the real fixture's Vexilla Regis hymn shows its Passiontide-specific final verse ("Hoc
// Passiónis témpore"), which requires `tempore == "Passionis"` (from 6 April, Passion
// Sunday) rather than `"Quadragesimæ"` (from 5 April, still the 4th week of Lent) to
// select via the hymn's own `(sed tempore Passionis)` conditional line.

@Test func firstVespersOfTomorrowUsesTomorrowsOwnSeasonForInlineConditionals() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 5, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 5, month: 4, year: 2025, priest: false))
    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })

    let text = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined(separator: " ")
    #expect(text.contains("Hoc Passiónis témpore"))
    #expect(!text.contains("In hac triúmphi glória"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-05"))
    #expect(fixture.contains("Hoc Passiónis témpore"))
}
