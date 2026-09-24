import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `Occurrence.temporalPath` never consulted
// DO's own "monthday" merge (`Computus.monthday`, already ported for the Magnificat
// antiphon in `HourAssembler`) when deciding the temporal office's own rank -- flagged
// as an explicit, known gap in `Occurrence`'s own type doc ("Ember days" among the
// cases "not covered by this pass"). September's three Ember days (Wednesday/Friday/
// Saturday, the only three monthday files in the whole corpus that define their own
// [Officium]/[Rank]) were the one real case this gap actually surfaced: their ordinary
// week-based path is an unremarkable rank-1 Feria, so even a low-grade Semiduplex saint
// numerically outranked it and wrongly won the day outright. Confirmed real for 23
// September 2026 (Ember Wednesday): the real fixture's own title is "Feria Quarta
// Quattuor Temporum Septembris ~ II. classis", not "S. Lini Papæ et Martyris" -- and
// since the correct temporal office defines no Vespers-proper texts of its own, its
// Capitulum/Hymnus/Versus (and, transitively, the main Oratio) correctly fall through
// to the ordinary ferial Major Special default once the winner itself is fixed -- a
// single root cause behind four separate mismatched categories on this one date.

@Test func emberWednesdayWinsItsOwnVespersInsteadOfALowRankedSanctoralCandidate() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 23, month: 9, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let occurrence = Occurrence(corpus: corpus, context: context, calendar: calendar)
    let result = try #require(occurrence.resolve(day: 23, month: 9, year: 2026))
    #expect(result.winningPath == "Tempora/093-3")
    #expect(result.winningRank.numericPrecedence == 4.9)
    #expect(!result.sanctoralWins)

    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 23, month: 9, year: 2026, priest: false))
    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })
    let capitulumText = capitulum.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(capitulumText.contains { $0.contains("2 Cor 1:3-4") && $0.contains("Benedíctus Deus") })

    let hymnus = try #require(hour.sections.first { $0.kind == .hymnus })
    let hymnusText = hymnus.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(hymnusText.contains { $0.contains("Cæli Deus sanctíssime") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-09-23"))
    #expect(fixture.contains("Feria Quarta Quattuor Temporum Septembris"))
    #expect(!fixture.contains("Lini Papæ"))
    #expect(fixture.contains("Cæli Deus sanctíssime"))
}
