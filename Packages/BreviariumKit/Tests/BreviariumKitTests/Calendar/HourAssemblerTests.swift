import Foundation
import Testing
@testable import BreviariumKit

private let vesperaContext = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "post Epiphaniam", feria: 1, ad: "vesperas", mense: 1
)

private let skeleton = RawOfficeFile(path: "Ordinarium/Vespera", sections: [
    RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: [
        "#Incipit", "&Deus_in_adjutorium", "&Alleluia", "",
        "#Psalmi", "",
        "#Canticum: Magnificat", "",
        "#Preces Feriales", "",
        "#Oratio", "",
        "#Conclusio", "&Dominus_vobiscum", "&Benedicamus_Domino", "$Fidelium animae",
    ])
])

private let majorSpecialFile = RawOfficeFile(path: "Psalterium/Special/Major Special.txt", sections: [
    RawSection(name: "Preces feriales Vespera", condition: "", body: [
        "$Kyrie", "$Pater noster Et", "$Preces feriales Vespera", "$Domine exaudi",
    ])
])

private let precesTextFile = RawOfficeFile(path: "Psalterium/Special/Preces.txt", sections: [
    RawSection(name: "Preces feriales Vespera", condition: "", body: [
        "V. Ego dixi: Domine, miserere mei.", "R. Sana animam meam quia peccavi tibi.",
        "/:Nota bene: haec est adnotatio.:/ ",
        // Confirmed real (Preces.txt:198-200): a line ending "~" merges into the next
        // with a single space, and the lowercase "r." line it merges with is DO's own
        // drop-cap marker for the fragment's first letter, not a real response.
        "V. Oremus pro beatissimo Papa nostro~", "r. N.", "R. Dominus conservet eum.",
    ])
])

private let prayersFile = RawOfficeFile(path: "Psalterium/Common/Prayers.txt", sections: [
    RawSection(name: "Deus in adiutorium", condition: "", body: [
        "V. Deus in adiutorium meum intende.", "R. Domine, ad adiuvandum me festina.",
        "v. Gloria Patri, et Filio, * et Spiritui Sancto.",
        "Sicut erat in principio, * et nunc et semper. Amen.",
    ]),
    RawSection(name: "Alleluia", condition: "", body: ["v. Alleluia.", "v. Laus tibi, Domine."]),
    RawSection(name: "Gloria", condition: "", body: [
        "Gloria Patri, et Filio, * et Spiritui Sancto.", "Sicut erat in principio, * et nunc et semper. Amen.",
    ]),
    RawSection(name: "Dominus", condition: "", body: [
        "V. Dominus vobiscum.", "R. Et cum spiritu tuo.",
        "V. Domine, exaudi orationem meam.", "R. Et clamor meus ad te veniat.",
    ]),
    RawSection(name: "Benedicamus Domino", condition: "", body: ["V. Benedicamus Domino.", "R. Deo gratias."]),
    RawSection(name: "Fidelium animae", condition: "", body: ["V. Fidelium animae per misericordiam Dei requiescant in pace.", "R. Amen."]),
])

private let psalm114 = RawOfficeFile(path: "Psalterium/Psalmorum/Psalm114", sections: [
    RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: [
        "114:1 Dilexi, quoniam exaudiet Dominus * vocem orationis meae.",
        "114:2 Quia inclinavit aurem suam mihi: * et in diebus meis invocabo.",
    ])
])

private let psalm232 = RawOfficeFile(path: "Psalterium/Psalmorum/Psalm232", sections: [
    RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: [
        "1:46 Magnificat * anima mea Dominum.", "1:47 Et exsultavit spiritus meus * in Deo salutari meo.",
    ])
])

private let weekdaySchedule = RawOfficeFile(path: "Psalterium/Psalmi/Psalmi major", sections: [
    RawSection(name: "Day1 Vespera", condition: "", body: ["Antiphona feriae * de psalmo.;;114"]),
    // The festal "Psalmi Dominica" number source (`assemblePsalmodia`'s own
    // `candidatePairs` doc comment): only the numbers matter here, zipped positionally
    // against a *different* office's own unnumbered antiphons, so the placeholder
    // antiphon text on each line is never actually used.
    RawSection(name: "Day0 Vespera", condition: "", body: [
        "placeholder;;109", "placeholder;;110", "placeholder;;111", "placeholder;;112", "placeholder;;113",
    ]),
])

