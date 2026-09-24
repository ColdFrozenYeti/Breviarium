import Testing
@testable import BreviariumKit

@Test func layeredCorpusPrefersEarlierLayer() {
    let bea = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Psalterium/Dom1/Matutinum.txt", sections: [
            RawSection(name: "Ps 1", condition: "", body: ["Beatus vir (Bea)."])
        ])
    ])
    let latin = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Psalterium/Dom1/Matutinum.txt", sections: [
            RawSection(name: "Ps 1", condition: "", body: ["Beatus vir (Vulgate)."]),
            RawSection(name: "Oratio", condition: "", body: ["Only in plain Latin."]),
        ])
    ])
    let layered = LayeredOfficeCorpus(layers: [bea, latin])

    #expect(layered.rawSections(path: "Psalterium/Dom1/Matutinum", name: "Ps 1").first?.body == ["Beatus vir (Bea)."])
    // Falls through to the next layer when the first doesn't have this file at all.
    #expect(layered.rawSections(path: "Psalterium/Dom1/Matutinum", name: "Oratio").first?.body == ["Only in plain Latin."])
}

@Test func dataBundleMakeLatinCorpusLayersBeaOverLatin() {
    let bundle = DataBundle(
        latin: [RawOfficeFile(path: "Psalterium/Dom1/Matutinum.txt", sections: [
            RawSection(name: "Ps 1", condition: "", body: ["Vulgate text."])
        ])],
        latinBea: [RawOfficeFile(path: "Psalterium/Dom1/Matutinum.txt", sections: [
            RawSection(name: "Ps 1", condition: "", body: ["Bea text."])
        ])],
        english: [],
        calendar: [:]
    )
    let resolver = SectionResolver(
        corpus: bundle.makeLatinCorpus(psalter: .pius12),
        context: ConditionalContext(rubrica: "Rubrics 1960 - 1960", tempore: "post Pentecosten", feria: 1, ad: "vesperas", mense: 9)
    )
    #expect(resolver.resolve(path: "Psalterium/Dom1/Matutinum", section: "Ps 1") == "Bea text.")
}

@Test func dataBundleMakeEnglishCorpusHasNoBeaLayer() {
    // Confirmed against the real checkout: no `English-Bea` sibling directory exists,
    // so (unlike makeLatinCorpus) this is just the one plain tree.
    let bundle = DataBundle(
        latin: [], latinBea: [],
        english: [RawOfficeFile(path: "Psalterium/Dom1/Matutinum.txt", sections: [
            RawSection(name: "Ps 1", condition: "", body: ["Blessed is the man."])
        ])],
        calendar: [:]
    )
    let resolver = SectionResolver(
        corpus: bundle.makeEnglishCorpus(),
        context: ConditionalContext(rubrica: "Rubrics 1960 - 1960", tempore: "post Pentecosten", feria: 1, ad: "vesperas", mense: 9)
    )
    #expect(resolver.resolve(path: "Psalterium/Dom1/Matutinum", section: "Ps 1") == "Blessed is the man.")
}
