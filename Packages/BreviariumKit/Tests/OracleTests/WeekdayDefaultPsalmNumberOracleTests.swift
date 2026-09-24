import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: when a winning office's own antiphons carry
// no ";;N" psalm-number tag (psalmi.pl:606-609's own positional pairing with "@p"), this
// project's engine always zipped them against the hardcoded festal default 109-113 --
// but the real "@p" source is gated by psalmi.pl:499-524's own "Psalmi Dominica" check
// on the *office's* (or its Commune's) own [Rule]: when that check fails, "@p" is the
// *plain weekday* default ("Day$dayofweek $hora", $dayofweek being the actual calendar
// day of the date rendered) instead of the festal one -- and a Sunday reached via its
// own *first* Vespers is rendered on the preceding Saturday's own calendar date, so
// $dayofweek is 6 (Saturday), not 0 (Sunday).

@Test func firstVespersOfAnUngatedSundayUsesTheWeekdaysOwnPsalmNumbersNotTheFestalDefault() async throws {
    // 29 November 2025 (First Vespers of Advent I, rendered on its own Saturday date).
    // Tempora/Adv1-0's own [Ant Vespera] is "@:Ant Laudes" -- five plain, unnumbered
    // antiphons -- and its own [Rule] has no "Psalmi Dominica" tag and no Commune at
    // all, so the gate fails: the real fixture's own first psalm is "143(1-8)"
    // (Psalmi major.txt's own "Day6 Vespera" first entry, Saturday's plain default),
    // not "109" (the festal default this project's engine rendered before this fix).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 29, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 29, month: 11, year: 2025, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles.first == "Psalmus 143(1-8) [1]")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-29"))
    #expect(fixture.contains("Psalmus 143(1-8)"))
    #expect(!fixture.contains("Psalmus 109"))
}

@Test func secondVespersOfTheSameSundayStillUsesTheFestalDefault() async throws {
    // 30 November 2025 (the same First Sunday of Advent's own second Vespers, rendered
    // on the Sunday's own date). Same office, same [Rule] (the "Psalmi Dominica" gate
    // still fails), but "Day0 Vespera" -- the plain weekday default for $dayofweek == 0
    // -- *is* the ordinary festal 109-113 set anyway, so the real fixture's own first
    // psalm is "109" here, confirming the fix's own dayOfWeek-keyed lookup (not a
    // reintroduced hardcoded festal default) gets this contrasting case right too.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 30, month: 11, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 30, month: 11, year: 2025, priest: false))
    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })

    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles.first == "Psalmus 109 [1]")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-30"))
    #expect(fixture.contains("Psalmus 109"))
}
