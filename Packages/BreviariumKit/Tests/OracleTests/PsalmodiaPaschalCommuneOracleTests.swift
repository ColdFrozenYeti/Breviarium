import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Psalmodia category pass): the Psalmodia
// antiphon lookup used the plain `communeFallbackPath` instead of the Paschal-aware
// `paschalCommuneFallbackPath` every sibling lookup in this file (Capitulum/Hymnus/
// Versus/Oratio/Magnificat-antiphon) already uses. `extract_common()`'s own Paschaltide
// branch (`horascommon.pl:1501-1509`) swaps in a Commune's own "p"-suffixed variant
// during Paschaltide -- this one lookup never made that swap, reaching the ordinary
// (non-Paschal) Commune file's own content instead, which for many Communes has no
// `[Ant Vespera]` of its own at all, only its Paschal variant's own base chain does.

@Test func paschaltideEvangelistUsesTheCommunesOwnPaschalAntiphons() async throws {
    // 25 April 2026 (S. Marci Evangelistæ, II. classis, "ex C1a", within Paschaltide).
    // Commune/C1a.txt has no [Ant Vespera] of its own; the real antiphons come from
    // Commune/C1p.txt (reached only via the Paschal variant Commune/C1ap.txt's own
    // "@Commune/C1p" base inclusion) -- "Sancti tui, Domine, florebunt sicut lilium,
    // allelúia...". This project's engine previously reached plain Commune/C1a
    // directly, found nothing, and fell through to a wrong default.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 25, month: 4, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 25, month: 4, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    let antiphons = psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Sancti tui") && $0.contains("florébunt sicut lílium") })

    let verses = psalmodia.units.compactMap { unit -> (String, String)? in
        if case .verse(_, let first, let second, _, _) = unit { return (first, second) } else { return nil }
    }
    #expect(!verses.contains { $0.0.contains("pœnitébit") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-04-25"))
    #expect(fixture.contains("Sancti tui"))
    #expect(fixture.contains("florébunt sicut lílium"))
}
