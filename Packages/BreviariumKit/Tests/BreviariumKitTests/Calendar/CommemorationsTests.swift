import Testing
@testable import BreviariumKit

private let context1960 = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "post Epiphaniam", feria: 1, ad: "vesperas", mense: 1
)

/// Real January 2026 dates, hand-verified the same way `ConcurrenceTests` verifies them:
/// 17 Jan 2026 (Saturday) = "Epi1-6", 18 Jan 2026 (Sunday) = "Epi2-0", 19 Jan 2026
/// (Monday) = "Epi2-1", 20 Jan 2026 (Tuesday) = "Epi2-2".
private func makeCommemorations(files: [RawOfficeFile], calendarEntries: [String: String] = [:]) -> Commemorations {
    Commemorations(
        corpus: InMemoryOfficeCorpus(files: files),
        context: context1960,
        calendar: SanctoralCalendar(entries: calendarEntries)
    )
}

// MARK: - Section 2a: today's own second Vespers wins

@Test func ownVespersCommemoratesAQualifyingRunnerUpSaint() {
    // A Feria wins occurrence outright (tied rank -- Occurrence only lets sanctoral win by
    // outranking, not tying); the tied-rank saint still clears the Feria-winner ranklimit
    // (2, since the winning title is ordinary) and gets commemorated.
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;2.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Aliquis Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex;;2.0"]),
            ]),
        ],
        calendarEntries: ["01-19": "01-19"]
    )
    let result = commemorations.resolve(day: 19, month: 1, year: 2026)
    #expect(result.map(\.path) == ["Sancti/01-19"])
}

@Test func ownVespersExcludesARunnerUpBelowTheRanklimit() {
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;2.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Minor Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Simplex;;1.0"]),
            ]),
        ],
        calendarEntries: ["01-19": "01-19"]
    )
    let result = commemorations.resolve(day: 19, month: 1, year: 2026)
    #expect(result.isEmpty)
}

@Test func ownVespersNeverCommemoratesTomorrowRegardlessOfItsRank() {
    // Tomorrow's rank (4.0) would clear the pre-1960 commemoration threshold but not the
    // 1960 first-Vespers threshold (6, non-Sunday) -- so today's own Vespers still wins,
    // and per §2a, 1960 never commemorates tomorrow there. Tomorrow's path must not
    // appear alongside the qualifying runner-up saint from the first test above.
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;2.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Aliquis Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex;;2.0"]),
            ]),
            RawOfficeFile(path: "Tempora/Epi2-2", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria III infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex majus;;4.0"]),
            ]),
        ],
        calendarEntries: ["01-19": "01-19"]
    )
    let result = commemorations.resolve(day: 19, month: 1, year: 2026)
    #expect(result.map(\.path) == ["Sancti/01-19"])
}

// MARK: - Section 2b: tomorrow's first Vespers pre-empts today's

@Test func firstVespersCommemoratesAPrivilegedDisplacedFeriaButNotAnOrdinaryOne() {
    let tomorrowFiles: [RawOfficeFile] = [
        RawOfficeFile(path: "Tempora/Epi2-0", sections: [
            RawSection(name: "Officium", condition: "", body: ["Dominica II post Epiphaniam"]),
            RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;3.0"]),
        ]),
        RawOfficeFile(path: "Sancti/01-18a", sections: [
            RawSection(name: "Officium", condition: "", body: ["S. Feast Aliquod"]),
            RawSection(name: "Rank", condition: "", body: [";;Duplex II classis;;5.0"]),
        ]),
    ]
    let calendarEntries = ["01-18": "01-18a"]

    let ordinary = makeCommemorations(
        files: tomorrowFiles + [
            RawOfficeFile(path: "Tempora/Epi1-6", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria VII infra Hebdomadam I post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;1"]),
            ])
        ],
        calendarEntries: calendarEntries
    )
    let ordinaryResult = ordinary.resolve(day: 17, month: 1, year: 2026)
    #expect(!ordinaryResult.map(\.path).contains("Tempora/Epi1-6"))

    let privileged = makeCommemorations(
        files: tomorrowFiles + [
            RawOfficeFile(path: "Tempora/Epi1-6", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria VII infra Hebdomadam I post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;1.15"]),
            ])
        ],
        calendarEntries: calendarEntries
    )
    let privilegedResult = privileged.resolve(day: 17, month: 1, year: 2026)
    #expect(privilegedResult.map(\.path).contains("Tempora/Epi1-6"))
}

@Test func firstVespersCommemoratesTheWinnersDisplacedSundayButNotANonSundayRunnerUp() {
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi1-6", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria VII infra Hebdomadam I post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;1"]),
            ]),
            RawOfficeFile(path: "Tempora/Epi2-0", sections: [
                RawSection(name: "Officium", condition: "", body: ["Dominica II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;3.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-18a", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Feast Aliquod"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex II classis;;5.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-18b", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Minor Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Simplex;;3.0"]),
            ]),
        ],
        calendarEntries: ["01-18": "01-18a~01-18b"]
    )
    let result = commemorations.resolve(day: 17, month: 1, year: 2026)
    #expect(result.map(\.path) == ["Tempora/Epi2-0"])
}

@Test func noConcurrenceResultGivesNoCommemorations() {
    let commemorations = makeCommemorations(files: [])
    #expect(commemorations.resolve(day: 19, month: 1, year: 2026).isEmpty)
}
