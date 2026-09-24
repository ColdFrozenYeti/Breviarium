import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `extract_common()`'s own Paschaltide branch
// (`horascommon.pl:1501-1509`), never previously ported: for a genuine Commune-code
// reference, during Paschaltide, if a `"p"`-suffixed variant of that Commune file
// actually exists, it's used instead, unconditionally, for every section looked up
// against that Commune -- a real DO limitation this project's engine had no equivalent
// for, always following the ordinary (non-"p") chain regardless of season. Confirmed
// real for 29 April 2025 (S. Petri Martyris, `"vide C2a-1"`, in the weeks following the
// Easter Octave): the real fixture's own Magnificat antiphon, "Sancti et iusti * in
// Dómino gaudéte, allelúia...", comes from `Commune/C2a-1p.txt`'s own chain (→ `C2ap` →
// `C2p` → `C1p`), not the ordinary `C2a-1` chain this project's engine used to follow
// instead (landing on a Common-of-a-Martyr antiphon proper to the *ordinary*, non-
// Paschal season, "Qui vult veníre post me...").

@Test func sPetriMartyrisUsesThePaschaltideCommuneVariantForItsAntiphon() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 29, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 29, month: 4, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Sancti et iusti") && $0.contains("in Dómino gaudéte") })
    #expect(!antiphons.contains { $0.contains("Qui vult veníre post me") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-29"))
    #expect(fixture.contains("Sancti et iusti"))
}
