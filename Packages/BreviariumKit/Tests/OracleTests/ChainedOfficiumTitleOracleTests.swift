import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `SectionResolver.resolveRank`'s own
// Officium-title-fallback (`SetupString.pl`'s `if (exists($sections{'Officium'}))`
// safeguard, which reads an already-chain-resolved section hash) used a *literal*,
// non-chain-aware existence check (`corpus.rawSections(path:name:).isEmpty`) instead of
// `sectionExists`, this project's own chain-aware equivalent used everywhere else. A
// pure `@`-inclusion redirect file (real example: `Tempora/Quad6-4r.txt`, Holy
// Thursday's own redirect target, whose entire content is the single line
// `@Tempora/Quad6-4`) has no `[Officium]` section *directly at that path*, so the guard
// failed and `OfficeRank.title` came back empty for it -- even though the same file's
// `[Rank]` field's own numeric/degree parts resolved correctly via that same chain.
// That empty title then slipped past every title-based exclusion check downstream
// (`Concurrence`'s and `Commemorations`' own `isExcludedByTitle`, both matching against
// `.title`), wrongly commemorating Holy Thursday's own Institution of the Eucharist
// antiphon at Holy Wednesday's Vespers (confirmed real for 16 April 2025: the real
// fixture is a plain collect with no commemoration at all).

@Test func resolveRankFillsTheTitleThroughAPureInclusionRedirectFile() throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let resolver = SectionResolver(corpus: corpus, context: ConditionalContext(rubrica: "Rubrics 1960 - 1960", tempore: "Passionis", feria: 4, ad: "vesperas", mense: 4))
    let rank = try #require(OfficeRank(rankFieldValue: resolver.resolveRank(path: "Tempora/Quad6-4r")))
    #expect(rank.title == "Feria Quinta in Cena Domini")
}

@Test func holyWednesdayDoesNotWronglyCommemorateHolyThursday() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 16, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 16, month: 4, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(!antiphons.contains { $0.contains("Cenántibus autem illis") })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Réspice, quǽsumus, Dómine") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-16"))
    #expect(!fixture.contains("Cenántibus autem illis"))
}
