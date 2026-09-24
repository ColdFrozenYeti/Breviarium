import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `commemorationUnits` looked up a
// commemorated office's `Ant`/`Versum`/`Oratio N` fields using the *winning* office's
// own Vespers index (`MacroContext.isFirstVespers`), but a cross-day commemoration
// (today's own winner commemorating tomorrow, or vice versa) needs the *commemorated*
// office's own natural index instead -- the real Perl's `$cvespera`, always the
// opposite of whichever index the actually-prayed office took (`$vespera`), not a copy
// of it. `Commemoration.ind` now carries this per-candidate, set once in
// `Commemorations.swift` rather than threaded in from `MacroContext` at render time.

@Test func crossDayCommemorationUsesItsOwnNaturalVespersIndexNotTheWinnersOwn() async throws {
    // 31 May 2025 (Beatæ Mariæ Virginis Reginæ, II. classis): wins its own Vespers
    // outright under the 1960 "equal rank, the preceding takes precedence" tie-break
    // (`ind == 3` for the winning office itself), commemorating tomorrow's "Dominica
    // post Ascensionem". `Tempora/Pasc6-0.txt`'s own `[Ant 1]` ("Cum vénerit
    // Paráclitus...") is the real antiphon; `[Ant 3]` ("Hæc locútus sum vobis...") is a
    // different Gospel verse this project's engine wrongly rendered before this fix,
    // reusing the winning office's own `ind == 3` for the commemoration too.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 31, month: 5, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 31, month: 5, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Cum vénerit Paráclitus") })
    #expect(!antiphons.contains { $0.contains("Hæc locútus sum") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-05-31"))
    #expect(fixture.contains("Cum vénerit Paráclitus"))
    #expect(!fixture.contains("Hæc locútus sum"))
}
