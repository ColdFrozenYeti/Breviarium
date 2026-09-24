import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found by `vespersFullRangeCommemorationAudit` (Phase 4), the reverse of the content
// audit: 89 dates in 2025-2040 where DO renders a commemoration this project silently
// omitted, ~80 of them a Sunday commemorated at a feast's Vespers. The Sunday was a
// commemoration candidate all along, but `commemorationUnits` returned `nil`: an ordinary
// Sunday after Pentecost has no `[Versum N]`, and the last tier of `getcommemoratio`'s
// versicle chain, `getfrompsalterium` (`specials.pl:639-652`), keys Major Special by
// `gettempora('getfrompsalterium major')`. Outside the marked seasons that key is
// `Dominica`/`Feria`, by the request's weekday, tried at `$ind`, 1, 3, 2. This project
// only ever tried week-name prefixes. Two more pieces of `officestring`'s monthday merge
// (`SetupString.pl:723-780`) came with it: the Scripture-cycle antiphon and the
// " III. Augusti"-style title suffix.
//
// Once Sundays could render, the audit showed the inverse problem: Sundays that DO
// never commemorates. `occurrence()` removes the temporal office outright when a Feast of
// the Lord displaces a II. classis Sunday (`horascommon.pl:388-406`). `concurrence()`'s
// "nihil de sequenti" branch (`:1136-1152`) also keeps a Saturday Feast of the Lord's
// Vespers with nothing of the Sunday.

private func sundayCommemorationVespers(day: Int, month: Int, year: Int) throws -> Section {
    let bundle = try #require(RealCorpus.bundle)
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let hour = try #require(HourAssembler(corpus: corpus, context: context, calendar: calendar).assembleVespers(day: day, month: month, year: year, priest: false))
    return try #require(hour.sections.first { $0.kind == .oratio })
}

private func sundayCommemorationRubrics(_ section: Section) -> [String] {
    section.units.compactMap { unit in
        if case .rubric(let text, _) = unit, text.hasPrefix("Commemoratio") { return text } else { return nil }
    }
}

private func sundayCommemorationVersicles(_ section: Section) -> [String] {
    section.units.compactMap { unit in
        if case .versicleResponse(let versicle, _, _, _) = unit { return versicle } else { return nil }
    }
}

@Test func saturdayFeastCommemoratesTheFollowingSundayWithThePsalterVersicle() async throws {
    // 26 July 2025 (S. Annæ, Saturday). Real fixture: "Commemoratio Dominica VII Post
    // Pentecosten Ant. Unxérunt Salomónem Sadoc sacérdos... ℣. Vespertína orátio ascéndat
    // ad te, Dómine." -- `[Feria Versum 3] (feria 7)` via `getfrompsalterium`.
    guard RealCorpus.bundle != nil else { return }
    let oratio = try sundayCommemorationVespers(day: 26, month: 7, year: 2025)
    #expect(sundayCommemorationRubrics(oratio) == ["Commemoratio Dominica VII Post Pentecosten"])
    #expect(sundayCommemorationVersicles(oratio).contains("Vespertína orátio ascéndat ad te, Dómine."))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-07-26"))
    #expect(fixture.contains("Commemoratio Dominica VII Post Pentecosten Ant. Unxérunt Salomónem"))
    #expect(fixture.contains("Vespertína orátio ascéndat ad te, Dómine."))
}

@Test func monthdayMergedSundayCommemorationHasItsTitleSuffixAndAntiphon() async throws {
    // 16 August 2025 (S. Ioachim, Saturday). Real fixture: "Commemoratio Dominica X Post
    // Pentecosten III. Augusti Ant. Omnis sapiéntia a Dómino Deo est..." -- the title
    // suffix and antiphon both come from the monthday merge.
    guard RealCorpus.bundle != nil else { return }
    let oratio = try sundayCommemorationVespers(day: 16, month: 8, year: 2025)
    #expect(sundayCommemorationRubrics(oratio) == ["Commemoratio Dominica X Post Pentecosten III. Augusti"])
    #expect(oratio.units.contains { unit in
        if case .antiphon(let text, _) = unit { return text.hasPrefix("Omnis sapiéntia a Dómino Deo est") }
        return false
    })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-08-16"))
    #expect(fixture.contains("Commemoratio Dominica X Post Pentecosten III. Augusti Ant. Omnis sapiéntia a Dómino Deo est"))
}

@Test func feastOfTheLordOnSundayDoesNotCommemorateTheSunday() async throws {
    // 14 September 2025 (Exaltation of the Holy Cross, a Sunday): `occurrence()` removes
    // the displaced Sunday outright (`horascommon.pl:399-403`). Real fixture: "In
    // Exaltatione Sanctæ Crucis ~ II. classis Ad Vesperas", no commemoration.
    guard RealCorpus.bundle != nil else { return }
    let oratio = try sundayCommemorationVespers(day: 14, month: 9, year: 2025)
    #expect(sundayCommemorationRubrics(oratio).isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-09-14"))
    #expect(fixture.hasPrefix("In Exaltatione Sanctæ Crucis ~ II. classis Ad Vesperas"))
    #expect(!fixture.contains("Commemoratio"))
}

@Test func christTheKingCommemoratesAllSaintsNotTheResumedSunday() async throws {
    // 31 October 2027 (Christ the King, commemorating All Saints de sequenti). The
    // resumed "Dominica IV Post Epiphaniam" is removed by the same `:399-403` rule, so
    // the one surviving commemoration is All Saints. Real fixture: "Commemoratio Omnium
    // Sanctorum Ant. Ángeli, Archángeli, Throni et Dominatiónes...".
    guard RealCorpus.bundle != nil else { return }
    let oratio = try sundayCommemorationVespers(day: 31, month: 10, year: 2027)
    #expect(sundayCommemorationRubrics(oratio) == ["Commemoratio Omnium Sanctorum"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-10-31"))
    #expect(fixture.contains("Commemoratio Omnium Sanctorum Ant. Ángeli, Archángeli"))
}

@Test func saturdayFeastOfTheLordHasNothingOfTheFollowingSunday() async throws {
    // 1 July 2028 (the Precious Blood, Saturday, before "Dominica IV Post Pentecosten").
    // Real fixture: "Pretiosissimi Sanguinis Domini Nostri Jesu Christi ~ I. classis
    // Vespera de præcedenti; nihil de sequenti".
    guard RealCorpus.bundle != nil else { return }
    let oratio = try sundayCommemorationVespers(day: 1, month: 7, year: 2028)
    #expect(sundayCommemorationRubrics(oratio).isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2028, date: "2028-07-01"))
    #expect(fixture.contains("Vespera de præcedenti; nihil de sequenti"))
}
