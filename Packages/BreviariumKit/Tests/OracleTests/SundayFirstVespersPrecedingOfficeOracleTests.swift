import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (Phase 3's Bug 4, "Sabbato infra Hebdomadam II
// in Quadragesima" wrongly commemorated): on the Saturday before a Lenten Sunday, this
// project's engine commemorated the displaced Lenten Saturday at the Sunday's first
// Vespers, where real DO commemorates the day's saint (19 March 2033) or nothing at all
// (24 February 2035). Three separate pieces of `concurrence()` (`horascommon.pl`) were
// missing or approximated:
//
// 1. `:937-964`, "if tomorrow is a Sunday, get rid of today's tempora completely": when
//    tomorrow's *temporal* office is a Sunday and a saint wins today, today's temporal
//    runner-up is shifted off `@commemoentries` before anything else is decided.
// 2. `:1166-1170`: the "nothing of the preceding office" exclusion before a Sunday or
//    Feast of the Lord is rank-gated (`$rank < ($crank >= 6 ? 6 : 5)`, or today itself a
//    Sunday or Feast of the Lord), not blanket. An I. classis feast before a I. classis
//    Sunday escapes it and is commemorated by `:1296`'s ordinary `$crank > $rank` branch.
// 3. `:1063-1081`, "two concurrent Tempora": when both days' winners are temporal and
//    tomorrow wins, today's temporal winner is never commemorated, and unless `$crank <
//    7 && $crank != 6.5/6 && $comrank > 2`, nothing of today is. Fixing (2) alone
//    regressed every Pentecost Vigil and several 29/30 December dates on the full sweep,
//    which is how this third piece was found; it had previously been masked by the
//    blanket exclusion (2) replaced.

private func sundayFirstVespers(day: Int, month: Int, year: Int) throws -> (commemorations: [Commemoration], oratio: Section) {
    let bundle = try #require(RealCorpus.bundle)
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: day, month: month, year: year, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let commemorations = Commemorations(corpus: corpus, context: context, calendar: calendar).resolve(day: day, month: month, year: year)
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: day, month: month, year: year, priest: false))
    return (commemorations, try #require(hour.sections.first { $0.kind == .oratio }))
}

private func commemorationRubrics(_ section: Section) -> [String] {
    section.units.compactMap { unit in
        if case .rubric(let text, _) = unit, text.hasPrefix("Commemoratio") { return text } else { return nil }
    }
}

@Test func firstClassFeastBeforeFirstClassSundayIsCommemorated() async throws {
    // 19 March 2033: St Joseph (rank 6) on the Saturday before "Dominica III in
    // Quadragesima" (rank 6.9). Real fixture: "Dominica III in Quadragesima ~ I. classis
    // Commemoratio: S. Joseph Sponsi B.M.V. Confessoris Vespera de sequenti; commemoratio
    // de præcedenti ... Commemoratio S. Ioseph Sponsi B.M.V. Confessoris Ant. Ecce fidélis
    // servus et prudens..." -- and nothing of the Lenten Saturday.
    guard RealCorpus.bundle != nil else { return }
    let (commemorations, oratio) = try sundayFirstVespers(day: 19, month: 3, year: 2033)
    #expect(commemorations.map(\.path) == ["Sancti/03-19"])
    #expect(commemorationRubrics(oratio) == ["Commemoratio S. Ioseph Sponsi B.M.V. Confessoris"])

    let fixture = try #require(try await OracleFixture.shared.main(year: 2033, date: "2033-03-19"))
    #expect(fixture.contains("Vespera de sequenti; commemoratio de præcedenti"))
    #expect(fixture.contains("Commemoratio S. Ioseph Sponsi B.M.V. Confessoris Ant. Ecce fidélis servus"))
    #expect(!fixture.contains("Commemoratio Sabbato infra Hebdomadam II in Quadragesima"))
}

@Test func secondClassFeastAndLentenSaturdayBeforeSundayAreNotCommemorated() async throws {
    // 24 February 2035: St Matthias (rank 5) on the Saturday before "Dominica III in
    // Quadragesima". Real fixture: "Vespera de sequenti; nihil de præcedenti" -- neither
    // St Matthias (excluded by `:1166-1170`, rank 5 < 6) nor the privileged Lenten
    // Saturday (rank 3.9, dropped by `:937-964` before the ranklimit filter could keep it).
    guard RealCorpus.bundle != nil else { return }
    let (commemorations, oratio) = try sundayFirstVespers(day: 24, month: 2, year: 2035)
    #expect(commemorations.isEmpty)
    #expect(commemorationRubrics(oratio).isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2035, date: "2035-02-24"))
    #expect(fixture.contains("Vespera de sequenti; nihil de præcedenti"))
    #expect(!fixture.contains("Commemoratio Sabbato"))
}

@Test func pentecostVigilIsNotCommemoratedAtPentecostsFirstVespers() async throws {
    // 7 June 2025: "Sabbato in Vigilia Pentecostes" displaced by Pentecost's own first
    // Vespers -- both temporal, `$crank` 7. Real fixture: "Dominica Pentecostes ~ I.
    // classis Vespera de sequenti." with no commemoration.
    guard RealCorpus.bundle != nil else { return }
    let (commemorations, oratio) = try sundayFirstVespers(day: 7, month: 6, year: 2025)
    #expect(commemorations.isEmpty)
    #expect(commemorationRubrics(oratio).isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-06-07"))
    #expect(fixture.hasPrefix("Dominica Pentecostes ~ I. classis Vespera de sequenti. Ad Vesperas"))
    #expect(!fixture.contains("Commemoratio"))
}

@Test func christmasOctaveDayIsNotCommemoratedAtTheOctaveSundaysFirstVespers() async throws {
    // 30 December 2028: `Tempora/Nat30` displaced by "Dominica Infra Octavam Nativitatis"
    // (31 December) -- both temporal, `$comrank` 0. Real fixture: "Dominica Infra Octavam
    // Nativitatis ~ II. classis Vespera de sequenti." with no commemoration.
    guard RealCorpus.bundle != nil else { return }
    let (commemorations, oratio) = try sundayFirstVespers(day: 30, month: 12, year: 2028)
    #expect(commemorations.isEmpty)
    #expect(commemorationRubrics(oratio).isEmpty)

    let fixture = try #require(try await OracleFixture.shared.main(year: 2028, date: "2028-12-30"))
    #expect(fixture.hasPrefix("Dominica Infra Octavam Nativitatis ~ II. classis Vespera de sequenti. Ad Vesperas"))
    #expect(!fixture.contains("Commemoratio"))
}
