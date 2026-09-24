import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the "Sacred-Heart/Precious-Blood" deferred
// cluster, and two of the six "Epiphany/Holy-Family" dates). Under the 1960 rubrics,
// "in concurrence of days of equal rank, the preceding takes precedence"
// (`horascommon.pl:1241-1242`, `$rank >= $crank`), which this project already ported.
// But `concurrence()` checks another branch *before* that tie-break (`:1161-1170`):
//
//     || ( $version =~ /196/
//       && ($cwrank[0] =~ /Dominica/i || $cwinner{Rule} =~ /Festum Domini/i)
//       && ($rank < ($crank >= 6 ? 6 : 5) || $wrank[0] =~ /Dominica/i || $winner{Rule} =~ /Festum Domini/i))
//
// -- when both days are Sundays or Feasts of the Lord, tomorrow takes first Vespers even
// at equal (or lower) rank, provided it clears the ordinary first-Vespers threshold and
// the earlier "nihil de sequenti" branch (`:1136-1152`) didn't keep today's Vespers.

private func feastOfTheLordConcurrence(day: Int, month: Int, year: Int) throws -> (ConcurrenceResult, [Commemoration]) {
    let bundle = try #require(RealCorpus.bundle)
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let result = try #require(Concurrence(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year))
    let commemorations = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year)
    return (result, commemorations)
}

@Test func sacredHeartPreEmptsPreciousBloodAtEqualRank() async throws {
    // 1 July 2038: the Precious Blood (`Sancti/07-01`, rank 6, "Festum Domini") is
    // followed by the Sacred Heart (`Tempora/Pent02-5`, rank 6, "Festum Domini"). Real
    // fixture: "Sacratissimi Cordis Domini Nostri Jesu Christi ~ I. classis Vespera de
    // sequenti; nihil de præcedenti".
    guard RealCorpus.bundle != nil else { return }
    let (result, commemorations) = try feastOfTheLordConcurrence(day: 1, month: 7, year: 2038)
    #expect(result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Pent02-5")
    #expect(commemorations.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2038, date: "2038-07-01"))
    #expect(fixture.hasPrefix("Sacratissimi Cordis Domini Nostri Jesu Christi ~ I. classis Vespera de sequenti; nihil de præcedenti"))
}

@Test func holyFamilyPreEmptsEpiphanyOnSaturday() async throws {
    // 6 January 2029 (Saturday): Epiphany (rank 6.5, "Festum Domini") is followed by
    // Holy Family (`Tempora/Epi1-0`, rank 5, "Festum Domini"), whose threshold is 5
    // because today is a Saturday (`$cwinner{Rule} =~ /Festum Domini/i && $dayofweek ==
    // 6`). The "nihil de sequenti" branch's `$rank >= 7` (on a Saturday) doesn't hold for
    // 6.5. Real fixture: "Sanctæ Familiæ Jesu Mariæ Joseph ~ II. classis Vespera de
    // sequenti; nihil de præcedenti".
    guard RealCorpus.bundle != nil else { return }
    let (result, commemorations) = try feastOfTheLordConcurrence(day: 6, month: 1, year: 2029)
    #expect(result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Epi1-0")
    #expect(commemorations.isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2029, date: "2029-01-06"))
    #expect(fixture.hasPrefix("Sanctæ Familiæ Jesu Mariæ Joseph ~ II. classis Vespera de sequenti; nihil de præcedenti"))
}

@Test func lowSundayKeepsItsVespersBeforeTheTransferredAnnunciation() async throws {
    // 4 April 2027: Low Sunday (rank 6) before the Annunciation transferred to 5 April
    // (rank 6). The Annunciation's `[Rule]` has no "Festum Domini", so the ordinary
    // equal-rank tie-break still applies. Real fixture: "Dominica in Albis in Octava
    // Paschæ ~ I. classis Commemoratio: In Annuntiatione Beatæ Mariæ Virginis Vespera de
    // præcedenti; commemoratio de sequenti".
    guard RealCorpus.bundle != nil else { return }
    let (result, _) = try feastOfTheLordConcurrence(day: 4, month: 4, year: 2027)
    #expect(!result.isFirstVespersOfTomorrow)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-04-04"))
    #expect(fixture.hasPrefix("Dominica in Albis in Octava Paschæ ~ I. classis"))
    #expect(fixture.contains("Vespera de præcedenti; commemoratio de sequenti"))
}
