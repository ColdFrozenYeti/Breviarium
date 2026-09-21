import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `Commemorations.tomorrowsTiedFirstVespersCandidate`
// (the "equal rank, the preceding takes precedence" tie-break, confirmed real for the
// Annunciation/St Joseph 2035 case) didn't reuse `Concurrence`'s own title-based
// exclusion (`Feria|Sabbato|Vigilia|Quat[t]*uor`, unless overridden). Every day of Holy
// Week is I. classis, so tomorrow's rank clears the same threshold St Joseph 2035 does
// -- but tomorrow's title is still "Feria [Tertia/Quarta/...] Hebdomadæ Sanctæ", which
// the exclusion should catch. Confirmed real for 14 April 2025 (Holy Monday,
// Tempora/Quad6-1): the real fixture shows no commemoration of Holy Tuesday at all;
// this project's engine wrongly added one.

@Test func holyMondayDoesNotWronglyCommemorateHolyTuesday() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 14, month: 4, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 14, month: 4, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(!rubrics.contains { $0.contains("Feria Tertia") })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Adiuva nos, Deus, salutáris noster") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-04-14"))
    #expect(!fixture.contains("Feria Tertia Hebdomadæ Sanctæ"))
}
