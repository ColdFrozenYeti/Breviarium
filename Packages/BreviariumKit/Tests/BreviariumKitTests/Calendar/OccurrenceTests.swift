import Testing
@testable import BreviariumKit

private let context1960 = ConditionalContext(
    rubrica: "Rubrics 1960 - 1960", tempore: "Adventus", feria: 1, ad: "vesperas", mense: 12
)

/// Builds a corpus with one temporal file at the given path/rank and, optionally, one
/// sanctoral candidate registered in the calendar for 18 January 2026 (a Sunday, so
/// Sunday-exception tests can reuse it directly).
private func makeFixture(
    temporalPath: String,
    temporalRank: String,
    sanctoralRank: String? = nil,
    sanctoralRule: String = ""
) -> (Occurrence, day: Int, month: Int, year: Int) {
    var files: [RawOfficeFile] = [
        RawOfficeFile(path: temporalPath, sections: [
            RawSection(name: "Rank", condition: "", body: [temporalRank])
        ])
    ]
    var calendarEntries: [String: String] = [:]

    if let sanctoralRank {
        files.append(RawOfficeFile(path: "Sancti/01-18", sections: [
            RawSection(name: "Rank", condition: "", body: [sanctoralRank]),
            RawSection(name: "Rule", condition: "", body: [sanctoralRule]),
        ]))
        calendarEntries["01-18"] = "01-18"
    }

    let occurrence = Occurrence(
        corpus: InMemoryOfficeCorpus(files: files),
        context: context1960,
        calendar: SanctoralCalendar(entries: calendarEntries)
    )
    return (occurrence, 18, 1, 2026)    // 18 Jan 2026 is a Sunday.
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
    // Use a Monday so the Sunday-exception branch never comes into play -- this is
    // purely the "sanctoral rank > temporal rank" ordinary case.
    let (occurrence, _, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-1", temporalRank: ";;Feria;;2.0",
        sanctoralRank: ";;S. Aliquis;;4.0;;vide C6"
    )
    let result = occurrence.resolve(day: 19, month: m, year: y)    // 19 Jan 2026 is a Monday.
    #expect(result?.sanctoralWins == true)
    #expect(result?.winningPath == "Sancti/01-18")
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
    let (occurrence, d, m, y) = makeFixture(
        temporalPath: "Tempora/Epi2-0", temporalRank: ";;Semiduplex;;6.9",
        sanctoralRank: ";;In Conceptione Immaculata Beatæ Mariæ Virginis;;4.0;;vide C10"
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
