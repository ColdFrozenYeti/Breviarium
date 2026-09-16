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
