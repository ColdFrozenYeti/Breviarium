import Foundation
import Testing
@testable import BreviariumKit

private let context1960 = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "post Epiphaniam", feria: 1, ad: "vesperas", mense: 1
)

/// Two consecutive real January 2026 dates, hand-verified against the actual computus
/// the same way OccurrenceTests/LiturgicalDayTests were: 17 Jan 2026 (Saturday) =
/// "Epi1-6", 18 Jan 2026 (Sunday) = "Epi2-0"; 19 Jan 2026 (Monday) = "Epi2-1", 20 Jan
/// 2026 (Tuesday) = "Epi2-2" (all within the same easter-63 Epiphany-season branch as
/// the already-verified 18 Jan case, just one week label earlier/later or one weekday
/// along). The actual "today"/"tomorrow" dates each test exercises come from the
/// explicit day/month/year passed to `.resolve()`, not from anything in this helper --
/// `Concurrence` computes "tomorrow" itself via `Computus.addDays`.
private func makeConcurrence(
    todayPath: String, todayRank: String,
    tomorrowPath: String, tomorrowRank: String, tomorrowRule: String = ""
) -> Concurrence {
    let files: [RawOfficeFile] = [
        RawOfficeFile(path: todayPath, sections: [
            RawSection(name: "Rank", condition: "", body: [todayRank]),
        ]),
        RawOfficeFile(path: tomorrowPath, sections: [
            RawSection(name: "Rank", condition: "", body: [tomorrowRank]),
            RawSection(name: "Rule", condition: "", body: [tomorrowRule]),
        ]),
    ]
    return Concurrence(
        corpus: InMemoryOfficeCorpus(files: files),
        context: context1960,
        calendar: SanctoralCalendar(entries: [:])
    )
}

@Test func ordinarySundayGetsFirstVespersOnSaturdayEvening() {
    // Real Advent Sunday rank (Semiduplex;;6.9) stands in for "an ordinary Sunday" --
    // every Sunday has first Vespers on Saturday evening, basic to the rubrics.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi1-6", todayRank: ";;Sabbato;;2.0",
        tomorrowPath: "Tempora/Epi2-0", tomorrowRank: ";;Semiduplex;;6.9"
    )
    let result = concurrence.resolve(day: 17, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == true)
    #expect(result?.vespersOffice.winningPath == "Tempora/Epi2-0")
}

@Test func firstClassWeekdayFeastGetsFirstVespers() {
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi2-1", todayRank: ";;Feria;;2.0",
        tomorrowPath: "Tempora/Epi2-2", tomorrowRank: ";;S. Aliquis;;6.0;;vide C6"
    )
    let result = concurrence.resolve(day: 19, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == true)
}

@Test func secondClassWeekdayFeastDoesNotGetFirstVespers() {
    // Rank 5.0 (II. classis), tomorrow is a weekday, today is not a Saturday --
    // threshold is 6, so 5.0 falls short.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi2-1", todayRank: ";;Feria;;2.0",
        tomorrowPath: "Tempora/Epi2-2", tomorrowRank: ";;S. Aliquis;;5.0;;vide C6"
    )
    let result = concurrence.resolve(day: 19, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == false)
    #expect(result?.vespersOffice.winningPath == "Tempora/Epi2-1")
}

@Test func secondClassFestumDominiOnSaturdayGetsFirstVespers() {
    // 17 Jan 2026 is a Saturday; tomorrow (18 Jan) is given a synthetic II. classis
    // Festum Domini rank instead of its real Sunday one, to isolate the
    // Saturday+FestumDomini threshold=5 branch from the "tomorrow is a Sunday" branch.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi1-6", todayRank: ";;Sabbato;;2.0",
        tomorrowPath: "Tempora/Epi2-0", tomorrowRank: ";;Festum Domini Aliquod;;5.0;;vide C6",
        tomorrowRule: "Festum Domini; 9 lectiones"
    )
    let result = concurrence.resolve(day: 17, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == true)
}

@Test func secondClassFestumDominiOnAWeekdayDoesNotGetFirstVespers() {
    // Same rank and Rule, but today (19 Jan) is a Monday, not a Saturday -- the
    // Saturday-specific threshold=5 exception doesn't apply, so this falls back to the
    // ordinary threshold=6.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi2-1", todayRank: ";;Feria;;2.0",
        tomorrowPath: "Tempora/Epi2-2", tomorrowRank: ";;Festum Domini Aliquod;;5.0;;vide C6",
        tomorrowRule: "Festum Domini; 9 lectiones"
    )
    let result = concurrence.resolve(day: 19, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == false)
}

@Test func explicitNoPrimaVesperaFlagSuppressesFirstVespersRegardlessOfRank() {
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi1-6", todayRank: ";;Sabbato;;2.0",
        tomorrowPath: "Tempora/Epi2-0", tomorrowRank: ";;S. Aliquis;;7.0;;vide C6",
        tomorrowRule: "No prima vespera; 9 lectiones"
    )
    let result = concurrence.resolve(day: 17, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == false)
}

@Test func plainFeriaTitleIsExcludedEvenAtAnArtificiallyHighRank() {
    // Rank alone (7.0) would clear any threshold; the title-text exclusion for
    // Feria/Sabbato/Vigilia/Quatuor titles should still suppress it.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi2-1", todayRank: ";;Feria;;2.0",
        tomorrowPath: "Tempora/Epi2-2", tomorrowRank: "Feria Quarta;;Feria;;7.0"
    )
    let result = concurrence.resolve(day: 19, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == false)
}

@Test func vigilTitleWithOctaveOverrideIsNotExcluded() {
    // "Vigilia" alone would be excluded, but "in octava" in the same title is one of
    // the documented override exceptions.
    let concurrence = makeConcurrence(
        todayPath: "Tempora/Epi2-1", todayRank: ";;Feria;;2.0",
        tomorrowPath: "Tempora/Epi2-2",
        tomorrowRank: "Vigilia in octava Aliquid;;Semiduplex;;6.0;;vide C6"
    )
    let result = concurrence.resolve(day: 19, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == true)
}

@Test func noTomorrowOfficeFallsBackToTodaysOwnVespers() {
    let concurrence = Concurrence(
        corpus: InMemoryOfficeCorpus(files: [
            RawOfficeFile(path: "Tempora/Epi1-6", sections: [
                RawSection(name: "Rank", condition: "", body: [";;Sabbato;;2.0"])
            ])
        ]),
        context: context1960,
        calendar: SanctoralCalendar(entries: [:])
    )
    let result = concurrence.resolve(day: 17, month: 1, year: 2026)
    #expect(result?.isFirstVespersOfTomorrow == false)
    #expect(result?.vespersOffice.winningPath == "Tempora/Epi1-6")
}
