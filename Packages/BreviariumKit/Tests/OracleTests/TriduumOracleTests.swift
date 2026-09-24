import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: Holy Saturday's Vespers (and Holy Thursday's/
// Good Friday's) were entirely missing their real Oratio and rendering wrong content
// elsewhere, tracing back to two separate, previously-unported general mechanisms:
//
// - `Tabulae/Tempora/Generale.txt`'s own version-gated whole-week redirect
//   (`TemporaRedirectResolver`, `Directorium.pm`'s `load_tempora()`): under the 1960
//   rubrics, `Tempora/Quad6-6` (Holy Saturday) redirects to `Tempora/Quad6-6r`, a thin
//   override file with the day's real Vespers content (Matins stays on the base file via
//   its own leading `@Tempora/Quad6-6` chain). Real Vespers-relevant fixture range this
//   also covers: Palm Sunday, Holy Thursday, Good Friday, Ascension, Trinity Sunday, and
//   two more Sundays after Pentecost.
// - `[Rule]`'s own `"Omit A B C..."` directive (`ruleOmits`, `specials.pl:83-94`): Holy
//   Saturday's own rule omits Incipit/Capitulum/Hymnus/Versus/Commemoratio/Conclusio
//   entirely, plus the Gloria Patri after every psalm/canticle from Maundy Thursday's own
//   second Vespers through Holy Saturday's (`isTriduumGloriaOmitted`, `horas.pl:223-234`
//   and `303-311` — the visible page substitutes a small-font "Gloria omittitur" rubric
//   note, not silence).

@Test func holySaturdayVespersOmitsIncipitCapitulumAndConclusioEntirely() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 4, year: 2025, priest: false))

    let presentKinds = Set(hour.sections.map(\.kind))
    #expect(!presentKinds.contains(.introductio))
    #expect(!presentKinds.contains(.capitulum))
    #expect(!presentKinds.contains(.hymnus))
    #expect(!presentKinds.contains(.versus))
    #expect(!presentKinds.contains(.conclusio))
    #expect(presentKinds.contains(.psalmodia))
    #expect(presentKinds.contains(.canticum))
    #expect(presentKinds.contains(.oratio))
}

@Test func holySaturdayVespersOratioComesFromTheRRedirectFileWithNoWrongCommemoration() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 4, year: 2025, priest: false))

    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    let proseTexts = oratio.units.compactMap { unit -> String? in
        if case .prose(let text, _) = unit { return text } else { return nil }
    }
    #expect(proseTexts.contains {
        $0.contains("Concéde, quǽsumus, omnípotens Deus: ut, qui Fílii tui resurrectiónem devóta exspectatióne prævenímus")
    })
    let rubricTexts = oratio.units.compactMap { unit -> String? in
        if case .rubric(let text, _) = unit { return text } else { return nil }
    }
    #expect(rubricTexts.contains("Et sub silentio concluditur"))
    // No wrong "Commemoratio Dominica Resurrectionis" -- Holy Saturday's own rule omits
    // Commemoratio entirely.
    #expect(!rubricTexts.contains { $0.contains("Commemoratio") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-19"))
    #expect(fixture.contains("Concéde, quǽsumus, omnípotens Deus: ut, qui Fílii tui resurrectiónem devóta exspectatióne prævenímus"))
}

@Test func holySaturdayPsalmsAndCanticleShowGloriaOmittiturInsteadOfTheDoxology() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 4, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let gloriaOmittiturCount = psalmodia.units.filter {
        if case .rubric(let text, _) = $0 { return text == "Gloria omittitur" } else { return false }
    }.count
    #expect(gloriaOmittiturCount == 5, "expected one 'Gloria omittitur' per psalm")
    #expect(!psalmodia.units.contains {
        if case .verse(_, "Glória Patri, et Fílio,*", _, _, _) = $0 { true } else { false }
    })

    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    #expect(canticum.units.contains { if case .rubric("Gloria omittitur", _) = $0 { true } else { false } })
}

@Test func trinitySundayUsesItsOwnRRedirectedProperAntiphonNotTheOrdinaryFallback() async throws {
    // 15 June 2025 (Trinity Sunday): `Tempora/Pent01-0` redirects to `Tempora/Pent01-0r`
    // under the 1960 rubrics -- a completely different redirect trigger from the Triduum
    // (no Omit involved at all), confirming `TemporaRedirectResolver` is genuinely
    // general, not a Holy-Week-only special case.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 15, month: 6, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 15, month: 6, year: 2025, priest: false))

    let psalmodia = try #require(hour.sections.first { $0.kind == .psalmodia })
    let antiphonTexts = psalmodia.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
    #expect(antiphonTexts.first == "Glória tibi, Trínitas * æquális, una Déitas, et ante ómnia sǽcula, et nunc et in perpétuum.")

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-06-15"))
    #expect(fixture.contains("Glória tibi, Trínitas * æquális, una Déitas, et ante ómnia sǽcula, et nunc et in perpétuum."))
}