/// The fixed Sunday/festal Vespers psalm set (109-112) `assemblePsalmodia` hardcodes for
/// the "unnumbered antiphon but a Psalm5 rule exists" case -- one trivial verse each,
/// just enough to prove the right numbers were picked.
private let festalPsalms109to112 = (109...112).map { number in
    RawOfficeFile(path: "Psalterium/Psalmorum/Psalm\(number)", sections: [
        RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: ["\(number):1 Psalmus * numero \(number)."])
    ])
}

private let festalFifthPsalm = RawOfficeFile(path: "Psalterium/Psalmorum/Psalm200", sections: [
    RawSection(name: RawSectionParser.wholeFileSectionName, condition: "", body: ["200:1 Psalmus quintus * proprius."])
])

/// A plain Monday feria (19 Jan 2026, real-date-verified elsewhere in this test suite),
/// low-ranked enough that a Sancti candidate the same day always wins occurrence.
private let feriaTemporal = RawOfficeFile(path: "Tempora/Epi2-1", sections: [
    RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
    RawSection(name: "Rank", condition: "", body: [";;Feria;;1.0"]),
])

@Test func assemblesAFerialVespersFromTheWeekdaySchedulesOwnAntiphons() throws {
    // Confirmed against the real oracle fixture for 16 September 2026: the weekday
    // schedule (Psalterium/Psalmi/Psalmi major.txt) carries real antiphon text
    // alongside each psalm number, not a bare cue placeholder.
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))

    let introductio = try #require(hour.sections.first { $0.kind == .introductio })
    #expect(introductio.units.contains(.versicleResponse(versicle: "Deus in adiutorium meum intende.", response: "Domine, ad adiuvandum me festina.")))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    #expect(psalmodia.units.first == .antiphon("Antiphona feriae * de psalmo."))
    #expect(psalmodia.units.contains(.verse(reference: "114:1", firstHalf: "Dilexi, quoniam exaudiet Dominus*", secondHalf: "vocem orationis meae.")))
    #expect(psalmodia.units.last == .antiphon("Antiphona feriae de psalmo."))    // repeated without its asterisk (psalmi.pl:688)

    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })
    #expect(conclusio.units.contains(.versicleResponse(versicle: "Domine, exaudi orationem meam.", response: "Et clamor meus ad te veniat.")))
}

@Test func fallsBackToTheWeekdayScheduleWhenAntVesperaHasNoPsalmNumbers() throws {
    // Confirmed against the real oracle fixture for 16 September 2026: Commune/C3.txt
    // (Common of Several Martyrs) has its own [Ant Vespera], but with no ";;number" on
    // any line -- meaning "alternate antiphons for the ferial psalms," not "these come
    // with their own proper psalms." A section that exists but parses to zero
    // (antiphon, psalmNumber) pairs must fall through to the weekday schedule exactly
    // like no section at all, not silently produce empty psalmody.
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;vide C99"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona alternativa sine numero psalmi."])
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona feriae * de psalmo."))
    #expect(psalmodia.units.contains(.verse(reference: "114:1", firstHalf: "Dilexi, quoniam exaudiet Dominus*", secondHalf: "vocem orationis meae.")))
}

@Test func assemblesPsalmodiaFromAProperAntiphonWhenTheOfficeDefinesOne() throws {
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;vide C99"]),
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona propria;;114"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona propria"))
    #expect(psalmodia.units.last == .antiphon("Antiphona propria"))
}

// MARK: - English pairing

