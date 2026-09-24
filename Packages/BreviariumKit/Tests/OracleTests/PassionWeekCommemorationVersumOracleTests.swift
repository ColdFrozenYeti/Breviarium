import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Oratio category pass): a Passiontide
// commemoration (e.g. the Annunciation's own pre-empting first Vespers commemorating a
// displaced feria within Passion week) always fell through to the week-agnostic generic
// Lenten commemoration versicle ("Ángelis suis Deus mandávit de te.", Major Special.txt's
// own `[Quad Versum 3]`), never trying Passion week's own more specific override
// (`[Quad5 Versum 3]`, real text "Éripe me, Dómine, ab hómine malo.") first.
//
// `[Quad5 Versum 3]`'s own body is itself just a same-file cross-reference
// (`@:Quad5 Versum 3_`) to the underscore-suffixed section actually holding the text --
// confirmed by reading `Major Special.txt` directly in the pinned DO checkout; the
// underscore is purely DO's own convention for giving two section headers non-colliding
// names within one file, not a special lookup key `SectionResolver` needs to know about
// separately (it already follows the `@`-inclusion once the plain header is found).
// `HourAssembler.seasonalVersumLocation` previously always stripped the week number from
// `weekName` (`"Quad5"` -> `"Quad"`) before ever looking anything up, so it never even
// tried a week-specific override on any week, not just the ones (`Quad1`) that genuinely
// lack one. Fixed by trying the full week name first, falling back to the digit-stripped
// generic prefix only when no week-specific override exists -- confirmed real for both
// ends against the real fixtures: 24 March 2026 (Passion week, has its own override) and
// 24 February 2026 (Quad1, no override of its own, the already-confirmed generic case).

@Test func passionWeekCommemorationUsesItsOwnMoreSpecificVersum() async throws {
    // 24 March 2026 (Feria Tertia infra Hebdomadam Passionis, commemorated at the
    // Annunciation's own pre-empting first Vespers). Real fixture's commemoration
    // versicle: "Éripe me, Dómine, ab hómine malo. / A viro iníquo éripe me."
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 24, month: 3, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 3, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let pairs = oratio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Éripe me, Dómine, ab hómine malo") })
    #expect(!pairs.contains { $0.0.contains("Ángelis suis Deus mandávit") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-03-24"))
    #expect(fixture.contains("Éripe me, Dómine, ab hómine malo"))
}

@Test func ordinaryLentenWeekCommemorationStillUsesTheGenericVersum() async throws {
    // 24 February 2026 (Quad1, no week-specific override of its own) -- confirms the fix
    // doesn't disturb the already-working generic-fallback case: real fixture's
    // commemoration versicle is still "Ángelis suis Deus mandávit de te. / Ut custódiant
    // te in ómnibus viis tuis."
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = bundle.makeSanctoralCalendar()
    let context = ConditionalContextBuilder.build(
        day: 24, month: 2, year: 2026, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 24, month: 2, year: 2026, priest: false))
    let oratio = try #require(hour.sections.first { $0.kind == .oratio })

    let pairs = oratio.units.compactMap { unit -> (String, String)? in
        if case .versicleResponse(let v, let r, _, _) = unit { return (v, r) } else { return nil }
    }
    #expect(pairs.contains { $0.0.contains("Ángelis suis Deus mandávit") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2026, date: "2026-02-24"))
    #expect(fixture.contains("Ángelis suis Deus mandávit"))
}
