import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `HourAssembler.festalFifthPsalmNumber` only
// ever consults the winning office's own [Rule] for a "Psalm5 Vespera(3)=" tag -- never
// the Commune's, even when the office's own antiphons came from that Commune. This is
// deliberate: `psalmi.pl:577-580`'s own condition does have a second, Commune-Rule-gated
// alternative, but it's guarded by a bare, undeclared Perl global `$c` that -- confirmed
// by instrumenting the real Perl in the pinned Docker container -- is empty/undef at
// this exact check in every real case traced so far, so that alternative never actually
// fires in real DO. See `festalFifthPsalmNumber`'s own doc comment for the full story,
// including the earlier (reverted) version of this port that added a Commune fallback
// and the 16 August 2025 case that exposed it as wrong.

@Test func festalFifthPsalmInheritsFromTheCommuneWhenTheOfficeHasNoTagOfItsOwn() async throws {
    // 13 January 2025: Commemoratio Baptismatis Domini (Sancti/01-13), "ex Sancti/01-06"
    // (Epiphany). Sancti/01-13's own [Rule] has no Psalm5 tag; its antiphons come from
    // Epiphany's own [Ant Laudes] (via the Commune chain, no ;;psalmNumber tags), and
    // Epiphany's own [Rule] has "Psalm5 Vespera3=113" -- the real fixture's own fifth
    // psalm for that date's second Vespers is exactly Psalm 113.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 13, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 13, month: 1, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    // Expected titles are DO's own, from this date's fixture (the Pius XII subtitles came
    // with B1-M3's title fix, `HourAssembler.psalmTitle`).
    #expect(titles == ["Psalmus 109 — Messias rex, sacerdos victor [1]", "Psalmus 110 [2]", "Psalmus 111 — Viri iusti beatiduo [3]", "Psalmus 112 — Laus Dei excelsi et benigni [4]", "Psalmus 113 — A: Mirabilia a Deo in Exodo patrata [5]"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-13"))
    #expect(fixture.contains("Psalmus 113"))
    #expect(!fixture.contains("Díligo Dóminum"))    // the wrong (ferial Psalm 114) antiphon this bug used to render
}

@Test func festalFifthPsalmIgnoresTheCommunesOwnTagWhenTheOfficeHasNoneOfItsOwn() async throws {
    // 16 August 2025: S. Ioachim (Sancti/08-16, "ex C5"). Its own [Rule] has no Psalm5
    // tag at all, and its antiphons come entirely from Commune/C5's own [Ant Vespera]
    // (unnumbered) -- whose own [Rule] has "Psalm5 Vespera=116", with no "Vespera3="
    // counterpart. An earlier version of this port consulted that Commune tag (matching
    // 13 January 2025 above, by coincidence) and wrongly rendered 116; the real fixture's
    // own fifth psalm is 113, the ordinary festal default with no override at all --
    // confirmed by instrumenting the real Perl directly (`festalFifthPsalmNumber`'s own
    // doc comment has the full trace).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 16, month: 8, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 16, month: 8, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    #expect(titles.last == "Psalmus 113 — A: Mirabilia a Deo in Exodo patrata [5]")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-08-16"))
    #expect(fixture.contains("Psalmus 113"))
    #expect(!fixture.contains("Psalmus 116"))
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
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 28, month: 5, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 28, month: 5, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let titles = psalmodia.units.compactMap { unit -> String? in
        if case .psalmTitle(let text) = unit { return text } else { return nil }
    }
    // Expected titles are DO's own, from this date's fixture (the Pius XII subtitles came
    // with B1-M3's title fix, `HourAssembler.psalmTitle`).
    #expect(titles == ["Psalmus 109 — Messias rex, sacerdos victor [1]", "Psalmus 110 [2]", "Psalmus 111 — Viri iusti beatiduo [3]", "Psalmus 112 — Laus Dei excelsi et benigni [4]", "Psalmus 116 — Hymnus laudis et gratiarum actionis [5]"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-05-28"))
    #expect(fixture.contains("Psalmus 116"))
    #expect(!fixture.contains("Cum exíret Israël"))    // Psalm 113's own opening line, the wrong default before this fix
}