private let englishPrayersFile = RawOfficeFile(path: "Psalterium/Common/Prayers.txt", sections: [
    RawSection(name: "Deus in adjutorium", condition: "", body: [
        "V. O God, come to my assistance.", "R. O Lord, make haste to help me.",
        "v. Glory be to the Father, and to the Son, * and to the Holy Ghost.",
        "As it was in the beginning, is now, * and ever shall be. Amen.",
    ]),
    RawSection(name: "Dominus", condition: "", body: [
        "V. The Lord be with you.", "R. And with thy spirit.",
        "V. O Lord, hear my prayer.", "R. And let my cry come unto thee.",
    ]),
    RawSection(name: "Benedicamus Domino", condition: "", body: ["V. Let us bless the Lord.", "R. Thanks be to God."]),
    RawSection(name: "Fidelium animae", condition: "", body: ["V. May the souls of the faithful departed rest in peace.", "R. Amen."]),
])

@Test func pairsIntroductioAndConclusioWithTheirEnglishCounterpartsWhenAnEnglishCorpusIsSupplied() throws {
    let latinCorpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal])
    let englishCorpus = InMemoryOfficeCorpus(files: [skeleton, englishPrayersFile])
    let assembler = HourAssembler(corpus: latinCorpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]), englishCorpus: englishCorpus)

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))

    let introductio = try #require(hour.sections.first { $0.kind == .introductio })
    #expect(introductio.units.contains(.versicleResponse(
        versicle: "Deus in adiutorium meum intende.", response: "Domine, ad adiuvandum me festina.",
        versicleEnglish: "O God, come to my assistance.", responseEnglish: "O Lord, make haste to help me."
    )))

    let conclusio = try #require(hour.sections.first { $0.kind == .conclusio })
    #expect(conclusio.units.contains(.versicleResponse(
        versicle: "Domine, exaudi orationem meam.", response: "Et clamor meus ad te veniat.",
        versicleEnglish: "O Lord, hear my prayer.", responseEnglish: "And let my cry come unto thee."
    )))
}

@Test func leavesEnglishNilWhenTheWinningLatinSectionHasNoExactEnglishCounterpart() throws {
    // Confirmed against the real bilingual fixture for 16 September 2026: Commune/
    // C3.txt's English tree has no [Oratio 3] at all, only the plain [Oratio] -- and
    // DO's own real behaviour is to leave that piece in Latin, not substitute the
    // (different, wrong) plain English collect. A synthetic case of the same shape:
    // Latin's Commune has an indexed [Oratio 3] (which wins), but English's Commune
    // only has the plain, unrelated [Oratio].
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;vide C99"]),
    ])
    let latinCommune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["Oratio communis generica."]),
        RawSection(name: "Oratio 3", condition: "", body: ["Oratio communis indexata."]),
    ])
    let englishCommune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["A different, unrelated English collect."]),
    ])
    let latinCorpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, latinCommune])
    let englishCorpus = InMemoryOfficeCorpus(files: [skeleton, englishPrayersFile, englishCommune])
    let assembler = HourAssembler(
        corpus: latinCorpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]), englishCorpus: englishCorpus
    )

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(Array(oratio.units.dropFirst()) == [.prose("Oratio communis indexata.", english: nil)])    // after the Domine, exaudi (orationes.pl:185-213)
}

@Test func usesTheCommunesEnglishIndexedOratioWhenItGenuinelyExists() throws {
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;vide C99"]),
    ])
    let latinCommune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["Oratio communis generica."]),
        RawSection(name: "Oratio 3", condition: "", body: ["Oratio communis indexata."]),
    ])
    let englishCommune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["A generic English collect."]),
        RawSection(name: "Oratio 3", condition: "", body: ["The genuinely matching English collect."]),
    ])
    let latinCorpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, latinCommune])
    let englishCorpus = InMemoryOfficeCorpus(files: [skeleton, englishPrayersFile, englishCommune])
    let assembler = HourAssembler(
        corpus: latinCorpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]), englishCorpus: englishCorpus
    )

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(Array(oratio.units.dropFirst()) == [.prose("Oratio communis indexata.", english: "The genuinely matching English collect.")])
}

