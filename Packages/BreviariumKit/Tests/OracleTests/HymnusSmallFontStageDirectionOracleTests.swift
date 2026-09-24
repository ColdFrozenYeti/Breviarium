import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: DO's own generic "render in a smaller font"
// wrapper (`horas.pl:190`'s `s{/:(.*?):/}{setfont($smallfont, $1)}eg`) appears literally
// in `Commune/C11.txt`'s own `[Hymnus Vespera]` ("Ave maris stella"), wrapping the
// opening stage direction `/:Prima stropha sequentis hymni dicitur flexis genibus.:/` --
// this project's engine rendered the raw `/:...:/`  delimiters as literal text instead of
// stripping them, and separately left the following line's own `v. ` drop-cap marker
// unstripped (since the old whole-string `hasPrefix` check only ever looked at line 0,
// which this stage direction pushed the real first content line off of). Confirmed real
// for 1 February 2025 (Vespers within the Purification's octave-adjacent common).

@Test func hymnusStripsTheSmallFontStageDirectionAndTheFollowingDropCap() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 1, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 1, month: 2, year: 2025, priest: false))
    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })

    let text = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined(separator: "\n")
    #expect(text.contains("Prima stropha sequentis hymni dicitur flexis genibus."))
    #expect(!text.contains("/:"))
    #expect(!text.contains(":/"))
    #expect(text.contains("Ave maris stella,"))
    #expect(!text.contains("v. Ave maris stella"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-01"))
    #expect(fixture.contains("Prima stropha sequentis hymni dicitur flexis genibus."))
}
