import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Corpus Christi and the Sacred Heart -- named among `CLAUDE.md`'s edge cases
// ("Corpus Christi, the Sacred Heart, and Christ the King") but, unlike Christ the King
// (`TemporalTransferOracleTests.swift`), these two need no transfer-table involvement at
// all: both are plain `Tempora/PentNN-D` weekday files (`Pent01-4` for Corpus Christi,
// the Thursday of Trinity Sunday's own week; `Pent02-5` for the Sacred Heart, the Friday
// a full week after that), so `TemporalCycle.weekName`/`Occurrence.temporalPath` were
// already exercised by the full-range oracle sweep -- these tests close the *named*
// gap (no dedicated test asserted the exact expected office), not a code gap.

@Test func corpusChristiIsTheThursdayOfTrinitySundaysOwnWeek2026() async throws {
    // 2026: Easter 5 April, Pentecost 24 May, Trinity Sunday 31 May, so Corpus Christi
    // (the following Thursday) is 4 June.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 4, month: 6, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let winner = try #require(Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: 4, month: 6, year: 2026))
    #expect(!winner.sanctoralWins)
    #expect(winner.winningPath == "Tempora/Pent01-4")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-06-04"))
    #expect(fixture.contains("Festum Sanctissimi Corporis Christi"))
}

@Test func sacredHeartIsTheFridayAWeekAfterCorpusChristisOwnOctaveBegins2026() async throws {
    // 12 June 2026 -- the Friday one full week after Corpus Christi (4 June), matching
    // `Pent02-5`'s own real `[Officium]` text confirmed directly against the checkout.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 12, month: 6, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let winner = try #require(Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: 12, month: 6, year: 2026))
    #expect(!winner.sanctoralWins)
    #expect(winner.winningPath == "Tempora/Pent02-5")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-06-12"))
    #expect(fixture.contains("Sacratissimi Cordis"))
}
