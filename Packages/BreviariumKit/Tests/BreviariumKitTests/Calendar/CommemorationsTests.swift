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
    // outranking, not tying); the tied-rank saint clears both the Feria-winner ranklimit
    // (2, since the winning title is ordinary) *and* `climit1960`'s own separate
    // Vespers-eligibility gate for a `Sancti/` candidate losing to a non-sanctoral winner
    // (`horascommon.pl:1894-1919`, ported as `isVespersCommemorationEligible1960` --
    // requires rank >= 6 there), so it gets commemorated. Rank 6 rather than an ordinary
    // Duplex's real-world rank is deliberate: confirmed against two real fixtures (6 March
    // 2025, Ss. Perpetuae et Felicitatis, Duplex rank 3; 19 January 2026, a Vigil) that an
    // ordinary-rank saint losing outright to a Feria gets *no* Vespers commemoration at
    // all, even when it would otherwise clear this function's own ranklimit of 2.
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;6.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Aliquis Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex;;6.0"]),
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

@Test func ownVespersExcludesASanctiRunnerUpBelowClimit1960SixRegardlessOfTheOrdinaryRanklimit() {
    // `climit1960`'s own gate (ported as `isVespersCommemorationEligible1960`) sits
    // *ahead* of this function's ranklimit filter, not behind it: a `Sancti/` candidate
    // losing to a non-sanctoral winner needs rank >= 6 to reach Vespers at all, even when
    // its rank would otherwise clear the ordinary-winner ranklimit of 2 here. Confirmed
    // real for 6 March 2025 (Ss. Perpetuae et Felicitatis, Duplex rank 3, loses to "Feria
    // V post Cineres" and gets no commemoration) and 19 January 2026 (a Vigil loses to
    // "Feria II infra Hebdomadam II post Epiphaniam" and likewise gets none).
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Quadp3-4", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria V post Cineres"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria maior;;3.9"]),
            ]),
            RawOfficeFile(path: "Sancti/03-06", sections: [
                RawSection(name: "Officium", condition: "", body: ["Ss. Perpetuae et Felicitatis Martyrum"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex;;3.0"]),
            ]),
        ],
        calendarEntries: ["03-06": "03-06"]
    )
    let result = commemorations.resolve(day: 6, month: 3, year: 2025)
    #expect(result.isEmpty)
}

@Test func ownVespersNeverCommemoratesTomorrowRegardlessOfItsRank() {
    // Tomorrow's rank (4.0) would clear the pre-1960 commemoration threshold but not the
    // 1960 first-Vespers threshold (6, non-Sunday) -- so today's own Vespers still wins,
    // and per §2a, 1960 never commemorates tomorrow there. Tomorrow's path must not
    // appear alongside the qualifying runner-up saint from the first test above (rank 6,
    // matching that test's own `climit1960`-driven rationale, not an arbitrary lower one).
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;6.0"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["S. Aliquis Confessor"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex;;6.0"]),
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

@Test func aSundayOrFestumDominiTomorrowNeverCommemoratesTodaysOwnWinnerOutright() {
    // Real, confirmed cases (see `Commemorations.resolve`'s own citation): whenever
    // tomorrow's WINNING office is itself titled "Dominica" (or is a Festum Domini),
    // today's own winner is never an unconditional commemoration candidate, regardless
    // of its own rank -- St Januarius (Duplex, rank 3, 19 September 2026) and Advent
    // Ember Saturday (rank 4.9, well above the old ranklimit of 2, 20 December 2025)
    // both show no commemoration at all in the real fixtures. A rank of exactly 1.15
    // (Feria privilegiata) is no exception to this specific rule either -- it's still
    // excluded, since the exclusion isn't about ranklimit at all here.
    // Epi2-0's rank must be the real value (5, matching `OccurrenceTests.swift`'s own
    // corrected value), not an arbitrary lower one: `Occurrence.decideSanctoralWins`
    // lets a sanctoral candidate win outright whenever it numerically outranks the
    // temporal, Sunday or not -- a synthetic Sunday rank lower than the co-occurring
    // saint's would make the *saint* tomorrow's winning occurrence office instead of
    // the Sunday, defeating this test's own premise (it needs tomorrow's winner to
    // actually be titled "Dominica").
    let tomorrowFiles: [RawOfficeFile] = [
        RawOfficeFile(path: "Tempora/Epi2-0", sections: [
            RawSection(name: "Officium", condition: "", body: ["Dominica II post Epiphaniam"]),
            RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;5.0"]),
        ]),
        RawOfficeFile(path: "Sancti/01-18a", sections: [
            RawSection(name: "Officium", condition: "", body: ["S. Feast Aliquod"]),
            RawSection(name: "Rank", condition: "", body: [";;Duplex II classis;;5.0"]),
        ]),
    ]
    let calendarEntries = ["01-18": "01-18a"]

    for todayRank in [";;Feria;;1", ";;Feria;;1.15", ";;Feria major;;4.9"] {
        let commemorations = makeCommemorations(
            files: tomorrowFiles + [
                RawOfficeFile(path: "Tempora/Epi1-6", sections: [
                    RawSection(name: "Officium", condition: "", body: ["Feria VII infra Hebdomadam I post Epiphaniam"]),
                    RawSection(name: "Rank", condition: "", body: [todayRank]),
                ])
            ],
            calendarEntries: calendarEntries
        )
        let result = commemorations.resolve(day: 17, month: 1, year: 2026)
        #expect(!result.map(\.path).contains("Tempora/Epi1-6"), "rank \(todayRank) should not be commemorated")
    }
}

@Test func aNonSundayHigherRankTomorrowDoesCommemorateTodaysOwnDisplacedWinner() {
    // The other real, confirmed case: when tomorrow pre-empts by genuinely outranking
    // today numerically -- not via the Sunday/Festum-Domini threshold -- today's own
    // winner *is* commemorated. Real fixture: SS. Petri et Pauli (29 June, I. classis,
    // titled neither "Dominica" nor a Festum Domini) pre-empting an ordinary Sunday's
    // own second Vespers the evening before (28 June) commemorates that displaced Sunday
    // directly ("Commemoratio: Dominica V Post Pentecosten"). Today here is 18 Jan 2026
    // (the Sunday itself, per this file's own dated fixtures), tomorrow 19 Jan (Monday).
    let commemorations = makeCommemorations(
        files: [
            RawOfficeFile(path: "Tempora/Epi2-0", sections: [
                RawSection(name: "Officium", condition: "", body: ["Dominica II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;3.0"]),
            ]),
            RawOfficeFile(path: "Tempora/Epi2-1", sections: [
                RawSection(name: "Officium", condition: "", body: ["Feria II infra Hebdomadam II post Epiphaniam"]),
                RawSection(name: "Rank", condition: "", body: [";;Feria;;1"]),
            ]),
            RawOfficeFile(path: "Sancti/01-19", sections: [
                RawSection(name: "Officium", condition: "", body: ["SS. Apostolorum Aliquorum"]),
                RawSection(name: "Rank", condition: "", body: [";;Duplex I classis;;7.0"]),
            ]),
        ],
        calendarEntries: ["01-19": "01-19"]
    )
    let result = commemorations.resolve(day: 18, month: 1, year: 2026)
    #expect(result.map(\.path).contains("Tempora/Epi2-0"))
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
