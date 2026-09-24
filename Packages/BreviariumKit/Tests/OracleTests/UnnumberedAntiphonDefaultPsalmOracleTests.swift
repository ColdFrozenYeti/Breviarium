import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `psalmi.pl:606-609` always pairs an
// antiphon with no `;;N` tag of its own positionally with the office's own *default*
// five-psalm set (109-113, the ordinary Sunday/feast set) -- regardless of whether a
// `Psalm5` rule exists to override the fifth. This project's engine previously only
// attempted that pairing when a `Psalm5` override was found, so an ordinary Sunday or
// feast `[Ant Vespera]` with five plain, unnumbered antiphons and *no* `Psalm5` tag at
// all fell through to the generic ferial weekday schedule instead, losing its own
// proper antiphons entirely.

@Test func firstSundayOfAdventPairsItsOwnUnnumberedAntiphonsWithTheDefaultSundaySet() async throws {
    // 30 November 2025 (First Sunday of Advent): `Tempora/Adv1-0`'s own `[Ant Vespera]`
    // is `@:Ant Laudes` (a same-file cross-reference), five plain antiphons with no
    // tags and no `Psalm5` rule. The real fixture pairs them with 109/110/111/112/113,
    // exactly like an ordinary Sunday.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
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
    // Expected titles are DO's own, from this date's fixture (the Pius XII subtitles came
    // with B1-M3's title fix, `HourAssembler.psalmTitle`).
    #expect(titles == ["Psalmus 109 — Messias rex, sacerdos victor [1]", "Psalmus 110 [2]", "Psalmus 111 — Viri iusti beatiduo [3]", "Psalmus 112 — Laus Dei excelsi et benigni [4]", "Psalmus 113 — A: Mirabilia a Deo in Exodo patrata [5]"])

    let antiphonTexts = Set(psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    })
    #expect(antiphonTexts.contains("Ecce véniet * Prophéta magnus, et ipse renovábit Ierúsalem, allelúia."))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-11-30"))
    #expect(fixture.contains("Psalmus 113 — A: Mirabilia a Deo in Exodo patrata [5]"))
}

@Test func easterMondayInheritsEasterSundaysOwnUnnumberedAntiphonsViaTheExFallback() async throws {
    // 21 April 2025 (Easter Monday): `Tempora/Pasc0-1`'s own `[Rank]` is `ex Pasc0-0`
    // (Easter Sunday's own file, used as a Commune-like fallback, not a genuine Commune
    // code), whose own `[Ant Vespera]` (`@:Ant Laudes`) is five more plain, unnumbered
    // antiphons -- the same fix applies here via the `communeFallbackPath` route, not
    // just a direct office `[Ant Vespera]`.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 21, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 21, month: 4, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let antiphonTexts = Set(psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    })
    #expect(!antiphonTexts.contains("Allelúia, * allelúia, allelúia."))
    #expect(antiphonTexts.contains { $0.hasPrefix("Angelus autem Dómini") })
}
