import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: 6 March 2025 (a Thursday, "Feria V post
// Cineres" -- a plain Lenten feria, `Tempora/Quadp3-4`, rank 3.9) wrongly commemorated
// Ss. Perpetuae et Felicitatis (Duplex, rank 3) at Vespers, even though the real fixture
// shows no commemoration at all. Traced against the pinned DO engine directly (Docker):
// the cause isn't the Sunday-specific "discard entirely" branch already ported as
// `Commemorations.isDiscardedOnSunday` (6 March isn't a Sunday), nor any of
// `occurrence()`'s three already-known `@commemoentries = ()` clearing points -- its own
// emptying here is expected behaviour for a single sanctoral candidate
// (`$sfile = shift @commemoentries`), not a bug. The real cause is `climit1960`
// (`horascommon.pl:1894-1919`), a separate Vespers-eligibility gate this engine's
// `runnersUp()` had no equivalent for: when the temporal office is the actual overall
// winner (not another sanctoral office), a `Sancti/` candidate needs rank >= 6 to be
// Vespers-eligible at all -- below that it's Lauds-only, never reaching Vespers,
// regardless of `ownVespersCommemorations`'s own separate ranklimit of 2.

@Test func losingLenFeriaCandidateBelowRankSixGetsNoVespersCommemorationAtAll() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 6, month: 3, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 6, month: 3, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    #expect(!oratio.units.contains { unit in
        if case .rubric(let text, _) = unit { return text.contains("Perpetu") } else { return false }
    })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-03-06"))
    #expect(!fixture.contains("Perpetu"))
}