@Test func aCommunesOwnIndexedOratioWinsOverItsPlainOneWhenTheOfficeDefinesNeither() throws {
    // Confirmed against the real oracle fixture for 16 September 2026 (Ss. Cornelii et
    // Cypriani, "vide C3"): the collect actually said is Commune/C3.txt's own
    // [Oratio 3] (today's own/second Vespers), not its plain [Oratio] -- and this
    // Commune fallback for Oratio is unconditional (orationes.pl has no ex/vide
    // gating for it, unlike the psalm-antiphon case below).
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;vide C99"]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["Oratio communis generica."]),
        RawSection(name: "Oratio 3", condition: "", body: ["Oratio communis indexata."]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(Array(oratio.units.dropFirst()) == [.prose("Oratio communis indexata.")])
}

@Test func aVideCommunesIndexedAntVesperaIsNeverUsedForPsalmodyFallingThroughToTheWeekdaySchedule() throws {
    // The critical regression case: a first attempt let the second-Vespers "3" index
    // reach a "vide"-type Commune's own [Ant Vespera 3] unconditionally (mirroring the
    // Oratio rule), which broke the real 16 September 2026 fixture -- Ss. Cornelii et
    // Cypriani's actual psalm antiphons are the plain ferial ones ("Beáti omnes... ",
    // psalm 127), not Commune/C3's numbered [Ant Vespera 3] at all, because the rank
    // says "vide C3" not "ex C3" (psalmi.pl's `exists($w{'Ant Vespera 3'})` only
    // checks the office's own hash; the one call that reaches the Commune,
    // `getproprium`, is itself gated to `$communetype =~ /ex/`).
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;vide C99"]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona communis sine numero."]),
        RawSection(name: "Ant Vespera 3", condition: "", body: ["Antiphona indexata;;200"]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona feriae * de psalmo."))
    #expect(!psalmodia.units.contains(.antiphon("Antiphona indexata")))
}

@Test func anExCommunesIndexedAntVesperaIsUsedForPsalmody() throws {
    // The counterpart to the test above: an "ex"-type commune reference DOES let the
    // second-Vespers "3" index reach the Commune's own [Ant Vespera 3] -- traced from
    // `psalmi.pl`'s `getproprium('Ant Vespera 3', ...)` fallback (gated to
    // `$communetype =~ /ex/`). The mechanism itself (not this exact numbered-index
    // shape, which no real date's fixture happens to need) is now confirmed against a
    // real fixture: 22 February 2025, In Cathedra S. Petri Apostoli (`Sancti/02-22`,
    // `;;Duplex majus;;4;;ex C4`, no `[Ant Vespera]` of its own) renders
    // `Commune/C4.txt`'s own plain `[Ant Vespera]` ("Ecce sacérdos magnus...") as the
    // real first psalm antiphon -- see `Tests/OracleTests/CommuneFallbackOracleTests.swift`.
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;2.0;;ex C99"]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona communis sine numero."]),
        RawSection(name: "Ant Vespera 3", condition: "", body: ["Antiphona indexata;;114"]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona indexata"))
}

@Test func fallsBackToTheCommuneWhenTheOfficeItselfHasNoAntVespera() throws {
    // "ex C99", not "vide C99": psalm-antiphon Commune fallback is gated to "ex"-type
    // references only (see assemblePsalmodia's own doc comment) -- a "vide" reference
    // whose office has no Ant Vespera of its own falls through to the ferial weekday
    // schedule instead, confirmed against two real dates (16 September and
    // 19 November 2026, both "vide").
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;ex C99"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona de Communi;;114"])
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona de Communi"))
}

@Test func assemblesTheMagnificatWithItsOwnAntiphon() throws {
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0"]),
        RawSection(name: "Ant Vespera 3", condition: "", body: ["Antiphona Magnificat;;109"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })

    #expect(canticum.units.first == .antiphon("Antiphona Magnificat"))
    #expect(canticum.units.contains(.verse(reference: "1:46", firstHalf: "Magnificat*", secondHalf: "anima mea Dominum.")))
}

@Test func substitutesTheOfficesOwnNameIntoAGenericCommuneCollect() throws {
    // Confirmed against the real oracle fixture for 5 February 2026 (Sancti/02-05,
    // falling back to Commune/C6): "...beatae N. Virginis..." becomes
    // "...beatae Agathae Virginis..." via the office's own [Name].
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis Virgo"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;vide C99"]),
        RawSection(name: "Name", condition: "", body: ["Aliquis"]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Oratio", condition: "", body: ["Concede propitius, ut beatae N. Virginis natalicia colimus."])
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(Array(oratio.units.dropFirst()) == [.prose("Concede propitius, ut beatae Aliquis Virginis natalicia colimus.")])
}

