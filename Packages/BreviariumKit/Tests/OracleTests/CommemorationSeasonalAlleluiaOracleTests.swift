import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Oratio category pass): `postprocess_ant`/
// `postprocess_vr` (`horas.pl:675,687-690`) run the real Perl's own seasonal-Alleluia
// handling over *every* displayed antiphon and versicle/response throughout the whole
// office -- this project already applies `applyingSeasonalAlleluia` to the main
// Psalmodia/Magnificat units, but `commemorationUnits` never ran it over a
// commemoration's own antiphon or versicle/response at all, leaving a raw, still-
// parenthesized "(Allelúia.)" on screen whenever the commemorated office's own proper
// text carries that annotation (real for the Annunciation's own "Missus est... Allelúia."
// family of antiphons) during Paschaltide, when the real rule is to keep the word but
// drop the parentheses.

@Test func paschaltideCommemorationAlleluiaIsUnbracketed() async throws {
    // 4 April 2027 (Low Sunday, within the Easter Octave), commemorating the
    // Annunciation transferred there that year. Real fixture's antiphon/versicle/
    // response read "...obumbrábit tibi. Allelúia." / "Ave, María, grátia plena.
    // Allelúia." / "Dóminus tecum. Allelúia." -- unbracketed, not "(Allelúia.)".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus(psalter: .pius12)
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 4, month: 4, year: 2027, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 4, month: 4, year: 2027, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let antiphons = oratio.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("obumbrábit tibi. Allelúia.") })
    #expect(!antiphons.contains { $0.contains("(Allelúia.)") })

    let pairs = oratio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Ave, María, grátia plena. Allelúia.") && $0.1.contains("Dóminus tecum. Allelúia.") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2027, date: "2027-04-04"))
    #expect(fixture.contains("obumbrábit tibi. Allelúia."))
    #expect(fixture.contains("Ave, María, grátia plena. Allelúia."))
}
