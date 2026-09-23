import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `&Dominus_vobiscum2` (`horasscripts.pl:
// 136-140`, the Office-of-the-Dead-specific wrapper around `&Dominus_vobiscum`) was
// never implemented, so `Prayers.txt`'s own `[A porta inferi]` section -- part of All
// Souls' own Oratio chain (`Sancti/11-02`'s `[Oratio mortuorum2]` -> `Commune/C9`'s
// `[Oratio_a_porta]` -> `$A porta inferi` -> `[A porta inferi]`) -- rendered the
// literal, unresolved macro name as text.

@Test func dominusVobiscum2ResolvesInsteadOfLeakingTheLiteralMacroName() async throws {
    // 3 November 2025 (All Souls' Day proper, transferred here because 2 November is
    // a Sunday that year). Non-priest: `&Dominus_vobiscum2` forces $precesferiales,
    // selecting `[Dominus]`'s own 5th line -- a small-font `/:...:/ ` annotation
    // ("secunda «Domine, exaudi» omittitur") the real fixture *does* show, but which
    // this project deliberately omits entirely (`CLAUDE.md`'s "no explanatory text in
    // the office" rule, the same precedent `majorSpecialAntLocation`'s own
    // `/:ut in Proprio de Tempore:/` placeholder already follows) rather than
    // reproduce DO's own literal small-font UI element.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 3, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 3, month: 11, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(!prose.contains { $0.contains("Dominus_vobiscum2") })
    #expect(!prose.contains { $0.contains("secunda") })
    #expect(prose.contains { $0.contains("A porta ínferi") })
    #expect(prose.contains { $0.contains("Fidélium, Deus, ómnium Cónditor et Redémptor") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-03"))
    #expect(!fixture.contains("Dominus_vobiscum2"))
    #expect(fixture.contains("Fidélium, Deus, ómnium Cónditor et Redémptor"))
}