@Test func leavesACollectWithNoNPlaceholderUntouched() throws {
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0"]),
        RawSection(name: "Name", condition: "", body: ["Aliquis"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria de sancto nominato."]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(Array(oratio.units.dropFirst()) == [.prose("Oratio propria de sancto nominato.")])
}

@Test func festalUnnumberedAntiphonsPairWithTheSundayPsalmsAndARuleGivenFifth() throws {
    // The mechanism this exercises (no ";;number" on the antiphons, but a "Psalm5
    // Vespera3=NNN" Rule entry -- Vespers' first four psalms are always the Sunday set
    // 109-112, only the fifth is proper) is confirmed real for S. Agatha (5 February
    // 2026): psalms 109, 110, 111, 112, 147 exactly match the real oracle fixture. Her
    // own antiphons and Rule entry live directly on Sancti/02-05.txt itself, not on
    // Commune/C6 -- this fixture matches that shape (Rule directly on the office).
    // `festalFifthPsalmNumber` only ever consults the *office's own* [Rule], never the
    // Commune's, even when the antiphons themselves come from that Commune -- an
    // earlier version of this test/mechanism believed the Commune's own tag was also
    // consulted (gated by a `$c eq 4` check this project's port approximated), but
    // direct instrumentation of the real Perl engine showed that gate never actually
    // passes in real DO (see `festalFifthPsalmNumber`'s own doc comment for the full
    // trace) -- so the Rule must live on the office to have any effect, matching what's
    // exercised here.
    //
    // The *first four* psalms' own 109-112 numbering is a separate mechanism
    // (`psalmi.pl:499-524`'s own "Psalmi Dominica" gate, `assemblePsalmodia`'s own doc
    // comment on `candidatePairs`) -- real for S. Agatha too, but via her own Commune
    // (C6, which has "Psalmi Dominica" in *its* [Rule]), not her own office file
    // (neither has it directly). This fixture's own Commune/C99 needs the same tag for
    // the same reason, or the fix correctly falls through to the plain weekday default
    // instead (19 January 2026 is a Monday) -- confirmed to actually happen the hard
    // way, when an earlier version of this fixture (missing this tag) started failing
    // once that gate was ported for real.
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis Virgo"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;ex C99"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
        RawSection(name: "Rule", condition: "", body: ["Psalm5 Vespera=999", "Psalm5 Vespera3=200"]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: [
            "Ant unus * primi.", "Ant duo * secundi.", "Ant tres * tertii.", "Ant quattuor * quarti.", "Ant quinque * quinti.",
        ]),
        RawSection(name: "Rule", condition: "", body: ["Psalmi Dominica"]),
    ])
    let corpus = InMemoryOfficeCorpus(
        files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, feriaTemporal, feast, commune, festalFifthPsalm] + festalPsalms109to112
    )
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["01-19": "01-19"]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Ant unus * primi."))
    #expect(psalmodia.units.contains(.verse(reference: "109:1", firstHalf: "Psalmus*", secondHalf: "numero 109.")))
    #expect(psalmodia.units.contains(.verse(reference: "112:1", firstHalf: "Psalmus*", secondHalf: "numero 112.")))
    // The fifth psalm is the "Vespera3" (today's own second Vespers) entry, not
    // "Vespera" (999, which would point nowhere here) -- confirmed real precedence.
    #expect(psalmodia.units.contains(.verse(reference: "200:1", firstHalf: "Psalmus quintus*", secondHalf: "proprius.")))
    #expect(psalmodia.units.last == .antiphon("Ant quinque quinti."))
}

// MARK: - Paschaltide Alleluia antiphon

/// 20 April 2026 -- a plain Paschaltide Monday (week "Pasc2", real-date-verified in
/// `OracleTests`), low-ranked enough that no Sancti candidate ever competes.
private let paschaltideFeria = RawOfficeFile(path: "Tempora/Pasc2-1", sections: [
    RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Octavam Paschae"]),
    RawSection(name: "Rank", condition: "", body: [";;Feria;;1.0"]),
])

