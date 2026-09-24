import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `LatinOrthography.normalizeLine` treated a
// whole `@file:section:substitution` line as an opaque reference directive, leaving its
// own substitution segment un-normalised too -- but that segment's `s/pattern/.../` is
// matched, at render time, against `section`'s own content, which (being ordinary
// prose) *has* already been J-to-I normalised. A `j`-spelled pattern could then never
// match its now-I-spelled target, silently turning the substitution into a no-op.
// Confirmed real for 7 August 2025 (S. Cajetani Confessoris, III. classis):
// `Sancti/08-07.txt`'s own `[Ant 1]` is `@Tempora/Pent14-0:Ant 3:s/, allelúja//`,
// borrowing an ordinary "time after Pentecost" antiphon and stripping its trailing
// seasonal "allelúja" for this non-Paschal feast -- the real fixture's own Magnificat
// antiphon ends plainly "...adiciéntur vobis." with no alleluia at all, but this
// project's engine rendered "...vobis, allelúia." before this fix.

@Test func nonPaschalBorrowedAntiphonHasItsAlleluiaStrippedNotJustRespelled() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 7, month: 8, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 7, month: 8, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })

    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(!antiphons.isEmpty)
    #expect(antiphons.allSatisfy { !$0.contains("allelúia") })
    #expect(antiphons.contains { $0.contains("Quǽrite primum") && $0.contains("adiciéntur vobis") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-08-07"))
    #expect(!fixture.contains("adiciéntur vobis, allelúia"))
}
