import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `displacedVespersCommemorations`'s own
// ranklimit was keyed by the *displaced* office's own rank rather than the *winner's*
// (tomorrow's) — confirmed wrong by direct Docker tracing of `$comrank`, the real
// variable this mechanism actually gates on (`horascommon.pl:1203`'s own
// `$comrank == 1.15 || ... || $comrank == 3.9` check, inside a branch whose own entry
// condition requires the *winner's* rank, `$crank`, to reach 5 or 6 -- never the
// displaced office's own `$rank`). The old, wrong threshold (based on the displaced
// office's own rank) was nearly always trivially cleared, regardless of how high
// tomorrow's own rank actually was. Confirmed real for 30 April 2025 (S. Catharinæ
// Senensis, Duplex rank 3, displaced by St Joseph the Worker's own first Vespers the
// next day, I. classis): "Vespera de sequenti; nihil de præcedenti" -- no commemoration
// at all, since rank 3 is below the winner-rank-6 threshold of 4.2.

@Test func stCatharineIsNotCommemoratedWhenStJosephTheWorkersFirstVespersPreEmptsHer() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 30, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 30, month: 4, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(!rubrics.contains { $0.contains("Catharin") })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Rerum cónditor Deus") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-30"))
    #expect(!fixture.contains("Commemoratio S. Catharin"))
}
