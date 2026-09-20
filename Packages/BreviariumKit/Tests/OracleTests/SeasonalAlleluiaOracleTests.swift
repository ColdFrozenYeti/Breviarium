import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: some Commune/Sancti antiphon files carry a
// literal "Allelúia" annotation -- either bare (Commune C4's own "Sacerdótes Dei...
// Allelúia.") or parenthesized (the Annunciation's own "Missus est... (Allelúia.)") --
// whose visibility depends on the current season (Septuagesima through Lent suppresses
// it outright; Paschaltide unbrackets a parenthesized one instead), not on the office's
// own rank. Ports `process_inline_alleluias`/`suppress_alleluia`
// (`LanguageTextTools.pm:39-73`, called from every displayed text block via
// `webdia.pl:681-685`).

@Test func bareAlleluiaIsSuppressedDuringSexagesimaWeek() async throws {
    // 22 February 2025 (Sexagesima week, pre-Lent): In Cathedra S. Petri uses Commune
    // C4, whose own [Ant Vespera] antiphon 4 reads "Sacerdótes Dei, * benedícite
    // Dóminum: servi Dómini, hymnum dícite Deo. Allelúja." in the raw source -- the real
    // fixture shows no "Allelúia" anywhere in that antiphon.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable)
    let context = ConditionalContextBuilder.build(
        day: 22, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 22, month: 2, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let antiphonTexts = psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
    let sacerdotesDei = try #require(antiphonTexts.first { $0.hasPrefix("Sacerdótes Dei") })
    #expect(sacerdotesDei == "Sacerdótes Dei, * benedícite Dóminum: servi Dómini, hymnum dícite Deo.")
    #expect(!sacerdotesDei.contains("Allel"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-22"))
    #expect(fixture.contains("Sacerdótes Dei, * benedícite Dóminum: servi Dómini, hymnum dícite Deo. Psalmus"))
}

@Test func parenthesizedAlleluiaIsRemovedEntirelyDuringLent() async throws {
    // 24 March 2025 (Lent): the Annunciation's own proper antiphon "Missus est *
    // Gábriel Angelus ad Maríam Vírginem desponsátam Joseph. (Allelúja.)" -- the real
    // fixture shows no "(Allelúia.)" at all, not even unbracketed.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable)
    let context = ConditionalContextBuilder.build(
        day: 24, month: 3, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 3, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    guard case .antiphon(let antiphonText, _) = try #require(psalmodia.units.first) else {
        Issue.record("expected the psalmody's first unit to be an antiphon")
        return
    }
    #expect(antiphonText == "Missus est * Gábriel Angelus ad Maríam Vírginem desponsátam Ioseph.")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-03-24"))
    #expect(fixture.contains("Missus est * Gábriel Angelus ad Maríam Vírginem desponsátam Ioseph. Psalmus"))
}
