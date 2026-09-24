import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `Commemorations.tomorrowsTiedFirstVespersCandidate`
// (the "equal rank, the preceding takes precedence" tie-break) already excludes
// Feria-titled offices (the Holy Week case), but consecutive days within the same
// privileged octave -- also all tied at the same high rank -- aren't Feria-titled, so
// they slipped past. Real DO routes octave-day succession through an entirely
// different branch (`horascommon.pl:965-1072`'s own outer condition, gated on
// "infra octavam|Vigilia Pent" in the other day's own title), which never produces a
// cross-day commemoration for two ordinary octave days. Confirmed real for 9 June 2025
// (Die II infra octavam Pentecostes, I. classis, tied with tomorrow's Die III infra
// octavam Pentecostes): the real fixture shows no commemoration at all.

@Test func pentecostOctaveDayDoesNotWronglyCommemorateTheFollowingOctaveDay() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 9, month: 6, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 9, month: 6, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(!rubrics.contains { $0.contains("Die III") })
    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Deus, qui Apóstolis tuis Sanctum dedísti Spíritum") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-06-09"))
    #expect(!fixture.contains("Commemoratio Die III"))
}
