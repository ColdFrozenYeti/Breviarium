import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `orationes.pl:216-222`'s own "Sub unica
// conclusione" handling -- when several collects are said in series under one shared
// conclusion (the office's own `[Rule]` says so directly, e.g. "Sub unica concl"), 1960
// drops the main collect's own closing doxology macro entirely
// (`$w =~ s/\$(Per|Qui) .*?\n//`) rather than moving it, letting the chain's own final
// commemoration supply the one and only "...Amen.". Confirmed real for 22 February 2025
// (In Cathedra S. Petri, `Sancti/02-22.txt`'s own `[Rule]`: "ex C4; ... Sub unica
// concl..."): the real fixture goes straight from the main collect's own "...néxibus
// liberémur:" to "Commemoratio S. Pauli Apostoli" with no "Qui vivis...Amen." in
// between at all -- this project's engine used to render that doxology anyway.

@Test func inCathedraSPetriOmitsItsOwnConclusionUnderSubUnicaConclusione() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 22, month: 2, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 22, month: 2, year: 2025, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let prose = oratio.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("néxibus liberémur") })
    #expect(!prose.contains { $0.contains("Qui vivis et regnas") })
    let rubrics = oratio.units.compactMap { unit -> String? in
        if case .rubric(let t, _) = unit { return t } else { return nil }
    }
    #expect(rubrics.contains { $0.contains("Commemoratio S. Pauli") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-02-22"))
    #expect(!fixture.contains("liberémur: Qui vivis"))
    #expect(!fixture.contains("liberémur:\nQui vivis"))
}
