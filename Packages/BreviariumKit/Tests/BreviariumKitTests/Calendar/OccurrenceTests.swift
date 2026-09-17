import Foundation
import Testing
@testable import BreviariumKit

private let context1960 = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "Adventus", feria: 1, ad: "vesperas", mense: 12
)

/// Builds a corpus with one temporal file at the given path/rank and, optionally, one
/// sanctoral candidate registered in the calendar for `day` January 2026 (18 Jan 2026 is
/// a Sunday; 19 Jan 2026 is a Monday -- see `temporalPathConstruction` and its hand
/// verification against the actual computus).
private func makeFixture(
    day: Int = 18,
    temporalPath: String,
    temporalRank: String,
    sanctoralRank: String? = nil,
    sanctoralRule: String = ""
) -> (Occurrence, day: Int, month: Int, year: Int) {
    let sanctoralKey = String(format: "01-%02d", day)
    var files: [RawOfficeFile] = [
        RawOfficeFile(path: temporalPath, sections: [
            RawSection(name: "Rank", condition: "", body: [temporalRank])
        ])
    ]
    var calendarEntries: [String: String] = [:]

    if let sanctoralRank {
        files.append(RawOfficeFile(path: "Sancti/\(sanctoralKey)", sections: [
            RawSection(name: "Rank", condition: "", body: [sanctoralRank]),
            RawSection(name: "Rule", condition: "", body: [sanctoralRule]),
        ]))
        calendarEntries[sanctoralKey] = sanctoralKey
    }

    let occurrence = Occurrence(
        corpus: InMemoryOfficeCorpus(files: files),
        context: context1960,
        calendar: SanctoralCalendar(entries: calendarEntries)
    )
    return (occurrence, day, 1, 2026)
}

@Test func temporalPathConstruction() {
    // Nat weeks never get the "-<weekday>" suffix; every other week does.
    #expect(Occurrence.temporalPath(day: 25, month: 12, year: 2026) == "Tempora/Nat25")
    #expect(Occurrence.temporalPath(day: 18, month: 1, year: 2026) == "Tempora/Epi2-0")
}

@Test func decemberTwentySixToThirtyFirstRedirectsToNat1_0OnWhicheverDayIsSunday() {
    // DO reaches this via seven dominical-letter transfer tables (Tabulae/Transfer/
    // {a..g}.txt), each redirecting exactly one of 26-31 December to "Tempora/Nat1-0"
    // for 1960 rubrics -- computing the weekday directly gets the same result.
    // Confirmed against the real oracle fixture for 2025-12-28 (Sunday that year):
    // the rendered Vespers antiphon is Sancti/12-25's own [Ant Vespera 3], reached
    // only through Nat1-0's own [Ant Vespera] cross-reference.
    #expect(Occurrence.temporalPath(day: 28, month: 12, year: 2025) == "Tempora/Nat1-0")    // 28th is Sunday.
    #expect(Occurrence.temporalPath(day: 27, month: 12, year: 2026) == "Tempora/Nat1-0")    // 27th is Sunday.
    #expect(Occurrence.temporalPath(day: 26, month: 12, year: 2027) == "Tempora/Nat1-0")    // 26th is Sunday.
    #expect(Occurrence.temporalPath(day: 31, month: 12, year: 2028) == "Tempora/Nat1-0")    // 31st is Sunday.
    #expect(Occurrence.temporalPath(day: 30, month: 12, year: 2029) == "Tempora/Nat1-0")    // 30th is Sunday.
    #expect(Occurrence.temporalPath(day: 29, month: 12, year: 2030) == "Tempora/Nat1-0")    // 29th is Sunday.
}

@Test func decemberTwentySixToThirtyFirstOnANonSundayIsUnaffected() {
    // 2025-12-28 is the Sunday that year (previous test) -- the days around it keep
    // their own plain day-numbered files.
    #expect(Occurrence.temporalPath(day: 26, month: 12, year: 2025) == "Tempora/Nat26")
    #expect(Occurrence.temporalPath(day: 27, month: 12, year: 2025) == "Tempora/Nat27")
    #expect(Occurrence.temporalPath(day: 29, month: 12, year: 2025) == "Tempora/Nat29")
}

@Test func christmasDayItselfIsNeverRedirectedEvenOnASunday() {
    // 25 December is outside the 26-31 redirect range regardless of its own weekday --
    // Christmas Day always uses its own full sanctoral office, per the existing
    // Occurrence rank comparison, not this temporal-path special case.
    #expect(Occurrence.temporalPath(day: 25, month: 12, year: 2033) == "Tempora/Nat25")
}