@Test func replacesTheFallbackAntiphonWithAllelúiaOnAPlainPaschaltideWeekday() throws {
    // Confirmed against the real oracle fixture for 20 April 2026: with no office or
    // Commune [Ant Vespera] at all (the weekday-schedule fallback), every psalm's
    // antiphon becomes alleluia_ant()'s "Allelúia, * allelúia, allelúia." rather than
    // the plain ferial schedule's own text.
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, paschaltideFeria])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]))

    let hour = try #require(assembler.assembleVespers(day: 20, month: 4, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Alleluia, * alleluia, alleluia."))
    #expect(psalmodia.units.last == .antiphon("Alleluia, alleluia, alleluia."))
    #expect(!psalmodia.units.contains(.antiphon("Antiphona feriae * de psalmo.")))
}

@Test func leavesAGenuinelyProperAntiphonAloneEvenDuringPaschaltide() throws {
    // The bare-"Alleluia, * alleluia, alleluia." *replacement* only applies to the
    // "nothing defined at all" fallback case -- an office (or its Commune) that
    // genuinely defines its own [Ant Vespera] keeps that antiphon even in Paschaltide
    // (`psalmi.pl`'s own `$communetype !~ /ex/i` gate is vacuously satisfied only when
    // nothing was found; this is the case where something *was* found). It still gets
    // `ensure_single_alleluia`'s own separate, unconditional trailing-alleluia *append*
    // for every Paschaltide antiphon regardless of properness
    // (`LanguageTextTools.pm:78-96`, confirmed real for 28 April 2025's own proper
    // Magnificat antiphon in `EnsureSingleAlleluiaOracleTests`) -- these are two
    // different real mechanisms, not one.
    let feast = RawOfficeFile(path: "Sancti/04-20", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0"]),
        RawSection(name: "Ant Vespera", condition: "", body: ["Antiphona propria;;114"]),
    ])
    let corpus = InMemoryOfficeCorpus(files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, paschaltideFeria, feast])
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["04-20": "04-20"]))

    let hour = try #require(assembler.assembleVespers(day: 20, month: 4, year: 2026, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    #expect(psalmodia.units.first == .antiphon("Antiphona propria, allelúia."))
}

// MARK: - Preces Feriales

/// 18 February 2026 -- Ash Wednesday, real-date-verified elsewhere (`OracleTests`):
/// a Wednesday, with `weekName` "Quadp3" (Quinquagesima week -- Ash Wednesday's own
/// week doesn't get its own "Quad" name, confirmed against `getweek()`,
/// `Date.pm:22-78`) and temporal Feria (not Sancti) winning outright. The real
/// `Tempora/Quadp3-3.txt` gives `;;Feria privilegiata;;7` (a *privileged* feria,
/// deliberately high-numbered so it resists being superseded in occurrence -- not a
/// signal this is festal) and `[Rule]` "Preces Feriales" (the season gate here comes
/// from the Rule flag, not from `weekName`, since "Quadp3" doesn't match `Adv|Quad(?!p)`).
private let ashWednesdayFeria = RawOfficeFile(path: "Tempora/Quadp3-3", sections: [
    RawSection(name: "Officium", condition: "", body: ["Feria IV Cinerum"]),
    RawSection(name: "Rank", condition: "", body: [";;Feria privilegiata;;7"]),
    RawSection(name: "Rule", condition: "", body: ["Preces Feriales"]),
])

@Test func showsPrecesFerialesOnALentenWednesdayWhenTemporalFeriaWins() throws {
    let corpus = InMemoryOfficeCorpus(
        files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, ashWednesdayFeria, majorSpecialFile, precesTextFile]
    )
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]))

    let hour = try #require(assembler.assembleVespers(day: 18, month: 2, year: 2026, priest: false))
    let precesFeriales = try #require(hour.sections.first { $0.kind == .precesFeriales })

    #expect(precesFeriales.units.contains(
        .versicleResponse(versicle: "Ego dixi: Domine, miserere mei.", response: "Sana animam meam quia peccavi tibi.")
    ))
    #expect(precesFeriales.units.contains(.rubric("Nota bene: haec est adnotatio.")))
    // The "~"-suffixed line merges with the following "r. N." line into one versicle
    // (confirmed real: Preces.txt's own Pope/Bishop versicles) instead of leaving a
    // stray, unmerged "N." fragment or a dangling trailing tilde.
    #expect(precesFeriales.units.contains(
        .versicleResponse(versicle: "Oremus pro beatissimo Papa nostro N.", response: "Dominus conservet eum.")
    ))
}

