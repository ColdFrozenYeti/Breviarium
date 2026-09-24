import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (Phase 3's Bug 8, the "Hoc est testimonium"
// Advent commemoration): in the years 21 December falls on the Advent Ember Friday
// (2029, 2035, 2040), S. Thomæ Apostoli wins and correctly commemorates "Feria VI
// Quattuor Temporum Adventus" -- but this project's engine rendered that commemoration's
// antiphon from the Ember Friday's own `[Ant 3]` (`Tempora/Adv3-5.txt`, "Hoc est
// testimónium, * quod perhíbuit Joánnes..."), where the real fixture has the day's O
// Antiphon.
//
// The real mechanism is `getcommemoratio`'s own override (`specials/orationes.pl:
// 772-785`), run *after* the ordinary `Ant $ind` lookup:
//
//     if ($wday =~ /tempora/i) {
//       if ($month == 12 && (($hora eq 'Vespera' && $day >= 17 && $day <= 23) || ...)) {
//         my %v = %{setupstring($lang, 'Psalterium/Special/Major Special.txt')};
//         if ($hora eq 'Vespera') { $a = $v{"Adv Ant $day"}; } ...
//
// -- a commemorated *temporal* office at Vespers between 17 and 23 December always takes
// Major Special's `[Adv Ant $day]`, whatever antiphon it has of its own.
//
// Writing the control test below surfaced a second, previously invisible bug on the
// *ordinary* Advent-feria years: the whole commemoration was silently dropped. An
// ordinary feria such as `Tempora/Adv4-1` has no `[Ant N]` and no `[Oratio]` of its own
// (its `[Rule]` is just "Oratio Dominica"), so `commemorationUnits` found neither and
// returned `nil`. The content sweep can't see an omission (it only checks that rendered
// text appears in the fixture), which is why this never showed up as a mismatch. The O
// Antiphon override fixes the antiphon; `getcommemoratio`'s own "Oratio Dominica"
// redirect (`orationes.pl:704-711`, `$wday =~ s/\-[0-9]/-0/`, then the Sunday's
// `OratioW // Oratio`) fixes the collect.

private func oAntiphonVespersOratio(day: Int, month: Int, year: Int) throws -> Section {
    let bundle = try #require(RealCorpus.bundle)
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: day, month: month, year: year, priest: false))
    return try #require(hour.sections.first { $0.kind == .oratio })
}

private func oAntiphonAntiphons(_ section: Section) -> [String] {
    section.units.compactMap { unit in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
}

@Test func emberFridayCommemorationTakesTheOAntiphon() async throws {
    // 21 December 2029 (S. Thomæ Apostoli, commemorating the Advent Ember Friday). Real
    // fixture: "Commemoratio Feria VI Quattuor Temporum Adventus Ant. O Óriens splendor
    // lucis ætérnæ, et sol iustítiæ: veni, et illúmina sedéntes in ténebris, et umbra
    // mortis. ℣. Roráte, cæli, désuper, et nubes pluant iustum. ... Orémus. Excita,
    // quǽsumus, Dómine, poténtiam tuam, et veni..."
    guard RealCorpus.bundle != nil else { return }
    let oratio = try oAntiphonVespersOratio(day: 21, month: 12, year: 2029)
    let commemorationAntiphons = oAntiphonAntiphons(oratio)
    #expect(commemorationAntiphons.contains { $0.hasPrefix("O Óriens splendor lucis ætérnæ") })
    #expect(!commemorationAntiphons.contains { $0.contains("Hoc est testimónium") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2029, date: "2029-12-21"))
    #expect(fixture.contains("Commemoratio Feria VI Quattuor Temporum Adventus Ant. O Óriens splendor lucis ætérnæ"))
    #expect(!fixture.contains("Hoc est testimónium"))
}

@Test func ordinaryAdventFeriaCommemorationIsRenderedWithItsSundayCollect() async throws {
    // 21 December 2026 (S. Thomæ Apostoli, commemorating `Tempora/Adv4-1`, an ordinary
    // Advent feria with no antiphon or collect of its own). Real fixture: "Commemoratio
    // Feria II infra Hebdomadam IV Adventus Ant. O Óriens splendor lucis ætérnæ... ℣.
    // Roráte, cæli, désuper... Orémus. Excita, quǽsumus, Dómine, poténtiam tuam, et veni:
    // et magna nobis virtúte succúrre..." -- the collect is `Tempora/Adv4-0`'s own.
    guard RealCorpus.bundle != nil else { return }
    let oratio = try oAntiphonVespersOratio(day: 21, month: 12, year: 2026)
    #expect(oratio.units.contains(.rubric("Commemoratio Feria II infra Hebdomadam IV Adventus")))
    #expect(oAntiphonAntiphons(oratio).contains { $0.hasPrefix("O Óriens splendor lucis ætérnæ") })
    #expect(oratio.units.contains { unit in
        if case .prose(let text, _) = unit { return text.hasPrefix("Excita, quǽsumus, Dómine, poténtiam tuam, et veni: et magna nobis") }
        return false
    })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-12-21"))
    #expect(fixture.contains("Commemoratio Feria II infra Hebdomadam IV Adventus Ant. O Óriens splendor lucis ætérnæ"))
    #expect(fixture.contains("Orémus. Excita, quǽsumus, Dómine, poténtiam tuam, et veni: et magna nobis virtúte succúrre"))
}