@Test func aTiedRankSanctoralCandidateLosesToTheSundayViaNat1_0sOwnRank() {
    // Before this fix, a Sunday within the Octave would have used the day-numbered
    // file's own (typically low, ferial) rank instead of Nat1-0's real "Semiduplex;;
    // 5.4" -- which would make almost any commemorated saint that day (all of Ss.
    // Stephen/John/the Innocents are also 5.4 under 1960 rubrics, confirmed real)
    // incorrectly win outright, contradicting the real fixture (Dominica wins on
    // 2025-12-28 against Holy Innocents, both 5.4). This test locks in that the
    // *rank comparison* genuinely depends on the Nat1-0 redirect happening first.
    let corpus = InMemoryOfficeCorpus(files: [
        RawOfficeFile(path: "Tempora/Nat1-0", sections: [
            RawSection(name: "Rank", condition: "", body: [";;Semiduplex;;5.4;;ex Sancti/12-25"])
        ]),
        RawOfficeFile(path: "Sancti/12-28", sections: [
            RawSection(name: "Rank", condition: "", body: [";;Duplex II class;;5.4;;ex C3"]),
            RawSection(name: "Rule", condition: "", body: [""]),
        ]),
    ])
    let occurrence = Occurrence(
        corpus: corpus, context: context1960, calendar: SanctoralCalendar(entries: ["12-28": "12-28"])
    )
    let result = occurrence.resolve(day: 28, month: 12, year: 2025)
    #expect(result?.sanctoralWins == false)
    #expect(result?.winningPath == "Tempora/Nat1-0")
}

@Test func noSanctoralOfficeMeansTemporalWins() {
    let (occurrence, d, m, y) = makeFixture(temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;4.2")
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == false)
    #expect(result?.winningPath == "Tempora/Epi2-0")
}

@Test func sanctoralAtOrBelow1point1AlwaysLosesTo1960Temporal() {
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;4.2",
        sanctoralRank: ";;S. Aliquis;;1.1;;vide C6"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == false)
}

@Test func sanctoralNumericallyOutrankingTemporalWinsOnAWeekday() {
    // Use a Monday (19 Jan 2026) so the Sunday-exception branch never comes into play --
    // this is purely the "sanctoral rank > temporal rank" ordinary case.
    let (occurrence, d, m, y) = makeFixture(
        day: 19, temporalPath: "Tempora/Epi2-1", temporalRank: ";;Feria;;2.0",
        sanctoralRank: ";;S. Aliquis;;4.0;;vide C6"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == true)
    #expect(result?.winningPath == "Sancti/01-19")
}

@Test func sundayFirstClassFeastBeatsAHigherNumericSunday() {
    // Real Advent Sunday data (Tempora/Adv1-0.txt) carries rank ";;Semiduplex;;6.9" --
    // deliberately higher than a plain 6.0 first-class feast, yet the rubrics still let
    // the I. classis feast win. This is exactly the case the Sunday-exception branch
    // (not the plain numeric comparison) exists for.
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;6.9",
        sanctoralRank: ";;S. Aliquis;;6.0;;vide C6"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == true)
    #expect(result?.winningRank.numericPrecedence == 6.0)
}

@Test func sundaySecondClassFeastOfTheLordBeatsSunday() {
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;6.9",
        sanctoralRank: ";;Festum Domini Aliquod;;5.0;;vide C6",
        sanctoralRule: "Festum Domini; 9 lectiones"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == true)
}

@Test func sundaySecondClassFeastNotOfTheLordLosesToSunday() {
    // Same rank (5.0) but no "Festum Domini" in the Rule -- an ordinary II. classis
    // saint's feast does NOT beat a Sunday.
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;6.9",
        sanctoralRank: ";;S. Aliquis Magnus;;5.0;;vide C6"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == false)
}

@Test func immaculateConceptionBeatsSundayViaRG15EvenAtLowRank() {
    // Title goes in the *first* Rank field (matching how a real file's [Officium] title
    // gets auto-filled into that leading slot -- see do-format.md's [Rank] section);
    // the degree label is the second field.
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;6.9",
        sanctoralRank: "In Conceptione Immaculata Beatæ Mariæ Virginis;;Duplex II classis;;4.0;;vide C10"
    )
    let result = occurrence.resolve(day: d, month: m, year: y)
    #expect(result?.sanctoralWins == true)
}

@Test func noRealTemporalOfficeReturnsNil() {
    let occurrence = Occurrence(
        corpus: InMemoryOfficeCorpus(files: []),
        context: context1960,
        calendar: SanctoralCalendar(entries: [:])
    )
    #expect(occurrence.resolve(day: 18, month: 1, year: 2026) == nil)
}
