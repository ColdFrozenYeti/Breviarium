import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: when a psalm's antiphon quotes its own
// first verse verbatim (a common pattern, e.g. Psalm 132's "Ecce quam bonum..."), DO
// marks the boundary with a "‡" dagger rather than the psalm's own ordinary mid-verse
// "*" split (`getantcross()`, `horas.pl:238-278`; `horasscripts.pl`'s own
// `s/‡\s+(.*?)\*\s*/* $1/g if $noflexa` for the Breviarium Romanum style this project
// always renders). This project's engine already added the dagger to verse 2, but kept
// verse 1's own natural `*` split unchanged -- never matching DO's real text there,
// which shows verse 1 as one plain unsplit line.

@Test func psalmVerseOneLosesItsSplitWhenTheAntiphonQuotesItWhole() async throws {
    // 2 January 2025 (Octave of the Nativity): Psalm 132's antiphon "Ecce quam
    // bonum..." verbatim quotes 132:1 -- the real fixture shows "132:1 Ecce quam
    // bonum et quam iucúndum, habitáre fratres in unum:" with no "*" anywhere in it,
    // and "‡ Sicut óleum..." starting verse 2.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 2, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 2, month: 1, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    guard case .verse(_, let firstHalf, let secondHalf, _, _) = try #require(
        psalmodia.units.first { if case .verse(let reference, _, _, _, _) = $0 { reference == "132:1" } else { false } }
    ) else {
        Issue.record("expected a .verse unit for 132:1")
        return
    }
    #expect(secondHalf.isEmpty)
    #expect(!firstHalf.contains("*"))
    #expect(firstHalf.contains("Ecce quam bonum et quam iucúndum, habitáre fratres in unum"))

    guard case .verse(_, let secondVerseFirst, _, _, _) = try #require(
        psalmodia.units.first { if case .verse(let reference, _, _, _, _) = $0 { reference == "132:2" } else { false } }
    ) else {
        Issue.record("expected a .verse unit for 132:2")
        return
    }
    #expect(secondVerseFirst.hasPrefix("‡ "))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-02"))
    #expect(fixture.contains("Ecce quam bonum et quam iucúndum, habitáre fratres in unum"))
}

@Test func psalmVerseOneGetsAMidVerseDaggerWhenTheAntiphonQuotesOnlyItsOpeningWords() async throws {
    // 19 January 2025: Psalm 109's antiphon "Dixit Dóminus * Dómino meo: Sede a dextris
    // meis." quotes only 109:1's own opening words, not the whole verse -- the real
    // fixture shows the dagger landing right after the verse's own natural "*" split
    // point ("109:1 Dixit Dóminus Dómino meo: «Sede a dextris meis, * ‡ donec ponam
    // inimícos..."), not at the very end like the whole-match case above. The antiphon
    // itself also gets a trailing "‡" here, same as the whole-match case ("Dixit
    // Dóminus * Dómino meo: Sede a dextris meis. ‡").
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 1, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    guard case .antiphon(let antiphonText, _) = try #require(psalmodia.units.first) else {
        Issue.record("expected the psalmody's first unit to be an antiphon")
        return
    }
    #expect(antiphonText == "Dixit Dóminus * Dómino meo: Sede a dextris meis. ‡")

    guard case .verse(_, let firstHalf, let secondHalf, _, _) = try #require(
        psalmodia.units.first { if case .verse(let reference, _, _, _, _) = $0 { reference == "109:1" } else { false } }
    ) else {
        Issue.record("expected a .verse unit for 109:1")
        return
    }
    #expect(firstHalf == "Dixit Dóminus Dómino meo: «Sede a dextris meis,*")
    #expect(secondHalf == "‡ donec ponam inimícos tuos scabéllum pedum tuórum».")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-19"))
    #expect(fixture.contains("Dixit Dóminus Dómino meo: «Sede a dextris meis, * ‡ donec ponam"))
}
