import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit, then traced directly against the pinned DO
// engine (a debug trace inside the project's own Docker container): `horascommon.pl:
// 364-387`'s own "discard this sanctoral candidate entirely" check has a 1960-specific
// branch (`:379-381`) this project's engine never ported: on any Sunday, once the
// winning temporal office's own rank reaches II. classis (5) or I. classis (6), a
// sanctoral candidate ranked below that *same* threshold is discarded from
// commemoration entirely -- not merely filtered by the ordinary ranklimit
// (`ownVespersCommemorations`'s own flat 2 for an ordinary Sunday, which alone would
// have kept a Duplex-rank candidate).

@Test func aDuplexRankedSaintIsNotCommemoratedOnAnIIClassisSunday() async throws {
    // 26 January 2025 ("Dominica III Post Epiphaniam", II. classis, rank 5):
    // S. Polycarpi Episcopi et Martyris (Duplex, rank 3) gets no commemoration at all
    // in the real fixture -- confirmed by a direct trace against the pinned DO engine,
    // not just the fixture diff (this rule discards the candidate before DO's own
    // ordinary ranklimit filter even runs).
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 26, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 26, month: 1, year: 2025, priest: false))

    let oratio = try #require(hour.sections.first { $0.kind == .oratio })
    #expect(!oratio.units.contains { unit in
        if case .rubric(let text, _) = unit { return text.contains("Polycarp") }
        if case .prose(let text, _) = unit { return text.contains("Polycarp") }
        return false
    })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-26"))
    #expect(!fixture.contains("Polycarp"))
}
