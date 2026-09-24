import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// `CLAUDE.md`'s own named edge cases: "the Annunciation transferred in 2027, 2029 and
// 2035, and St Joseph transferred in 2035" -- confirmed against the real, pinned DO
// checkout's `Tabulae/Transfer/*.txt` tables (`docs/PLAN.md`'s Occurrence doc comment
// had flagged this mechanism as unported) and the real oracle fixtures for both the
// transfer *target* dates and the impeded *natural* dates.
//
// Natural-date suppression (the Annunciation/Joseph disappearing from their own 25/19
// March in an impeded year) needed no new code at all: every one of the four natural
// dates below falls on a day the 1960 rubrics already privilege enormously (Holy
// Thursday, Palm Sunday, Easter Sunday itself, Monday of Holy Week), so the existing
// `Occurrence.decideSanctoralWins` rank comparison already suppresses the fixed feast
// outright -- confirmed here, not assumed. The real work was making the feast
// *reappear* on its transferred target date, which `SanctoralCalendar.candidates(...)`'s
// new transfer-table lookup now does.

private func realBundle() -> DataBundle? { RealCorpus.bundle }

private func occurrenceWinner(_ bundle: DataBundle, day: Int, month: Int, year: Int) -> OccurrenceResult? {
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    return Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year)
}

// MARK: - Natural dates: already correctly suppressed by rank, no new code needed

@Test func annunciationsNaturalDateIsSuppressedByHolyThursday2027() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 25, month: 3, year: 2027))
    #expect(!winner.sanctoralWins)
    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-03-25"))
    #expect(fixture.contains("Feria Quinta in Cena Domini"))
    #expect(!fixture.contains("Annuntiatione"))
}

@Test func annunciationsNaturalDateIsSuppressedByPalmSunday2029() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 25, month: 3, year: 2029))
    #expect(!winner.sanctoralWins)
    let fixture = try #require(try await OracleFixture.shared.main(year: 2029, date: "2029-03-25"))
    #expect(fixture.contains("in Palmis"))
    #expect(!fixture.contains("Annuntiatione"))
}

@Test func annunciationsNaturalDateIsSuppressedByEasterSundayItself2035() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 25, month: 3, year: 2035))
    #expect(!winner.sanctoralWins)
    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-03-25"))
    #expect(!fixture.contains("Annuntiatione"))
}

@Test func josephsNaturalDateIsSuppressedByHolyWeekMonday2035() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 19, month: 3, year: 2035))
    #expect(!winner.sanctoralWins)
    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-03-19"))
    #expect(fixture.contains("Hebdomadæ Sanctæ"))
    #expect(!fixture.contains("Joseph"))
}

// MARK: - Target dates: the transfer table makes the feast reappear

@Test func annunciationTransfersToTheMondayAfterLowSunday2027() async throws {
    guard let bundle = realBundle() else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 5, month: 4, year: 2027, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let winner = try #require(Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: 5, month: 4, year: 2027))
    #expect(winner.sanctoralWins)
    #expect(winner.winningPath == "Sancti/03-25")

    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 5, month: 4, year: 2027, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let antiphonTexts = psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
    #expect(antiphonTexts.contains { $0.contains("Missus est") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-04-05"))
    #expect(fixture.contains("Annuntiatione"))
    #expect(fixture.contains("Missus est"))
}

@Test func annunciationTransfersPastAnEntirelyImpededEasterWeek2029() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 9, month: 4, year: 2029))
    #expect(winner.sanctoralWins)
    #expect(winner.winningPath == "Sancti/03-25")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2029, date: "2029-04-09"))
    #expect(fixture.contains("Annuntiatione"))
}

@Test func annunciationTransfersOffEasterSundayItself2035() async throws {
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 2, month: 4, year: 2035))
    #expect(winner.sanctoralWins)
    #expect(winner.winningPath == "Sancti/03-25")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-04-02"))
    #expect(fixture.contains("Annuntiatione"))
}

@Test func josephTransfersToTheDayAfterAnnunciationsOwnTransfer2035() async throws {
    // Both feasts are displaced by the same 2035 Holy Week/Easter Octave -- Joseph
    // lands on the day immediately after Annunciation's own target (325.txt: Annunciation
    // to 2 April, Joseph to 3 April, the next free day), confirming the two transfers
    // stack correctly rather than colliding.
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 3, month: 4, year: 2035))
    #expect(winner.sanctoralWins)
    #expect(winner.winningPath == "Sancti/03-19")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-04-03"))
    #expect(fixture.contains("S. Joseph Sponsi B.M.V. Confessoris"))
}

