import Testing
@testable import BreviariumKit

private func vesperaContext(rubrica: String = "Rubrics 1960 - 1960") -> ConditionalContext {
    ConditionalContext(rubrica: rubrica, tempore: "Adventus", feria: 1, ad: "vesperas", mense: 12)
}

@Test func resolvesPlainUnconditionedSection() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Sancti/01-18r.txt", sections: [
            RawSection(name: "Oratio", condition: "", body: ["Da, quaesumus, omnipotens Deus."])
        ])
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/01-18r.txt", section: "Oratio") == "Da, quaesumus, omnipotens Deus.")
}

@Test func resolvesCrossFileInclusion() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Sancti/01-18r.txt", sections: [
            RawSection(name: "Hymnus Vespera", condition: "", body: ["@Sancti/02-22:Hymnus Vespera"])
        ]),
        RawOfficeFile(path: "Sancti/02-22.txt", sections: [
            RawSection(name: "Hymnus Vespera", condition: "", body: ["Iste confessor Domini sacratus."])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/01-18r.txt", section: "Hymnus Vespera") == "Iste confessor Domini sacratus.")
}

@Test func resolvesPrayerMacro() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Adv1-0.txt", sections: [
            RawSection(name: "Oratio", condition: "", body: ["Excita, quaesumus, Domine.", "$Per Dominum"])
        ]),
        RawOfficeFile(path: SectionResolver.prayersPath, sections: [
            RawSection(name: "Per Dominum", condition: "", body: [
                "r. Per Dominum nostrum Jesum Christum.", "R. Amen.",
            ])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    let result = resolver.resolve(path: "Tempora/Adv1-0.txt", section: "Oratio")
    #expect(result == "Excita, quaesumus, Domine.\nr. Per Dominum nostrum Jesum Christum.\nR. Amen.")
}

@Test func pickesLastTrueConditionedVariant() {
    // Mirrors setupstring_parse_file's hash-overwrite semantics: later matching
    // headers win over earlier ones, matching DO's own load-time behaviour.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Psalterium/Comment.txt", sections: [
            RawSection(name: "Festa", condition: "", body: ["Simplex"]),
            RawSection(name: "Festa", condition: "rubrica 196", body: ["IV. classis"]),
        ])
    ])
    let resolver1960 = SectionResolver(corpus: corpus, context: vesperaContext(rubrica: "Rubrics 1960 - 1960"))
    #expect(resolver1960.resolve(path: "Psalterium/Comment.txt", section: "Festa") == "IV. classis")

    let resolverTrident = SectionResolver(corpus: corpus, context: vesperaContext(rubrica: "Tridentine - 1570"))
    #expect(resolverTrident.resolve(path: "Psalterium/Comment.txt", section: "Festa") == "Simplex")
}

@Test func missingSectionReportsClearly() {
    let corpus = InMemoryOfficeCorpus(files: [])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/99-99.txt", section: "Oratio") == "Sancti/99-99.txt:Oratio is missing!")
}

@Test func lineRangeSubstitutionSelectsOnlyThoseLines() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Commune/C3.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["Line one.", "Line two.", "Line three.", "Line four."])
        ]),
        RawOfficeFile(path: "Sancti/06-29.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["@Commune/C3:Lectio1:2-3"])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/06-29.txt", section: "Lectio1") == "Line two.\nLine three.")
}

@Test func negatedLineSelectionExcludesThatRange() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Commune/C3.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["Line one.", "Line two.", "Line three."])
        ]),
        RawOfficeFile(path: "Sancti/06-29.txt", sections: [
            RawSection(name: "Lectio1", condition: "", body: ["@Commune/C3:Lectio1:!2"])
        ]),
    ])
    let resolver = SectionResolver(corpus: corpus, context: vesperaContext())
    #expect(resolver.resolve(path: "Sancti/06-29.txt", section: "Lectio1") == "Line one.\nLine three.")
}
