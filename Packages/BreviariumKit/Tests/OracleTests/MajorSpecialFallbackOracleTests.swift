import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a real device test: ordinary "time after Pentecost" Sundays' own temporal
// files (`Tempora/PentNN-0.txt`) define no `[Capitulum Laudes]`/`[Hymnus Vespera]`/
// `[Versum N]` of their own, and have no Commune reference either -- `HourAssembler`
// was silently omitting these sections entirely for every such date rather than falling
// back to `Psalterium/Special/Major Special.txt`, the real third tier DO itself uses
// (`capitulis.pl`'s `capitulum_major`, `specials/hymni.pl`'s `hymnusmajor`,
// `specials.pl`'s `getantvers`/`getfrompsalterium`).

@Test func capitulumHymnusVersusFallBackToMajorSpecialForAnOrdinarySunday() async throws {
    // 19 September 2026 (Saturday): first Vespers of Sunday XVII post Pentecosten.
    // Real fixture: Capitulum is Trinity Sunday's own "Capitulum Laudes" (Rom 11:33,
    // reached via Major Special's `[Feria Vespera] (feria 7)` -> `@Tempora/Pent01-0:
    // Capitulum Laudes`), Hymnus is Trinity Sunday's own "Hymnus Vespera" ("Iam sol
    // recéditígneus", via `[Hymnus Day6 Vespera]`), Versus falls through Major
    // Special's own `Feria Versum 1` (absent) to `Feria Versum 3`.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable)
    let context = ConditionalContextBuilder.build(
        day: 19, month: 9, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 9, year: 2026, priest: false))

    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })
    guard case .prose(let capitulumText, _) = try #require(capitulum.units.first) else {
        Issue.record("expected a .prose capitulum unit")
        return
    }
    #expect(capitulumText.contains("Altitúdo divitiárum sapiéntiæ"))

    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })
    #expect(!hymnus.units.isEmpty)
    let hymnusText = hymnus.units.compactMap { unit -> String? in
        if case .prose(let text, _) = unit { return text } else { return nil }
    }.joined(separator: " ")
    #expect(hymnusText.contains("Iam sol recédit ígneus"))

    let versus = try #require(hour.sections.first { $0.kind == .versus })
    #expect(!versus.units.isEmpty)
    guard case .versicleResponse(let versicle, _, _, _) = try #require(versus.units.first) else {
        Issue.record("expected a .versicleResponse versus unit")
        return
    }
    #expect(versicle.contains("Vespertína orátio ascéndat ad te"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-09-19"))
    #expect(fixture.contains("Altitúdo divitiárum sapiéntiæ"))
    #expect(fixture.contains("Iam sol recédit ígneus"))
    #expect(fixture.contains("Vespertína orátio ascéndat ad te"))
}

// Found via the same real device test as the Capitulum/Hymnus/Versus gap above: an
// ordinary "time after Pentecost"/"after Epiphany" Sunday's own temporal file defines
// no `[Ant 1]` (first Vespers), so the Magnificat antiphon was silently missing too.
// `officestring()`'s own "monthday" merge (`Computus.monthday`,
// `HourAssembler.monthdayLocation`) and, when that doesn't apply, the Major Special
// fallback (`majorSpecialAntLocation`) are DO's own two remaining tiers.

@Test func magnificatAntiphonUsesTheMonthdayMergeForAnOrdinarySundayInSeptember() async throws {
    // 19 September 2026 (Saturday): first Vespers of Sunday XVII post Pentecosten.
    // `Tempora/Pent17-0` has no `[Ant 1]` of its own; the real antiphon is `Tempora/
    // 093-0.txt`'s own `[Ant 1]` ("Ne reminiscáris..."), September's third
    // Matins-lesson week, merged in by `officestring()` since month >= 7.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable)
    let context = ConditionalContextBuilder.build(
        day: 19, month: 9, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 9, year: 2026, priest: false))

    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    guard case .antiphon(let antiphonText, _) = try #require(canticum.units.first) else {
        Issue.record("expected an .antiphon canticum unit")
        return
    }
    #expect(antiphonText.contains("Ne reminiscáris"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-09-19"))
    #expect(fixture.contains("Ne reminiscáris"))
}

@Test func magnificatAntiphonFallsBackToMajorSpecialBeforeJuly() async throws {
    // 17 January 2026 (Saturday): first Vespers of Dominica II post Epiphaniam.
    // `Tempora/Epi2-0` has no `[Ant 1]` of its own, and month < 7 so the monthday merge
    // doesn't apply at all -- the real antiphon is Major Special's own `[Feria Ant 3]`
    // (`(feria 7)` cross-referencing `[Feria7 Ant 3]`, "Suscépit Deus Israël...").
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable)
    let context = ConditionalContextBuilder.build(
        day: 17, month: 1, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 17, month: 1, year: 2026, priest: false))

    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    guard case .antiphon(let antiphonText, _) = try #require(canticum.units.first) else {
        Issue.record("expected an .antiphon canticum unit")
        return
    }
    #expect(antiphonText.contains("Suscépit Deus"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-01-17"))
    #expect(fixture.contains("Suscépit Deus"))
}
