import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `orationes.pl:44-53`'s own "Special
// handling for days during the suppressed octave of the Epiphany" synthesizes an
// "Oratio Dominica" rule flag on the fly (`$rule .= "Oratio Dominica\n"`) for any
// office within week "Epi1" whose own [Rule] carries "Infra octavam Epiphaniae Domini"
// -- even though the office's own literal [Rule] text never says "Oratio Dominica"
// itself. This project's `oratioDominicaOffice` only checked for the literal text.

@Test func epiphanyOctaveDayAfterTheOctaveSundayUsesTheOldSundayCollect() async throws {
    // 12 January 2026 (Sancti/01-12, a Monday -- the day after that year's Sunday
    // within the octave, 11 January, so week "Epi1" has already begun). Its own [Rule]
    // has "Infra octavam Epiphaniae Domini" but no literal "Oratio Dominica". The real
    // fixture's own collect is Tempora/Epi1-0a's "Vota, quaesumus, Domine..." -- not
    // Sancti/01-06's own "Deus, qui hodierna die..." reached via the office's ordinary
    // "vide Sancti/01-06" Commune-chain fallback (confirmed real for 7 January 2026,
    // still within week "Nat1" before that year's Sunday, which does use Epiphany's own
    // collect -- the gate is genuinely week-name-scoped, not the whole octave).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 12, month: 1, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 12, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Vota, qu") && $0.contains("supplic") })
    #expect(!prose.contains { $0.contains("hodi") && $0.contains("Unig") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-01-12"))
    #expect(fixture.contains("Vota, qu"))
    #expect(fixture.contains("supplicántis pópuli"))
}
