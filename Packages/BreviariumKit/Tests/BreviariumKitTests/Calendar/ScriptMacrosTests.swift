import Testing
@testable import BreviariumKit

private let vesperaContext = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "post Epiphaniam", feria: 1, ad: "vesperas", mense: 1
)

private let prayersFile = RawOfficeFile(path: "Psalterium/Common/Prayers.txt", sections: [
    RawSection(name: "Deus in adiutorium", condition: "", body: [
        "V. Deus in adiutorium meum intende.", "R. Domine, ad adiuvandum me festina.",
    ]),
    RawSection(name: "Alleluia", condition: "", body: [
        "v. Alleluia.", "v. Laus tibi, Domine, Rex aeternae gloriae.",
    ]),
    RawSection(name: "Gloria", condition: "", body: ["Gloria Patri, et Filio, * et Spiritui Sancto."]),
    RawSection(name: "Requiem", condition: "", body: ["Requiem aeternam dona ei, Domine."]),
    RawSection(name: "Dominus", condition: "", body: [
        "V. Dominus vobiscum.", "R. Et cum spiritu tuo.",
        "V. Domine, exaudi orationem meam.", "R. Et clamor meus ad te veniat.",
    ]),
    RawSection(name: "Benedicamus Domino", condition: "", body: [
        "V. Benedicamus Domino.", "R. Deo gratias.",
    ]),
    RawSection(name: "Alleluia Duplex", condition: "", body: ["Alleluia, alleluia."]),
])

private func resolver(withMacroContext macroContext: MacroContext) -> SectionResolver {
    SectionResolver(
        corpus: InMemoryOfficeCorpus(files: [prayersFile]), context: vesperaContext, macroContext: macroContext
    )
}

private func makeMacroContext(
    weekName: String = "Epi2", dayOfWeek: Int = 3, priest: Bool = false, isFirstVespers: Bool = false,
    rank: Double = 2.0, rule: String = ""
) -> MacroContext {
    MacroContext(
        weekName: weekName, dayOfWeek: dayOfWeek, priest: priest,
        winningRank: OfficeRank(title: "", degreeLabel: "Feria", numericPrecedence: rank, communeReference: ""),
        winningRule: rule, isFirstVespers: isFirstVespers
    )
}

@Test func deusInAdjutoriumAlwaysResolvesToThePlainText() {
    let r = resolver(withMacroContext: makeMacroContext())
    #expect(
        ScriptMacros.resolve("Deus_in_adjutorium", context: makeMacroContext(), resolver: r)
            == "V. Deus in adiutorium meum intende.\nR. Domine, ad adiuvandum me festina."
    )
}

@Test func alleluiaIsUsedOutsideLent() {
    let r = resolver(withMacroContext: makeMacroContext())
    #expect(ScriptMacros.resolve("Alleluia", context: makeMacroContext(weekName: "Epi2"), resolver: r) == "v. Alleluia.")
}

@Test func lausTibiIsUsedDuringSeptuagesimaAndLent() {
    let r = resolver(withMacroContext: makeMacroContext())
    #expect(
        ScriptMacros.resolve("Alleluia", context: makeMacroContext(weekName: "Quad3"), resolver: r)
            == "v. Laus tibi, Domine, Rex aeternae gloriae."
    )
    #expect(
        ScriptMacros.resolve("Alleluia", context: makeMacroContext(weekName: "Quadp2"), resolver: r)
            == "v. Laus tibi, Domine, Rex aeternae gloriae."
    )
}

@Test func alleluiaIsKeptAtFirstVespersOfSeptuagesimaItself() {
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(weekName: "Quadp1", dayOfWeek: 6, isFirstVespers: true)
    #expect(ScriptMacros.resolve("Alleluia", context: context, resolver: r) == "v. Alleluia.")
}

@Test func gloriaIsOmittedDuringTheTriduumsOwnVespers() {
    let r = resolver(withMacroContext: makeMacroContext())
    let holyFriday = makeMacroContext(weekName: "Quad6", dayOfWeek: 5, isFirstVespers: false)
    #expect(ScriptMacros.resolve("Gloria", context: holyFriday, resolver: r) == "")
}

@Test func gloriaIsSaidOnHolyThursdaysOwnFirstVespersOfTheTriduumItself() {
    // dayOfWeek 4 (Thursday) with isFirstVespers true means this is Wednesday evening's
    // first Vespers of Holy Thursday, before the Triduum's own Vespers silence begins.
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(weekName: "Quad6", dayOfWeek: 4, isFirstVespers: true)
    #expect(ScriptMacros.resolve("Gloria", context: context, resolver: r) == "Gloria Patri, et Filio, * et Spiritui Sancto.")
}

@Test func gloriaUsesRequiemFormWhenRuleFlagIsSet() {
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(rule: "Requiem gloria")
    #expect(ScriptMacros.resolve("Gloria", context: context, resolver: r) == "Requiem aeternam dona ei, Domine.")
}

@Test func dominusVobiscumUsesThePriestFormWhenPriestIsPresent() {
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(priest: true)
    #expect(ScriptMacros.resolve("Dominus_vobiscum", context: context, resolver: r) == "V. Dominus vobiscum.\nR. Et cum spiritu tuo.")
}

@Test func dominusVobiscumUsesTheDomineExaudiFormWithoutAPriest() {
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(priest: false)
    #expect(
        ScriptMacros.resolve("Dominus_vobiscum", context: context, resolver: r)
            == "V. Domine, exaudi orationem meam.\nR. Et clamor meus ad te veniat."
    )
}

@Test func benedicamusDominoIsPlainOutsidePaschaltide() {
    let r = resolver(withMacroContext: makeMacroContext())
    #expect(ScriptMacros.resolve("Benedicamus_Domino", context: makeMacroContext(), resolver: r) == "V. Benedicamus Domino.\nR. Deo gratias.")
}

@Test func benedicamusDominoAddsTheFarewellAlleluiaThroughoutThePaschalOctave() {
    let r = resolver(withMacroContext: makeMacroContext())
    let context = makeMacroContext(weekName: "Pasc0", dayOfWeek: 3)
    #expect(
        ScriptMacros.resolve("Benedicamus_Domino", context: context, resolver: r)
            == "V. Benedicamus Domino, alleluia, alleluia.\nR. Deo gratias, alleluia, alleluia."
    )
}

@Test func sectionResolverLeavesUnknownMacrosUntouchedWithoutAMacroContext() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Epi2-1", sections: [
            RawSection(name: "Conclusio", condition: "", body: ["&Dominus_vobiscum"])
        ])
    ])
    let r = SectionResolver(corpus: corpus, context: vesperaContext)
    #expect(r.resolve(path: "Tempora/Epi2-1", section: "Conclusio") == "&Dominus_vobiscum")
}

@Test func sectionResolverExpandsAKnownMacroWhenGivenAMacroContext() {
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Epi2-1", sections: [
            RawSection(name: "Conclusio", condition: "", body: ["&Dominus_vobiscum"])
        ]),
        prayersFile,
    ])
    let r = SectionResolver(corpus: corpus, context: vesperaContext, macroContext: makeMacroContext(priest: true))
    #expect(r.resolve(path: "Tempora/Epi2-1", section: "Conclusio") == "V. Dominus vobiscum.\nR. Et cum spiritu tuo.")
}
