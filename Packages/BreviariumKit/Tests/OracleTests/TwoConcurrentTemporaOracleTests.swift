import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: 26 April 2025 (Sabbato in Albis, the
// Saturday within the Easter Octave) wrongly showed its own second Vespers content
// (the Octave's shared "Et respiciéntes..." antiphon, from Tempora/Pasc0-0) instead of
// Low Sunday's own first Vespers (the real fixture's own title reads "Dominica in Albis
// in Octava Paschæ ~ Vespera de sequenti", with the real Magnificat antiphon "Cum esset
// sero..."). `Concurrence`'s existing threshold cascade (`horascommon.pl:1130-1189`'s
// Sunday/Festum-Domini branch) requires tomorrow's rank to *strictly outrank* today's --
// Low Sunday's own 1960-conditioned rank (6) is numerically *lower* than Sabbato in
// Albis's own (6.9), so that cascade alone wrongly keeps today's own Vespers. The real
// cause is a wholly separate branch, `horascommon.pl:1072-1076`'s "two concurrent
// Tempora" case: when neither today's nor tomorrow's winning office is sanctoral, the
// Sunday/Festum-Domini cascade doesn't apply at all -- tomorrow wins if its rank is at
// least today's own (non-strict), or unconditionally if today's own `[Rule]` says
// `"No secunda vespera"` regardless of rank, which `Tempora/Pasc0-6.txt` (Sabbato in
// Albis) explicitly does.

@Test func sabbatoInAlbisGivesWayToLowSundaysFirstVespersViaNoSecundaVespera() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 26, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let concurrence = Concurrence(corpus: corpus, context: context, calendar: calendar)
    let result = try #require(concurrence.resolve(day: 26, month: 4, year: 2025))
    #expect(result.isFirstVespersOfTomorrow)
    #expect(result.vespersOffice.winningPath == "Tempora/Pasc1-0")

    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 26, month: 4, year: 2025, priest: false))
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("Cum esset sero") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-26"))
    #expect(fixture.contains("Cum esset sero"))
}
