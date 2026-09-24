import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found not by a sweep diff (invisible to it -- see below) but by reading
// `specials.pl:83-94`'s own Omit-handling logic directly: its closing guard,
// `($rule !~ /Omit ad Matutinum/ || $hora eq 'Matutinum')`, is a *global* check against
// the whole [Rule] text, not scoped to the particular Omit clause being evaluated -- if
// the rule contains "Omit ad Matutinum" anywhere at all, no "Omit ..." directive in that
// rule applies to any hour but Matins. `ruleOmits` lacked this guard, so a rule like
// Epiphany's own "Omit ad Matutinum Incipit Invitatorium Hymnus" (Matins-only) was
// wrongly read as omitting Vespers' own Incipit too. Silently invisible to
// `vespersFullRangeContentAudit`: `.introductio` is deliberately excluded from its
// `alwaysPresent` list (a real "Omit" can legitimately empty it), and `mismatches` only
// ever checks that *rendered* text appears in the fixture -- an empty section has no
// rendered text to check, so a wrongly-omitted section produces zero mismatch entries.

@Test func epiphanyDoesNotWronglyOmitVespersOwnIncipit() async throws {
    // 6 January 2025 (In Epiphania Domini, I. classis). Sancti/01-06's own [Rule] is
    // exactly "Omit ad Matutinum Incipit Invitatorium Hymnus" -- Matins-only -- but the
    // real fixture's own Vespers shows the ordinary "Deus in adiutorium..." Incipit in
    // full, not an empty "Incipit{omittitur}".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 6, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 6, month: 1, year: 2025, priest: false))

    let introductio = try #require(hour.sections.first { $0.kind == .introductio })
    #expect(!introductio.units.isEmpty)
    let versicleResponses = introductio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versicleResponses.contains { $0.0.contains("Deus") && $0.0.contains("in adiutórium") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-06"))
    #expect(fixture.contains("Deus"))
    #expect(fixture.contains("in adiutórium meum inténde"))
    #expect(!fixture.contains("Incipit{omittitur}"))
}

@Test func holySaturdayStillOmitsItsOwnIncipitAtVespers() async throws {
    // 19 April 2025 (Holy Saturday). Tempora/Quad6-6's own [Rule] has "Omit Incipit
    // Invitatorium Hymnus Capitulum Lectio Commemoratio ... Conclusion ..." with no "ad
    // Matutinum" qualifier at all -- a genuine, Vespers-scoped omission this fix must not
    // disturb. The real fixture shows "Incipit{omittitur}".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 19, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 19, month: 4, year: 2025, priest: false))

    let introductio = hour.sections.first { $0.kind == .introductio }
    #expect(introductio == nil || introductio?.units.isEmpty == true)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-19"))
    #expect(fixture.contains("Incipit{omittitur}"))
}