@Test func omitsPrecesFerialesWhenASanctiOfficeWinsEvenOnALentenWednesday() throws {
    // Confirmed against the real oracle fixture for 16 September 2026: a Wednesday, but
    // a Sancti office (the martyrs' feast) wins occurrence, and Preces Feriales is
    // omitted outright regardless of season or day-of-week.
    // Given an artificially high rank so it genuinely outranks Ash Wednesday's own
    // privileged-feria precedence (7) in `Occurrence.resolve` -- an ordinary Duplex
    // feast would *not* actually win here (Ash Wednesday's whole point is resisting
    // supersession), so this isolates the Preces guard from occurrence correctness.
    let feast = RawOfficeFile(path: "Sancti/02-18", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex I. classis;;8.0"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let corpus = InMemoryOfficeCorpus(
        files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, ashWednesdayFeria, majorSpecialFile, precesTextFile, feast]
    )
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: ["02-18": "02-18"]))

    let hour = try #require(assembler.assembleVespers(day: 18, month: 2, year: 2026, priest: false))
    #expect(hour.sections.first { $0.kind == .precesFeriales } == nil)
}

@Test func omitsPrecesFerialesOnALentenThursdayOutsideTheWednesdayFridayEmberRestriction() throws {
    // 1960's own narrowing of the general "Rule has Preces, or Advent/Lent, or an Ember
    // day" condition down to Wednesdays, Fridays, and Ember days only (`preces()`,
    // `specials/preces.pl`) -- a Thursday in Lent doesn't qualify even though the season
    // does.
    let lentenThursday = RawOfficeFile(path: "Tempora/Quadp3-4", sections: [
        RawSection(name: "Officium", condition: "", body: ["Feria V post Cineres"]),
        RawSection(name: "Rank", condition: "", body: [";;Feria;;1.0"]),
        RawSection(name: "Rule", condition: "", body: ["Preces Feriales"]),
    ])
    let corpus = InMemoryOfficeCorpus(
        files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, lentenThursday, majorSpecialFile, precesTextFile]
    )
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]))

    let hour = try #require(assembler.assembleVespers(day: 19, month: 2, year: 2026, priest: false))
    #expect(hour.sections.first { $0.kind == .precesFeriales } == nil)
}

@Test func omitsPrecesFerialesOnAFerialWednesdayOutsideAnyQualifyingSeason() throws {
    // 21 January 2026 is a Wednesday (weekName "Epi2", dayOfWeek 3), but plain
    // time-after-Epiphany with no "Preces" Rule flag and no Ember day -- the season
    // gate must exclude it even though the day-of-week restriction alone would allow it.
    let epiphanyWednesday = RawOfficeFile(path: "Tempora/Epi2-3", sections: [
        RawSection(name: "Officium", condition: "", body: ["Feria IV infra Hebdomadam II post Epiphaniam"]),
        RawSection(name: "Rank", condition: "", body: [";;Feria;;1.0"]),
        RawSection(name: "Rule", condition: "", body: ["Oratio Dominica"]),
    ])
    let corpus = InMemoryOfficeCorpus(
        files: [skeleton, prayersFile, psalm114, psalm232, weekdaySchedule, epiphanyWednesday, majorSpecialFile, precesTextFile]
    )
    let assembler = HourAssembler(corpus: corpus, context: vesperaContext, calendar: SanctoralCalendar(entries: [:]))

    let hour = try #require(assembler.assembleVespers(day: 21, month: 1, year: 2026, priest: false))
    #expect(hour.sections.first { $0.kind == .precesFeriales } == nil)
}
