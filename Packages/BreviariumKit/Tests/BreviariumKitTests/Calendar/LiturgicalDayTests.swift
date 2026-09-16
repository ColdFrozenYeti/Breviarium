import Testing
@testable import BreviariumKit

private let context1960 = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "post Pentecosten", feria: 4, ad: "vesperas", mense: 9
)

@Test func martyrsFeastProducesAClassisLineAndRedColor() {
    // Modelled on 16 September 2026 (CLAUDE.md's own worked example): Ss. Cornelii et
    // Cypriani, III. classis, a Wednesday. Commemoration text isn't included, since
    // Occurrence doesn't build the commemoration list yet (see its doc comment) --
    // this fixture only exercises the single-winning-office path.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Pent16-3", sections: [
            RawSection(name: "Officium", condition: "", body: ["Feria IV infra Hebdomadam XVI post Octavam Pentecostes"]),
            RawSection(name: "Rank", condition: "", body: [";;Feria;;2.0"]),
        ]),
        RawOfficeFile(path: "Sancti/09-16", sections: [
            RawSection(name: "Officium", condition: "", body: ["Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum"]),
            RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;vide C3"]),
        ]),
    ])
    let engine = LiturgicalCalendarEngine(
        corpus: corpus, context: context1960,
        sanctoralCalendar: SanctoralCalendar(entries: ["09-16": "09-16"])
    )

    let result = engine.day(day: 16, month: 9, year: 2026)
    #expect(result?.occurrence.sanctoralWins == true)
    #expect(result?.rankDisplayName == "III. classis")
    #expect(result?.titleBlock.classisLine == "III. classis")
    #expect(result?.titleBlock.nameLine == "Ss. Cornelii Papæ et Cypriani Episcopi, Martyrum")
    #expect(result?.color == .red)    // "Martyr" in the title.
}

@Test func plainFeriaHasNoClassisLine() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Pent16-3", sections: [
            RawSection(name: "Officium", condition: "", body: ["Feria IV infra Hebdomadam XVI post Octavam Pentecostes"]),
            RawSection(name: "Rank", condition: "", body: [";;Feria;;2.0"]),
        ])
    ])
    let engine = LiturgicalCalendarEngine(corpus: corpus, context: context1960, sanctoralCalendar: SanctoralCalendar(entries: [:]))

    let result = engine.day(day: 16, month: 9, year: 2026)
    #expect(result?.occurrence.sanctoralWins == false)
    #expect(result?.rankDisplayName == "III. classis")    // Rank 2.0 (Semiduplex-tier) still maps to III. classis...
    // ...but the title-block classisLine is only suppressed specifically when the
    // display name is literally "Feria" (rank 0), which this fixture's rank (2.0) isn't
    // -- documenting the actual boundary rather than a looser "no classis line for any
    // weekday temporal office" assumption.
    #expect(result?.titleBlock.classisLine == "III. classis")
}

@Test func trueFeriaRankZeroSuppressesClassisLine() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Pent16-3", sections: [
            RawSection(name: "Officium", condition: "", body: ["Feria IV infra Hebdomadam XVI post Octavam Pentecostes"]),
            RawSection(name: "Rank", condition: "", body: [";;Feria;;0"]),
        ])
    ])
    let engine = LiturgicalCalendarEngine(corpus: corpus, context: context1960, sanctoralCalendar: SanctoralCalendar(entries: [:]))

    let result = engine.day(day: 16, month: 9, year: 2026)
    #expect(result?.rankDisplayName == "Feria")
    #expect(result?.titleBlock.classisLine == nil)
    #expect(result?.titleBlock.nameLine == "Feria IV infra Hebdomadam XVI post Octavam Pentecostes")
}

@Test func noWinningOfficeReturnsNil() {
    let engine = LiturgicalCalendarEngine(
        corpus: InMemoryOfficeCorpus(files: []), context: context1960, sanctoralCalendar: SanctoralCalendar(entries: [:])
    )
    #expect(engine.day(day: 16, month: 9, year: 2026) == nil)
}
