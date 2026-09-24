import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: DO's own `!`-marked "red line" rubric
// convention (`horas.pl:167-172`) can appear *mid-hymn*, not just as a whole-hymn-opening
// stage direction (the already-fixed `/:...:/` small-font case is a different
// convention) -- a real genuflection direction between two stanzas. `hymnStanzas` never
// checked `DOMarkers.isRubricLine` at all (unlike `unitsFromLines`/
// `unitsFromResolvedText`, which already did), so the literal `!` leaked into the
// rendered text. Confirmed real for 5 April 2025 (Passiontide): the Vexilla Regis hymn's
// own `!Sequens stropha dicitur flexis genibus.` line, right before its "O Crux, ave..."
// stanza.

@Test func hymnusStripsAMidHymnRubricLineMarker() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 5, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 5, month: 4, year: 2025, priest: false))
    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })

    let text = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined(separator: " ")
    #expect(text.contains("Sequens stropha dicitur flexis genibus."))
    #expect(!text.contains("!Sequens"))
    #expect(text.contains("O Crux, ave, spes única"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-05"))
    #expect(fixture.contains("Sequens stropha dicitur flexis genibus."))
}
