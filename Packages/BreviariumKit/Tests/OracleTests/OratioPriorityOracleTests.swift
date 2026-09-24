import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `orationes.pl:63-82`'s own real priority
// for the main Oratio checks the *office's own* file completely -- plain `[Oratio]`,
// then the office's own indexed `[Oratio N]` overriding it if present -- before ever
// consulting the Commune at all. The previous version of this code instead checked
// indexed-then-plain *across both* office and Commune together, which let a Commune's
// own generic indexed Oratio win over the office's own perfectly good plain one.

@Test func officesOwnPlainOratioWinsOverTheCommunesOwnIndexedOne() async throws {
    // 20 January 2025 (Ss. Fabian and Sebastian, Martyrs): `Sancti/01-20`'s own plain
    // `[Oratio]` is `@Commune/C2::s/beáti N\. Mártyris tui atque Pontíficis/beatórum
    // Mártyrum tuórum Fabiáni et Sebastiáni/` -- a same-file-resolvable, name-
    // substituted collect. Its own `[Rank]` names `"vide C3"`, and `Commune/C3` has its
    // own generic `[Oratio 3]` ("Da, quǽsumus... N. et N. ...", no name substituted) --
    // the previous priority order found that one first.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 20, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 20, month: 1, year: 2025, priest: false))

    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    let proseTexts = oratio.units.compactMap { unit -> String? in
        if case .prose(let text, _) = unit { return text } else { return nil }
    }
    #expect(proseTexts.contains {
        $0.contains("beatórum Mártyrum tuórum Fabiáni et Sebastiáni intercéssio gloriósa nos prótegat")
    })
    #expect(!proseTexts.contains { $0.contains("N. et N.") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-20"))
    #expect(fixture.contains("beatórum Mártyrum tuórum Fabiáni et Sebastiáni intercéssio gloriósa nos prótegat"))
}