@Test func annunciationStillWinsItsOwnVespersAndCommemoratesJosephsEquallyRankedTransferTomorrow2035() async throws {
    // The real oracle fixture for 2 April 2035 shows Annunciation as the primary office
    // (its own antiphons, Magnificat antiphon, and Oratio) with St Joseph -- transferred
    // to 3 April by this same session's fix -- only *commemorated*, via
    // "Commemoratio: S. Joseph...".
    //
    // Both halves needed a real, confirmed fix, not just the transfer table itself:
    // `Concurrence`'s plain threshold check (`tomorrow.rank >= 6`) alone would have let
    // Joseph's transferred rank-6.0 office pre-empt Annunciation's own Vespers outright,
    // since it never compared tomorrow's rank against *today's own* -- missing
    // `horascommon.pl:1241-1242`'s own "in concurrence of days of equal rank, the
    // preceding takes precedence" rule. And even with that fixed, tomorrow's office
    // would have gone uncommemorated entirely, since `Commemorations`'s §2a branch only
    // gathered *today's own* runners-up -- missing the same source's very next lines
    // (`:1244-1249`), which set a *guaranteed* single commemoration (`$commemoratio =
    // $cwinner`) precisely for this tie case, separate from the ordinary
    // (version-1960-suppressed) runner-up mechanism.
    guard let bundle = realBundle() else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 2, month: 4, year: 2035, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let winner = try #require(Occurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: 2, month: 4, year: 2035))
    #expect(winner.winningPath == "Sancti/03-25")

    let commemorations = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: 2, month: 4, year: 2035)
    #expect(commemorations.contains { $0.path == "Sancti/03-19" })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-04-02"))
    #expect(fixture.contains("In Annuntiatione"))
    #expect(fixture.contains("Missus est"))
    #expect(fixture.contains("Commemoratio: S. Joseph"))
}

@Test func annunciationsOwnTransferDoesNotWronglyCommemorateAnUnrelatedLowRankSaint2027() async throws {
    // 328.txt's own line ties a same-day commemoration candidate to the target date
    // ("04-05=03-25~04-05"), and Sancti/04-05.txt is real (S. Vincentii Ferrerii,
    // Duplex/rank 3) -- but the real oracle fixture shows no such commemoration, because
    // `Commemorations.ownVespersCommemorations`'s existing rank threshold (4.2, since
    // the winner is I. classis) already excludes a rank-3 candidate regardless of where
    // it came from. Confirms the existing commemoration-filtering logic needed no
    // transfer-specific special case.
    guard let bundle = realBundle() else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let commemorations = Commemorations(corpus: corpus, context: ConditionalContext(rubrica: "Rubrics 1960 - 1960", tempore: "", feria: 3, ad: "vesperas", mense: 4), calendar: calendar)
    let result = commemorations.resolve(day: 5, month: 4, year: 2027)
    #expect(!result.contains { $0.path == "Sancti/04-05" })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-04-05"))
    #expect(!fixture.contains("Vincentii"))
}

// MARK: - Christ the King: the same transfer-table mechanism, reused for a non-Easter-
// relative date ("last Sunday of October" needs the same "which of these seven possible
// dates is Sunday this year" redirect as the Nat1-0 December case, just keyed by the
// dominical-letter file rather than the exact Easter date -- `docs/PLAN.md`'s December
// fix already ported this idea directly; the transfer table now covers it generally
// instead of needing a second hand-written special case.)

@Test func christTheKingLandsOnTheRealLastSundayOfOctober2026() async throws {
    // 2026's Easter (5 April) gives dominical letter "d" (`ConditionalContextBuilder`'s
    // own letter formula, confirmed against `Tabulae/Transfer/d.txt`'s real line:
    // "10-25=10-DUr;;1960 Newcal") -- 25 October 2026 is indeed the last Sunday of
    // October that year.
    guard let bundle = realBundle() else { return }
    let winner = try #require(occurrenceWinner(bundle, day: 25, month: 10, year: 2026))
    #expect(winner.sanctoralWins)
    #expect(winner.winningPath == "Sancti/10-DUr")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-10-25"))
    #expect(fixture.contains("Domini Nostri Jesu Christi Regis"))
}
