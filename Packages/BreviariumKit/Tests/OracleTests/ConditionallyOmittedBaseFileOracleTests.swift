import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit: `RawSectionParser` captured a preamble's
// whole-file inclusion (`do-format.md`) unconditionally, even when the very next line
// is itself a `(sed ... omittitur)` conditional gating it. `Tempora/Pasc6-5.txt` and
// `Pasc6-6.txt` (the Friday/Saturday within the week after Ascension) are the only two
// real files in the whole corpus shaped this way: `@Tempora/Pasc6-0` (Sunday after
// Ascension's own file) immediately followed by `(sed rubrica 196 aut rubrica
// cisterciensis omittitur)` -- under 1960 rubrics that condition holds, so the real
// engine omits the inclusion entirely and falls through to each section's own ordinary
// Commune-reference chain instead (`Pasc6-5`'s own `[Rank]` names `"ex Tempora/
// Pasc5-4"`, Ascension's own file). This project's engine always followed the base
// file regardless, wrongly rendering the Sunday-after-Ascension's own Capitulum/Versum
// on both dates every year.

@Test func fridayAfterAscensionUsesAscensionsOwnCapitulumNotSundayAfterAscensions() async throws {
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 22, month: 5, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 22, month: 5, year: 2026, priest: false))

    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })
    let capitulumText = capitulum.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(capitulumText.contains { $0.contains("Act. 1:1-2") && $0.contains("Primum quidem sermónem") })
    #expect(!capitulumText.contains { $0.contains("1 Petri 4:7-8") })

    // `Pasc5-4.txt`'s own `[Versum 3]` chains to `[Versum 1]` (`@:Versum 1`, itself
    // `@:Versum 1_` unless "rubrica praedicatorum" -- neither hop's own condition holds
    // under 1960 rubrics), landing on "Ascéndit Deus..." -- *not* `[Versum 2]`
    // ("Dóminus in cælo..."), confirmed against the real fixture.
    let versus = try #require(hour.sections.first { $0.kind == .versus })
    let versusUnits = versus.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(versusUnits.contains { $0.0.contains("Ascéndit Deus in iubilatióne") && $0.1.contains("Et Dóminus in voce tubæ") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-05-22"))
    #expect(fixture.contains("Act. 1:1-2"))
    #expect(!fixture.contains("1 Petri 4:7-8"))
    #expect(fixture.contains("Ascéndit Deus in i"))
}
