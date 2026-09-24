import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Two separate real-fixture-confirmed fixes to `HourAssembler`'s Capitulum and
// Magnificat-antiphon lookups, both found via a full 2025-2040 content audit.

@Test func christmasEveUsesChristmasDaysOwnFirstVespersCapitulumNotItsSecond() async throws {
    // 24 December 2025 ("Vespera de sequenti; nihil de præcedenti" -- Christmas Day's
    // own first Vespers wins outright). Ports `capitulis.pl`'s own hardcoded special
    // case: `$name = 'Capitulum Vespera 1' if $winner =~ /12-25/ && $vespera == 1;` --
    // `Sancti/12-25.txt`'s own `[Capitulum Vespera 1]` is "Titus 3:4-5" ("Appáruit
    // benígnitas..."), the real fixture's own text; `[Capitulum Laudes]` (this
    // project's engine used to try first, unconditionally) is a different citation,
    // "Heb 1:1-2", reserved for Christmas's own *second* Vespers/Lauds.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 24, month: 12, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 12, year: 2025, priest: false))
    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })
    let text = capitulum.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(text.contains { $0.contains("Appáruit benígnitas") })
    #expect(!text.contains { $0.contains("Multifáriam") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-12-24"))
    #expect(fixture.contains("Titus 3:4-5"))
    #expect(!fixture.contains("Heb 1:1-2"))
}

@Test func oAntiphonOverridesTheOrdinaryMagnificatAntiphonSeventeenToTwentyThirdDecember() async throws {
    // 17 December 2025 (Feria IV Quattuor Temporum Adventus, a Tempora-won Ember
    // Wednesday within Advent). Ports `ant123_special` (`horas.pl:471-500`), called
    // unconditionally *before* the office's own `[Ant $ind]` lookup whenever
    // `$month == 12 && $day > 16 && $day < 24 && $winner =~ /tempora/i`: the real
    // fixture's own Magnificat antiphon is exactly `Major Special.txt`'s own
    // `[Adv Ant 17]`, "O Sapiéntia, * quæ ex ore Altíssimi prodiísti...", the first of
    // the seven "O Antiphons".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 17, month: 12, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 17, month: 12, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("O Sapiéntia") && $0.contains("veni ad docéndum nos viam prudéntiæ") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-12-17"))
    #expect(fixture.contains("O Sapiéntia"))
}
