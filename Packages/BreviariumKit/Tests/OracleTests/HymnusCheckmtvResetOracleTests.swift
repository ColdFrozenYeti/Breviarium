import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `hymnusmajor`'s `checkmtv()` matches on the
// winning office's own `[Rule]` field (`specials/hymni.pl:67-72`, `specials.pl:532-539`),
// which can say `"vide C5"` (inheriting C5's own `[Rule]` behaviour) even when the
// office's real Commune reference is a lettered variant like `"vide C5c"` -- so
// `hymnusIsRevised` fires correctly per the real Perl's own identical `C[45]` regex, yet
// still names the *wrong* section to search for when the office itself already has a
// proper, unrevised hymn of its own. Real DO guards against this with its own
// reset-to-plain check (`specials/hymni.pl:74-81`, ported this session): if the office's
// own file has neither the revised name nor its indexed variant, but does have the plain
// (unrevised) name or its indexed variant, the revision is dropped before any lookup.
// Confirmed real for 12 February 2025 (Ss. Septem Fundatorum Ordinis Servorum B.M.V.,
// whose own `[Rule]` is `"vide C5"`, triggering the revision, but whose own file defines
// a proper `[Hymnus Vespera 3]`, "Matris sub almæ numine..."; without the reset, the
// engine used to fall through Commune/C5c and Commune/C5 -- neither of which defines a
// Vespers hymn of its own -- all the way to Commune/C4's own revised `[Hymnus1 Vespera]`,
// "Iste Conféssor Dómini sacrátus...", the Common of a Single Confessor's hymn, wrong for
// this feast of seven founders).

@Test func hymnusResetsToThePlainNameWhenTheOfficeHasItsOwnUnrevisedHymn() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 12, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 12, month: 2, year: 2025, priest: false))
    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })

    let text = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }.joined(separator: " ")
    #expect(text.contains("Matris sub almæ") || text.contains("Matris sub alm"))
    #expect(!text.contains("Iste Conféssor"))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-12"))
    #expect(fixture.contains("Matris sub alm"))
}
