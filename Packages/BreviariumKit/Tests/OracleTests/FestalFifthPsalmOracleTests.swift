import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: an office whose own antiphons come from a
// Commune (unnumbered, no ";;psalmNumber" tags of their own) needs a "Psalm5" rule to
// pick its fifth psalm's number for the festal set (109/110/111/112/fifth) --
// `psalmi.pl:577-580`'s own `$rule =~ /Psalm5.../ || ($commune{Rule} =~ /Psalm5.../ &&
// $c eq 4)`. This project's engine only ever checked the winning office's own [Rule]:
// when that office had a [Rule] section at all (even without a Psalm5 tag of its own),
// it never consulted the Commune's own tag.

@Test func festalFifthPsalmInheritsFromTheCommuneWhenTheOfficeHasNoTagOfItsOwn() async throws {
    // 13 January 2025: Commemoratio Baptismatis Domini (Sancti/01-13), "ex Sancti/01-06"
    // (Epiphany). Sancti/01-13's own [Rule] has no Psalm5 tag; its antiphons come from
    // Epiphany's own [Ant Laudes] (via the Commune chain, no ;;psalmNumber tags), and
    // Epiphany's own [Rule] has "Psalm5 Vespera3=113" -- the real fixture's own fifth
    // psalm for that date's second Vespers is exactly Psalm 113.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 13, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 13, month: 1, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles == ["Psalmus 109 [1]", "Psalmus 110 [2]", "Psalmus 111 [3]", "Psalmus 112 [4]", "Psalmus 113 [5]"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-13"))
    #expect(fixture.contains("Psalmus 113"))
    #expect(!fixture.contains("Díligo Dóminum"))    // the wrong (ferial Psalm 114) antiphon this bug used to render
}

// `value(forRuleKey:)`'s own case-sensitive `hasPrefix` match missed a real, lowercase
// "vespera=" tag entirely -- the real Perl's own extraction regex is unconditionally
// case-insensitive (`psalmi.pl:577-580`, every alternative carrying `/i`).

@Test func festalFifthPsalmTagMatchesRegardlessOfCase() async throws {
    // 28 May 2025: Ascension's own first Vespers (Tempora/Pasc5-4). Its own [Rule] has
    // "Psalm5 vespera=116" -- lowercase "vespera", unlike every other real file this
    // project's own oracle sweep has found -- and its own [Ant Vespera] is five plain,
    // unnumbered antiphons, so the fifth psalm comes entirely from this tag. The real
    // fixture's own fifth psalm is "116 -- Hymnus laudis et gratiarum actionis", not
    // the ordinary festal default (113, "In exitu Israël") this project's engine fell
    // back to before this fix, having silently failed to find the lowercase tag.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 28, month: 5, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 28, month: 5, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles == ["Psalmus 109 [1]", "Psalmus 110 [2]", "Psalmus 111 [3]", "Psalmus 112 [4]", "Psalmus 116 [5]"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-05-28"))
    #expect(fixture.contains("Psalmus 116"))
    #expect(!fixture.contains("Cum exíret Israël"))    // Psalm 113's own opening line, the wrong default before this fix
}
