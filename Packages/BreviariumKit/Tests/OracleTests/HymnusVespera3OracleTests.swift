import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `hymnusmajor` (`specials/hymni.pl:69-99`)
// tries a `" 3"`-suffixed section (office's own file, then Commune -- exactly like the
// plain key's fallback chain) *before* falling to the plain `"Hymnus Vespera"` key, but
// only at second Vespers (`$vespera == 3`); first Vespers never gets an indexed attempt.
// This engine's own `assembleCapitulumHymnusVersus` only ever tried the plain key,
// skipping straight to the Commune's generic hymn whenever the office defined only the
// indexed one. Real example: 30 January 2025, S. Martina (Virgin and Martyr, "vide C6"),
// whose own `Sancti/01-30.txt` defines `[Hymnus Vespera 3]` (a same-file
// cross-reference to `[Hymnus Laudes]`, "Tu natale solum protege...") but no plain
// `[Hymnus Vespera]` -- the real page shows her own proper hymn, not the Commune of
// Virgins' "Iesu, corona Virginum".

@Test func hymnusTriesTheIndexedSecondVespersSectionBeforeFallingToCommune() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 30, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 30, month: 1, year: 2025, priest: false))
    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })

    let text = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined(separator: " ")
    #expect(text.contains("Tu natále solum prótege"))
    #expect(!text.contains("Iesu, coróna Vírginum"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-30"))
    #expect(fixture.contains("Tu natále solum prótege"))
}
