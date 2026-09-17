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
    RawSection(name: "Day1 Vespera", condition: "", body: ["Antiphona feriae * de psalmo.;;114"])
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
    #expect(psalmodia.units.last == .antiphon("Antiphona feriae * de psalmo."))

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

@Test func fallsBackToTheCommuneWhenTheOfficeItselfHasNoAntVespera() throws {
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;vide C99"]),
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

    #expect(oratio.units == [.prose("Concede propitius, ut beatae Aliquis Virginis natalicia colimus.")])
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

    #expect(oratio.units == [.prose("Oratio propria de sancto nominato.")])
}

@Test func festalUnnumberedAntiphonsPairWithTheSundayPsalmsAndARuleGivenFifth() throws {
    // Confirmed against the real oracle fixture for 5 February 2026 (S. Agatha, falling
    // back to Commune/C6): no ";;number" on the antiphons, but a "Psalm5 Vespera3=NNN"
    // Rule entry -- Vespers' first four psalms are always the Sunday set (109-112), only
    // the fifth is proper.
    let feast = RawOfficeFile(path: "Sancti/01-19", sections: [
        RawSection(name: "Officium", condition: "", body: ["S. Aliquis Virgo"]),
        RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0;;vide C99"]),
        RawSection(name: "Oratio", condition: "", body: ["Oratio propria."]),
    ])
    let commune = RawOfficeFile(path: "Commune/C99", sections: [
        RawSection(name: "Ant Vespera", condition: "", body: [
            "Ant unus * primi.", "Ant duo * secundi.", "Ant tres * tertii.", "Ant quattuor * quarti.", "Ant quinque * quinti.",
        ]),
        RawSection(name: "Rule", condition: "", body: ["Psalm5 Vespera=999", "Psalm5 Vespera3=200"]),
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
    #expect(psalmodia.units.last == .antiphon("Ant quinque * quinti."))
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
