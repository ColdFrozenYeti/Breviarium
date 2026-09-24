import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `replaceNdot()` (`specials.pl:778-817`) is a
// general "N." name-substitution mechanism used for *any* resolved text, not just the
// Oratio -- this project's engine only ever called its own `substituteName` for the
// Oratio, so a Magnificat antiphon with its own "N." placeholder (the Common of
// Doctors' own "O Doctor óptime... beáte N....") rendered the literal "N." instead of
// the saint's own name. The real mechanism also picks a different grammatical case (the
// `[Name]` section's own "Ant="-tagged line, vocative case) for this specific antiphon
// shape than it does for the Oratio (the plain/default line, a different case).

@Test func magnificatAntiphonSubstitutesTheDoctorsOwnVocativeName() async throws {
    // 14 January 2025 (St Hilary of Poitiers, a Doctor of the Church): `Sancti/01-14`'s
    // own [Name] is "Hilárium\n(sed rubrica 1570 aut rubrica 1617)\nHilárii\n
    // Ant=Hilári" -- the Magnificat antiphon (from Commune/C4a's own "O Doctor
    // óptime... beáte N.,...") needs the vocative "Hilári", not the plain "Hilárium".
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 14, month: 1, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 14, month: 1, year: 2025, priest: false))

    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphonTexts = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let text, _) = unit { return text } else { return nil }
    }
    #expect(antiphonTexts.first == "O Doctor óptime, * Ecclésiæ sanctæ lumen, beáte Hilári, divínæ legis amátor, deprecáre pro nobis Fílium Dei.")
    #expect(!antiphonTexts.contains { $0.contains("N.") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-01-14"))
    #expect(fixture.contains("O Doctor óptime, * Ecclésiæ sanctæ lumen, beáte Hilári, divínæ legis amátor, deprecáre pro nobis Fílium Dei."))
}
