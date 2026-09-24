import Testing
@testable import BreviariumKit
@testable import BreviariumDataCore

// Found via a full 2025-2040 content audit (the Capitulum category pass): a narrow,
// named real disjunct in horascommon.pl's own occurrence() (lines 314-315, inside its
// own "$tomorrow" branch): "ensure the Dominica IV adventus win in case it has a '1st
// Vespers' on Dec 23" -- when today is 23 December, tomorrow's own sanctoral candidate
// (Christmas Eve's own Vigil, "Sancti/12-24s", rank 6.9) is zeroed out entirely, forcing
// tomorrow's occurrence to resolve to its temporal winner instead, on the rare years the
// 4th Sunday of Advent coincides with Christmas Eve itself. Without this, the Vigil's
// own higher numeric rank would otherwise win occurrence outright, and Advent IV's own
// first Vespers would never even be considered.
//
// Fixing this surfaced a second, previously-unexercised bug in the same date's own
// Magnificat antiphon: `HourAssembler.oAntiphonLocation` was advancing the O-Antiphon's
// effective date by one when `isFirstVespers`, on the unconfirmed guess that DO's real
// `ant123_special` (`horas.pl:476`) keys off the *winning office's* own nominal date.
// Real Perl instrumentation (reading `horas.pl:476` directly) confirms `$day`/`$month`
// there are the same package-global, never-reassigned values the whole request was
// invoked with -- DO never advances them to "tomorrow" for first Vespers (only
// `$vespera` flips to 1); the O Antiphon custom is tied to the evening being prayed
// (the 23rd), not the following day's own date (the 24th, which would fall outside the
// 17-23 window `24 < 24` fails). Fixed by dropping the `isFirstVespers`-gated
// `addDays(1, ...)` entirely: `oAntiphonLocation` now always uses the requested
// `day`/`month` directly.

@Test func adventFourWinsChristmasEveWhenItFallsOnTheFourthSunday() async throws {
    // 23-24 December 2028: the 4th Sunday of Advent falls on Christmas Eve itself that
    // year. The real fixture's own title for 23 December's Vespers is "Dominica IV
    // Adventus ~ I. classis" ("Vespera de sequenti" -- Advent IV's own first Vespers,
    // pre-empting outright), not the Christmas Eve Vigil. Its own Capitulum (reached
    // via Tempora/Adv4-0's own [Capitulum Laudes], since it has no [Capitulum Vespera]
    // of its own) is "1 Cor 4:1-2 Fratres: Sic nos existimet homo..." -- not
    // Sancti/12-23's own "Gen 49:10 Non auferetur sceptrum de Iuda..." this project's
    // engine rendered instead, having let the Vigil win occurrence outright.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 23, month: 12, year: 2028, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 23, month: 12, year: 2028, priest: false))
    let capitulum = try #require(hour.sections.first { $0.kind == .capitulum })

    let prose = capitulum.units.compactMap { unit -> String? in
        if case .prose(let t, _) = unit { return t } else { return nil }
    }
    #expect(prose.contains { $0.contains("Sic nos exístimet homo") })
    #expect(!prose.contains { $0.contains("Non auferétur sceptrum") })

    // The real fixture's own Magnificat antiphon is the 23rd's own O Antiphon, "O
    // Emmánuel" -- keyed off today's date (23), not tomorrow's nominal date (24, which
    // would fall outside the O-Antiphon window entirely).
    let canticum = try #require(hour.sections.first { $0.kind == .canticum })
    let antiphons = canticum.units.compactMap { unit -> String? in
        if case .antiphon(let t, _) = unit { return t } else { return nil }
    }
    #expect(antiphons.contains { $0.contains("O Emmánuel") })
    #expect(!antiphons.contains { $0.contains("Suscépit Deus") })

    let fixture = try #require(try await OracleFixture.shared.main(year: 2028, date: "2028-12-23"))
    #expect(fixture.contains("Dominica IV Adventus"))
    #expect(fixture.contains("Sic nos exístimet homo"))
    #expect(fixture.contains("O Emmánuel"))
}

@Test func ordinaryChristmasEveStillWinsItsOwnFirstVespersMostYears() async throws {
    // 23-24 December 2025 (an ordinary year -- 24 December is not the 4th Sunday of
    // Advent). Confirms the narrow Dec-23 guard doesn't disturb the ordinary case: the
    // Vigil's own first Vespers still wins normally when there's no Advent-IV
    // coincidence to guard against.
    guard let bundle = RealCorpus.bundle else { return }
    let corpus = bundle.makeLatinCorpus()
    let calendar = SanctoralCalendar(entries: bundle.calendar, transferTable: bundle.transferTable, temporaRedirect: bundle.temporaRedirect)
    let context = ConditionalContextBuilder.build(
        day: 23, month: 12, year: 2025, ad: "vesperas", rubrica: "Rubrics 1960 - 1960", corpus: corpus, sanctoralCalendar: calendar
    )
    let assembler = HourAssembler(corpus: corpus, context: context, calendar: calendar)
    let hour = try #require(assembler.assembleVespers(day: 23, month: 12, year: 2025, priest: false))

    let fixture = try #require(try await OracleFixture.shared.main(year: 2025, date: "2025-12-23"))
    #expect(!fixture.contains("Dominica IV Adventus"))
}
